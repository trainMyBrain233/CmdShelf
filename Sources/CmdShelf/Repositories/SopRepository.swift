import Foundation
import MySQLKit
import SQLKit

protocol SopRepositoryProtocol {
    func list(group: String?) async throws -> [Sop]
    func search(keyword: String, limit: Int) async throws -> [Sop]
    func get(id: UUID) async throws -> Sop?
    func upsert(_ sop: Sop) async throws
    func delete(id: UUID) async throws
    func recordCopy(id: UUID) async throws
}

final class SopRepository: SopRepositoryProtocol {
    private let poolProvider: MySQLPoolProvider

    init(poolProvider: MySQLPoolProvider) {
        self.poolProvider = poolProvider
    }

    func list(group: String?) async throws -> [Sop] {
        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            if let group, !group.isEmpty {
                return sql.raw("\(unsafeRaw: Self.baseSelectSQL) WHERE group_name = \(bind: group) ORDER BY copy_count DESC, last_used_at DESC, title ASC").all()
            }
            return sql.raw("\(unsafeRaw: Self.baseSelectSQL) ORDER BY copy_count DESC, last_used_at DESC, title ASC").all()
        }

        return try rows.map(Self.decodeSop)
    }

    func search(keyword: String, limit: Int = 20) async throws -> [Sop] {
        let normalizedLimit = max(1, min(limit, 100))
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            if trimmed.isEmpty {
                return sql
                    .raw("\(unsafeRaw: Self.baseSelectSQL) ORDER BY copy_count DESC, last_used_at DESC, title ASC LIMIT \(unsafeRaw: String(normalizedLimit))")
                    .all()
            }

            let pattern = "%\(trimmed)%"
            return sql.raw(
                """
                \(unsafeRaw: Self.baseSelectSQL)
                WHERE title LIKE \(bind: pattern)
                   OR body_markdown LIKE \(bind: pattern)
                ORDER BY copy_count DESC, last_used_at DESC, title ASC
                LIMIT \(unsafeRaw: String(normalizedLimit))
                """
            ).all()
        }

        return try rows.map(Self.decodeSop)
    }

    func get(id: UUID) async throws -> Sop? {
        let row: SQLRow? = try await poolProvider.withSQL { sql in
            sql.raw("\(unsafeRaw: Self.baseSelectSQL) WHERE id = \(bind: id.uuidString) LIMIT 1").first()
        }
        guard let row else { return nil }
        return try Self.decodeSop(row)
    }

    func upsert(_ sop: Sop) async throws {
        let now = MySQLDateCodec.toString(Date())
        let createdAt = MySQLDateCodec.toString(sop.createdAt) ?? now
        let updatedAt = MySQLDateCodec.toString(sop.updatedAt) ?? now
        let lastUsedAt = MySQLDateCodec.toString(sop.lastUsedAt)

        _ = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                INSERT INTO sops (
                    id, title, body_markdown, group_name,
                    copy_count, last_used_at, created_at, updated_at
                ) VALUES (
                    \(bind: sop.id.uuidString),
                    \(bind: sop.title),
                    \(bind: sop.bodyMarkdown),
                    \(bind: sop.groupName),
                    \(bind: sop.copyCount),
                    \(bind: lastUsedAt),
                    \(bind: createdAt),
                    \(bind: updatedAt)
                )
                ON DUPLICATE KEY UPDATE
                    title = VALUES(title),
                    body_markdown = VALUES(body_markdown),
                    group_name = VALUES(group_name),
                    updated_at = VALUES(updated_at)
                """
            ).run()
        }
    }

    func delete(id: UUID) async throws {
        _ = try await poolProvider.withSQL { sql in
            sql.raw("DELETE FROM sops WHERE id = \(bind: id.uuidString)").run()
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
                        UPDATE sops
                        SET copy_count = copy_count + 1,
                            last_used_at = UTC_TIMESTAMP()
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
                            'sop',
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
        body_markdown,
        group_name,
        copy_count,
        DATE_FORMAT(last_used_at, '%Y-%m-%d %H:%i:%s') AS last_used_at,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
        DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
    FROM sops
    """

    private static func decodeSop(_ row: SQLRow) throws -> Sop {
        let idString = try row.decode(column: "id", as: String.self)
        guard let id = UUID(uuidString: idString) else {
            throw AppError.queryFailed("Invalid UUID in sops.id")
        }

        return Sop(
            id: id,
            title: try row.decode(column: "title", as: String.self),
            bodyMarkdown: try row.decode(column: "body_markdown", as: String.self),
            groupName: try row.decode(column: "group_name", as: String.self),
            copyCount: try row.decode(column: "copy_count", as: Int.self),
            lastUsedAt: MySQLDateCodec.fromString(try row.decode(column: "last_used_at", as: String?.self)),
            createdAt: MySQLDateCodec.fromString(try row.decode(column: "created_at", as: String.self)) ?? Date(),
            updatedAt: MySQLDateCodec.fromString(try row.decode(column: "updated_at", as: String.self)) ?? Date()
        )
    }
}
