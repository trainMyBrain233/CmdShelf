import Foundation
import MySQLKit
import NIOCore
import NIOPosix
import SQLKit

final class MySQLPoolProvider {
    private let eventLoopGroup: EventLoopGroup
    private var pool: EventLoopGroupConnectionPool<MySQLConnectionSource>?

    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        pool?.shutdown()
        try? eventLoopGroup.syncShutdownGracefully()
    }

    func rebuildPool(with config: MySQLConfig) async throws {
        let effectiveConfig = config.normalizedForLocalUse()
        if let pool {
            try? await pool.shutdownAsync()
        }

        let source = MySQLConnectionSource(configuration: mysqlConfiguration(from: effectiveConfig, includeDatabase: true))
        let newPool = EventLoopGroupConnectionPool(source: source, on: eventLoopGroup)

        do {
            _ = try await newPool.withConnection { connection in
                connection.sql().raw("SELECT 1").run()
            }.get()
        } catch {
            try? await newPool.shutdownAsync()
            throw AppError.queryFailed(error.localizedDescription)
        }

        pool = newPool
    }

    func shutdown() {
        pool?.shutdown()
        pool = nil
    }

    func testConnection(_ config: MySQLConfig) async throws {
        let effectiveConfig = config.normalizedForLocalUse()
        try await withTemporaryConnection(config: effectiveConfig, includeDatabase: false) { connection in
            connection.sql().raw("SELECT 1").run()
        }
    }

    func withConnection<T>(
        _ body: @escaping (MySQLConnection) -> EventLoopFuture<T>
    ) async throws -> T {
        guard let pool else {
            throw AppError.databaseDisconnected
        }
        return try await pool.withConnection(body).get()
    }

    func withSQL<T>(
        _ body: @escaping (SQLDatabase) -> EventLoopFuture<T>
    ) async throws -> T {
        try await withConnection { connection in
            body(connection.sql())
        }
    }

    func withTemporaryConnection<T>(
        config: MySQLConfig,
        includeDatabase: Bool,
        _ body: @escaping (MySQLConnection) -> EventLoopFuture<T>
    ) async throws -> T {
        let effectiveConfig = config.normalizedForLocalUse()
        let source = MySQLConnectionSource(
            configuration: mysqlConfiguration(from: effectiveConfig, includeDatabase: includeDatabase)
        )
        let temporaryPool = EventLoopGroupConnectionPool(source: source, on: eventLoopGroup)
        do {
            let result = try await temporaryPool.withConnection(body).get()
            try? await temporaryPool.shutdownAsync()
            return result
        } catch {
            try? await temporaryPool.shutdownAsync()
            throw error
        }
    }

    private func mysqlConfiguration(from config: MySQLConfig, includeDatabase: Bool) -> MySQLConfiguration {
        let targetDatabase = includeDatabase ? config.database : MySQLConfig.bootstrapDatabase
        let dbLabel = includeDatabase ? config.database : "\(MySQLConfig.bootstrapDatabase) (bootstrap)"
        print(
            "[CmdShelf] mysqlConfiguration host=\(config.host) port=\(config.port) user=\(config.username) includeDatabase=\(includeDatabase) database=\(dbLabel)"
        )
        return MySQLConfiguration(
            hostname: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: targetDatabase,
            tlsConfiguration: nil
        )
    }
}
