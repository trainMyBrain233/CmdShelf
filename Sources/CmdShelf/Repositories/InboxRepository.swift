import Foundation
import SQLKit

protocol InboxRepositoryProtocol {
    func add(rawText: String, detectedType: InboxDetectedType) async throws
    func list() async throws -> [InboxItem]
    func delete(id: UUID) async throws
}

final class InboxRepository: InboxRepositoryProtocol {
    private let poolProvider: MySQLPoolProvider

    init(poolProvider: MySQLPoolProvider) {
        self.poolProvider = poolProvider
    }

    func add(rawText: String, detectedType: InboxDetectedType) async throws {
        let id = UUID().uuidString
        let createdAt = MySQLDateCodec.toString(Date())

        _ = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                INSERT INTO inbox_items (id, raw_text, detected_type, created_at)
                VALUES (
                    \(bind: id),
                    \(bind: rawText),
                    \(bind: detectedType.rawValue),
                    \(bind: createdAt)
                )
                """
            ).run()
        }
    }

    func list() async throws -> [InboxItem] {
        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                SELECT
                    id,
                    raw_text,
                    detected_type,
                    DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at
                FROM inbox_items
                ORDER BY created_at DESC
                """
            ).all()
        }

        return try rows.map(Self.decodeInboxItem)
    }

    func delete(id: UUID) async throws {
        _ = try await poolProvider.withSQL { sql in
            sql.raw("DELETE FROM inbox_items WHERE id = \(bind: id.uuidString)").run()
        }
    }

    private static func decodeInboxItem(_ row: SQLRow) throws -> InboxItem {
        let idString = try row.decode(column: "id", as: String.self)
        guard let id = UUID(uuidString: idString) else {
            throw AppError.queryFailed("Invalid UUID in inbox_items.id")
        }

        let typeRaw = try row.decode(column: "detected_type", as: String.self)
        let type = InboxDetectedType(rawValue: typeRaw) ?? .text

        return InboxItem(
            id: id,
            rawText: try row.decode(column: "raw_text", as: String.self),
            detectedType: type,
            createdAt: MySQLDateCodec.fromString(try row.decode(column: "created_at", as: String.self)) ?? Date()
        )
    }
}
