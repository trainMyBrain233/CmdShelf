import Foundation
import MySQLKit
import NIOCore
import SQLKit

final class MigrationRunner {
    private let poolProvider: MySQLPoolProvider

    init(poolProvider: MySQLPoolProvider) {
        self.poolProvider = poolProvider
    }

    func runMigrations(config: MySQLConfig) async throws {
        let effectiveConfig = config.normalizedForLocalUse()
        do {
            try await createDatabaseIfNeeded(config: effectiveConfig)
            try await createTables(config: effectiveConfig)
            try await createIndexes(config: effectiveConfig)
        } catch {
            throw AppError.migrationFailed(error.localizedDescription)
        }
    }

    private func createDatabaseIfNeeded(config: MySQLConfig) async throws {
        let statement = "CREATE DATABASE IF NOT EXISTS \(quotedIdentifier(config.database)) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        do {
            try await poolProvider.withTemporaryConnection(config: config, includeDatabase: false) { connection in
                connection.simpleQuery(statement).map { _ in () }
            }
        } catch {
            guard isPrivilegeError(error) else { throw error }
            try await verifyDatabaseAccessible(config: config)
        }
    }

    private func createTables(config: MySQLConfig) async throws {
        let tableDefinitions: [(name: String, statement: String)] = [
            ("commands",
            """
            CREATE TABLE IF NOT EXISTS commands (
              id CHAR(36) PRIMARY KEY,
              title VARCHAR(255) NOT NULL,
              content TEXT NOT NULL,
              description TEXT NULL,
              shell VARCHAR(32) NOT NULL DEFAULT 'any',
              risk_level TINYINT NOT NULL DEFAULT 0,
              group_name VARCHAR(128) NOT NULL DEFAULT 'General',
              is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
              copy_count INT NOT NULL DEFAULT 0,
              last_copied_at DATETIME NULL,
              created_at DATETIME NOT NULL,
              updated_at DATETIME NOT NULL
            )
            """),
            ("sops",
            """
            CREATE TABLE IF NOT EXISTS sops (
              id CHAR(36) PRIMARY KEY,
              title VARCHAR(255) NOT NULL,
              body_markdown LONGTEXT NOT NULL,
              group_name VARCHAR(128) NOT NULL DEFAULT 'General',
              copy_count INT NOT NULL DEFAULT 0,
              last_used_at DATETIME NULL,
              created_at DATETIME NOT NULL,
              updated_at DATETIME NOT NULL
            )
            """),
            ("inbox_items",
            """
            CREATE TABLE IF NOT EXISTS inbox_items (
              id CHAR(36) PRIMARY KEY,
              raw_text LONGTEXT NOT NULL,
              detected_type VARCHAR(16) NOT NULL,
              created_at DATETIME NOT NULL
            )
            """),
            ("usage_events",
            """
            CREATE TABLE IF NOT EXISTS usage_events (
              id CHAR(36) PRIMARY KEY,
              item_type VARCHAR(16) NOT NULL,
              item_id CHAR(36) NOT NULL,
              event_type VARCHAR(16) NOT NULL,
              created_at DATETIME NOT NULL,
              INDEX idx_usage_item_time (item_type, item_id, created_at)
            )
            """)
        ]

        do {
            try await poolProvider.withTemporaryConnection(config: config, includeDatabase: true) { connection in
                var chain = connection.eventLoop.makeSucceededFuture(())

                for tableDefinition in tableDefinitions {
                    chain = chain.flatMap {
                        connection.simpleQuery(tableDefinition.statement).map { _ in () }
                    }
                }

                return chain
            }
        } catch {
            guard isPrivilegeError(error) else { throw error }
            try await verifyTablesExist(config: config, names: tableDefinitions.map(\.name))
        }
    }

    private func createIndexes(config: MySQLConfig) async throws {
        let indexes: [(table: String, name: String, statement: String)] = [
            ("commands", "idx_commands_group", "CREATE INDEX idx_commands_group ON commands(group_name)"),
            ("commands", "idx_commands_copy", "CREATE INDEX idx_commands_copy ON commands(copy_count)"),
            ("commands", "idx_commands_last", "CREATE INDEX idx_commands_last ON commands(last_copied_at)"),
            ("sops", "idx_sops_group", "CREATE INDEX idx_sops_group ON sops(group_name)"),
            ("sops", "idx_sops_last", "CREATE INDEX idx_sops_last ON sops(last_used_at)")
        ]

        do {
            try await poolProvider.withTemporaryConnection(config: config, includeDatabase: true) { connection in
                let sql = connection.sql()

                func ensure(_ index: (table: String, name: String, statement: String)) -> EventLoopFuture<Void> {
                    sql.raw(
                        """
                        SELECT COUNT(1) AS count_value
                        FROM information_schema.statistics
                        WHERE table_schema = \(bind: config.database)
                          AND table_name = \(bind: index.table)
                          AND index_name = \(bind: index.name)
                        """
                    )
                    .first()
                    .flatMap { row in
                        let count = (try? row?.decode(column: "count_value", as: Int.self)) ?? 0
                        if count > 0 {
                            return sql.eventLoop.makeSucceededFuture(())
                        }
                        return connection.simpleQuery(index.statement).map { _ in () }
                    }
                }

                var chain = sql.eventLoop.makeSucceededFuture(())
                for index in indexes {
                    chain = chain.flatMap {
                        ensure(index)
                    }
                }
                return chain
            }
        } catch {
            guard isPrivilegeError(error) else { throw error }
        }
    }

    private func verifyDatabaseAccessible(config: MySQLConfig) async throws {
        try await poolProvider.withTemporaryConnection(config: config, includeDatabase: true) { connection in
            connection.sql().raw("SELECT 1").run()
        }
    }

    private func verifyTablesExist(config: MySQLConfig, names: [String]) async throws {
        try await poolProvider.withTemporaryConnection(config: config, includeDatabase: true) { connection in
            let sql = connection.sql()
            var chain = sql.eventLoop.makeSucceededFuture(())
            for tableName in names {
                let probe: SQLQueryString = "SELECT 1 FROM `\(unsafeRaw: tableName)` LIMIT 1"
                chain = chain.flatMap {
                    sql.raw(probe).run()
                }
            }
            return chain
        }
    }

    private func isPrivilegeError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("access denied")
            || message.contains("command denied")
            || message.contains("privilege")
            || message.contains("not authorized")
    }

    private func quotedIdentifier(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }
}
