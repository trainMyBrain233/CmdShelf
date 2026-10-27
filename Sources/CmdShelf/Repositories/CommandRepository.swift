import Foundation
import MySQLKit
import SQLKit

enum CommandSort {
    case usage
    case title
    case recent
}

protocol CommandRepositoryProtocol {
    func list(group: String?, sort: CommandSort) async throws -> [Command]
    func search(keyword: String, limit: Int) async throws -> [Command]
    func get(id: UUID) async throws -> Command?
    func upsert(_ command: Command) async throws
    func delete(id: UUID) async throws
    func recordCopy(id: UUID) async throws
}

final class CommandRepository: CommandRepositoryProtocol {
    private let poolProvider: MySQLPoolProvider

    init(poolProvider: MySQLPoolProvider) {
        self.poolProvider = poolProvider
    }

    func list(group: String?, sort: CommandSort = .usage) async throws -> [Command] {
        let orderClause: String
        switch sort {
        case .usage:
            orderClause = "ORDER BY is_pinned DESC, copy_count DESC, last_copied_at DESC, title ASC"
        case .title:
            orderClause = "ORDER BY title ASC"
        case .recent:
            orderClause = "ORDER BY last_copied_at DESC, title ASC"
        }

        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            if let group, !group.isEmpty {
                return sql.raw("\(unsafeRaw: Self.baseSelectSQL) WHERE group_name = \(bind: group) \(unsafeRaw: orderClause)").all()
            }
            return sql.raw("\(unsafeRaw: Self.baseSelectSQL) \(unsafeRaw: orderClause)").all()
        }

        return try rows.map(Self.decodeCommand)
    }

    func search(keyword: String, limit: Int = 20) async throws -> [Command] {
        let normalizedLimit = max(1, min(limit, 100))
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            if trimmed.isEmpty {
                return sql
                    .raw("\(unsafeRaw: Self.baseSelectSQL) ORDER BY is_pinned DESC, copy_count DESC, last_copied_at DESC, title ASC LIMIT \(unsafeRaw: String(normalizedLimit))")
                    .all()
            }

            let pattern = "%\(trimmed)%"
            return sql.raw(
                """
                \(unsafeRaw: Self.baseSelectSQL)
                WHERE title LIKE \(bind: pattern)
                   OR content LIKE \(bind: pattern)
                   OR description LIKE \(bind: pattern)
                ORDER BY is_pinned DESC, copy_count DESC, last_copied_at DESC, title ASC
                LIMIT \(unsafeRaw: String(normalizedLimit))
                """
            ).all()
        }

        return try rows.map(Self.decodeCommand)
    }

    func get(id: UUID) async throws -> Command? {
        let row: SQLRow? = try await poolProvider.withSQL { sql in
            sql.raw("\(unsafeRaw: Self.baseSelectSQL) WHERE id = \(bind: id.uuidString) LIMIT 1").first()
        }
        guard let row else { return nil }
        return try Self.decodeCommand(row)
    }

    func upsert(_ command: Command) async throws {
        let now = MySQLDateCodec.toString(Date())
        let createdAt = MySQLDateCodec.toString(command.createdAt) ?? now
        let updatedAt = MySQLDateCodec.toString(command.updatedAt) ?? now
        let lastCopiedAt = MySQLDateCodec.toString(command.lastCopiedAt)

        _ = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                INSERT INTO commands (
                    id, title, content, description, shell, risk_level, group_name,
                    is_pinned, copy_count, last_copied_at, created_at, updated_at
                ) VALUES (
                    \(bind: command.id.uuidString),
                    \(bind: command.title),
                    \(bind: command.content),
                    \(bind: command.description),
                    \(bind: command.shell),
                    \(bind: command.riskLevel),
                    \(bind: command.groupName),
                    \(bind: command.isPinned ? 1 : 0),
                    \(bind: command.copyCount),
                    \(bind: lastCopiedAt),
                    \(bind: createdAt),
                    \(bind: updatedAt)
                )
                ON DUPLICATE KEY UPDATE
                    title = VALUES(title),
                    content = VALUES(content),
                    description = VALUES(description),
                    shell = VALUES(shell),
                    risk_level = VALUES(risk_level),
                    group_name = VALUES(group_name),
                    is_pinned = VALUES(is_pinned),
                    updated_at = VALUES(updated_at)
                """
            ).run()
        }
    }

    func delete(id: UUID) async throws {
        _ = try await poolProvider.withSQL { sql in
            sql.raw("DELETE FROM commands WHERE id = \(bind: id.uuidString)").run()
        }
    }

    func recordCopy(id: UUID) async throws {
        let eventID = UUID().uuidString
        let itemID = id.uuidString

        _ = try await poolProvider.withConnection { connection in
            let sql = connection.sql()
            return connection.simpleQuery("START TRANSACTION").map { _ in () }
                .flatMap {
                    sql.raw(
                        """
                        UPDATE commands
                        SET copy_count = copy_count + 1,
                            last_copied_at = UTC_TIMESTAMP()
                        WHERE id = \(bind: itemID)
                        """
                    ).run()
                }
                .flatMap {
                    sql.raw(
                        """
                        INSERT INTO usage_events (id, item_type, item_id, event_type, created_at)
                        VALUES (
                            \(bind: eventID),
                            'cmd',
                            \(bind: itemID),
                            'copy',
                            UTC_TIMESTAMP()
                        )
                        """
                    ).run()
                }
                .flatMap {
                    connection.simpleQuery("COMMIT").map { _ in () }
                }
                .flatMapError { error in
                    connection.simpleQuery("ROLLBACK").flatMapThrowing { _ in
                        throw error
                    }
                }
        }
    }

    private static let baseSelectSQL = """
    SELECT
        id,
        title,
        content,
        description,
        shell,
        risk_level,
        group_name,
        is_pinned,
        copy_count,
        DATE_FORMAT(last_copied_at, '%Y-%m-%d %H:%i:%s') AS last_copied_at,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
        DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
    FROM commands
    """

    private static func decodeCommand(_ row: SQLRow) throws -> Command {
        let idString = try row.decode(column: "id", as: String.self)
        guard let id = UUID(uuidString: idString) else {
            throw AppError.queryFailed("Invalid UUID in commands.id")
        }

        return Command(
            id: id,
            title: try row.decode(column: "title", as: String.self),
            content: try row.decode(column: "content", as: String.self),
            description: try row.decode(column: "description", as: String?.self),
            shell: try row.decode(column: "shell", as: String.self),
            riskLevel: try row.decode(column: "risk_level", as: Int.self),
            groupName: try row.decode(column: "group_name", as: String.self),
            isPinned: (try row.decode(column: "is_pinned", as: Int.self)) != 0,
            copyCount: try row.decode(column: "copy_count", as: Int.self),
            lastCopiedAt: MySQLDateCodec.fromString(try row.decode(column: "last_copied_at", as: String?.self)),
            createdAt: MySQLDateCodec.fromString(try row.decode(column: "created_at", as: String.self)) ?? Date(),
            updatedAt: MySQLDateCodec.fromString(try row.decode(column: "updated_at", as: String.self)) ?? Date()
        )
    }
}
