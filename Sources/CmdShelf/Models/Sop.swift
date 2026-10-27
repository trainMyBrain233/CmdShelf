import Foundation

struct Sop: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var bodyMarkdown: String
    var groupName: String
    var copyCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String,
        groupName: String = "General",
        copyCount: Int = 0,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.groupName = groupName
        self.copyCount = copyCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
