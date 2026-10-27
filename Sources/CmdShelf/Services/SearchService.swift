import Foundation

enum SearchResult: Identifiable, Hashable {
    case command(Command)
    case sop(Sop)

    var id: String {
        switch self {
        case .command(let command):
            return "cmd:\(command.id.uuidString)"
        case .sop(let sop):
            return "sop:\(sop.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .command(let command):
            return command.title
        case .sop(let sop):
            return sop.title
        }
    }

    var groupName: String {
        switch self {
        case .command(let command):
            return command.groupName
        case .sop(let sop):
            return sop.groupName
        }
    }

    var copyCount: Int {
        switch self {
        case .command(let command):
            return command.copyCount
        case .sop(let sop):
            return sop.copyCount
        }
    }

    var isPinned: Bool {
        switch self {
        case .command(let command):
            return command.isPinned
        case .sop:
            return false
        }
    }

    var lastUsedAt: Date? {
        switch self {
        case .command(let command):
            return command.lastCopiedAt
        case .sop(let sop):
            return sop.lastUsedAt
        }
    }

    var typeLabel: String {
        switch self {
        case .command:
            return "CMD"
        case .sop:
            return "SOP"
        }
    }
}

protocol SearchServiceProtocol {
    func search(query: String, limit: Int) async throws -> [SearchResult]
}

final class SearchService: SearchServiceProtocol {
    private let commandRepository: CommandRepositoryProtocol
    private let sopRepository: SopRepositoryProtocol

    init(commandRepository: CommandRepositoryProtocol, sopRepository: SopRepositoryProtocol) {
        self.commandRepository = commandRepository
        self.sopRepository = sopRepository
    }

    func search(query: String, limit: Int = 20) async throws -> [SearchResult] {
        async let commands = commandRepository.search(keyword: query, limit: limit)
        async let sops = sopRepository.search(keyword: query, limit: limit)

        let commandResults = try await commands.map { SearchResult.command($0) }
        let sopResults = try await sops.map { SearchResult.sop($0) }

        return (commandResults + sopResults)
            .sorted(by: Self.compare)
            .prefix(limit)
            .map { $0 }
    }

    private static func compare(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        if lhs.copyCount != rhs.copyCount {
            return lhs.copyCount > rhs.copyCount
        }

        switch (lhs.lastUsedAt, rhs.lastUsedAt) {
        case let (.some(left), .some(right)) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
