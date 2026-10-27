import Foundation

struct Command: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var content: String
    var description: String?
    var shell: String
    var riskLevel: Int
    var groupName: String
    var isPinned: Bool
    var copyCount: Int
    var lastCopiedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        description: String? = nil,
        shell: String = "any",
        riskLevel: Int = 0,
        groupName: String = "General",
        isPinned: Bool = false,
        copyCount: Int = 0,
        lastCopiedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.description = description
        self.shell = shell
        self.riskLevel = riskLevel
        self.groupName = groupName
        self.isPinned = isPinned
        self.copyCount = copyCount
        self.lastCopiedAt = lastCopiedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
