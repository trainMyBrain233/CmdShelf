import Foundation
import SQLKit

protocol UsageRepositoryProtocol {
    func add(itemType: UsageItemType, itemID: UUID, eventType: UsageEventType) async throws
    func listRecent(limit: Int) async throws -> [UsageEvent]
}

final class UsageRepository: UsageRepositoryProtocol {
    private let poolProvider: MySQLPoolProvider

    init(poolProvider: MySQLPoolProvider) {
        self.poolProvider = poolProvider
    }

    func add(itemType: UsageItemType, itemID: UUID, eventType: UsageEventType) async throws {
        let id = UUID().uuidString
        _ = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                INSERT INTO usage_events (id, item_type, item_id, event_type, created_at)
                VALUES (
                    \(bind: id),
                    \(bind: itemType.rawValue),
                    \(bind: itemID.uuidString),
                    \(bind: eventType.rawValue),
                    UTC_TIMESTAMP()
                )
                """
            ).run()
        }
    }

    func listRecent(limit: Int = 100) async throws -> [UsageEvent] {
        let normalizedLimit = max(1, min(limit, 500))
        let rows: [SQLRow] = try await poolProvider.withSQL { sql in
            sql.raw(
                """
                SELECT
                    id,
                    item_type,
                    item_id,
                    event_type,
                    DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at
                FROM usage_events
                ORDER BY created_at DESC
                LIMIT \(unsafeRaw: String(normalizedLimit))
                """
            ).all()
        }

        return try rows.compactMap { row in
            guard
                let id = UUID(uuidString: try row.decode(column: "id", as: String.self)),
                let itemID = UUID(uuidString: try row.decode(column: "item_id", as: String.self)),
                let itemType = UsageItemType(rawValue: try row.decode(column: "item_type", as: String.self)),
                let eventType = UsageEventType(rawValue: try row.decode(column: "event_type", as: String.self))
            else {
                return nil
            }

            return UsageEvent(
                id: id,
                itemType: itemType,
                itemID: itemID,
                eventType: eventType,
                createdAt: MySQLDateCodec.fromString(try row.decode(column: "created_at", as: String.self)) ?? Date()
            )
        }
    }
}
