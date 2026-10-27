import Foundation

enum AppError: Error, LocalizedError, Identifiable {
    case databaseDisconnected
    case migrationFailed(String)
    case queryFailed(String)
    case validationFailed(String)
    case clipboardUnavailable
    case configurationInvalid(String)
    case unknown(String)

    var id: String {
        switch self {
        case .databaseDisconnected:
            return "databaseDisconnected"
        case .migrationFailed(let message):
            return "migrationFailed:\(message)"
        case .queryFailed(let message):
            return "queryFailed:\(message)"
        case .validationFailed(let message):
            return "validationFailed:\(message)"
        case .clipboardUnavailable:
            return "clipboardUnavailable"
        case .configurationInvalid(let message):
            return "configurationInvalid:\(message)"
        case .unknown(let message):
            return "unknown:\(message)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .databaseDisconnected:
            return "Database disconnected"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .clipboardUnavailable:
            return "Clipboard is unavailable"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        case .unknown(let message):
            return "Unexpected error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .databaseDisconnected:
            return "Check CMDSHELF_MYSQL_* environment variables and verify the configured MySQL user can access the database with CREATE/ALTER privileges."
        case .migrationFailed:
            return "Check database permissions and ensure cmdshelf database can be created."
        case .queryFailed:
            return "Verify schema and connectivity, then retry."
        case .validationFailed:
            return "Please fix required fields and retry."
        case .clipboardUnavailable:
            return "Try again after granting clipboard access if prompted by macOS."
        case .configurationInvalid:
            return "Update Settings with valid MySQL connection details."
        case .unknown:
            return "Retry. If this persists, inspect logs in Console.app."
        }
    }
}

enum DBStatus: Equatable {
    case connected
    case disconnected
    case testing
}

enum MainTab: String, CaseIterable, Identifiable {
    case commands
    case sops
    case inbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commands: return "Commands"
        case .sops: return "SOPs"
        case .inbox: return "Inbox"
        }
    }
}
