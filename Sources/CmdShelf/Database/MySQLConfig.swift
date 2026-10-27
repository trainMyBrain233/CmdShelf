import Foundation

struct MySQLConfig: Equatable, Codable {
    static let embeddedHost = ProcessInfo.processInfo.environment["CMDSHELF_MYSQL_HOST"] ?? "localhost"
    static let embeddedPort = Int(ProcessInfo.processInfo.environment["CMDSHELF_MYSQL_PORT"] ?? "") ?? 3306
    static let embeddedUsername = ProcessInfo.processInfo.environment["CMDSHELF_MYSQL_USER"] ?? "root"
    static let embeddedDatabase = ProcessInfo.processInfo.environment["CMDSHELF_MYSQL_DATABASE"] ?? "cmdshelf"
    static let bootstrapDatabase = "mysql"
    static let embeddedPassword = ProcessInfo.processInfo.environment["CMDSHELF_MYSQL_PASSWORD"] ?? ""

    var host: String
    var port: Int
    var username: String
    var database: String
    var password: String

    static let `default` = MySQLConfig(
        host: embeddedHost,
        port: embeddedPort,
        username: embeddedUsername,
        database: embeddedDatabase,
        password: embeddedPassword
    )

    func normalizedForLocalUse() -> MySQLConfig {
        var normalized = self
        if normalized.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "localhost" {
            // On some macOS setups localhost resolves to ::1 first, while MySQL listens on 127.0.0.1 only.
            normalized.host = "127.0.0.1"
        }
        return normalized
    }
}

final class MySQLConfigStore {
    private let defaults: UserDefaults
    private let configKey = "cmdshelf.mysql.config.v1"
    private let legacyPasswordKey = "cmdshelf.mysql.password.fallback"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MySQLConfig {
        .default
    }

    func save(_ config: MySQLConfig) {
        _ = config
        // Read the connection profile from the process environment; ignore persisted values.
        defaults.removeObject(forKey: configKey)
        defaults.removeObject(forKey: legacyPasswordKey)
    }
}

enum MySQLDateCodec {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func toString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return formatter.string(from: date)
    }

    static func fromString(_ string: String?) -> Date? {
        guard let string else { return nil }
        return formatter.date(from: string)
    }
}
