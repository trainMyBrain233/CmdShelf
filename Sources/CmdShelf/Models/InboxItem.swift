import Foundation

enum InboxDetectedType: String, CaseIterable, Codable {
    case cmd
    case sop
    case text
}

struct InboxItem: Identifiable, Hashable, Codable {
    var id: UUID
    var rawText: String
    var detectedType: InboxDetectedType
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        detectedType: InboxDetectedType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.detectedType = detectedType
        self.createdAt = createdAt
    }

    var summary: String {
        let cleaned = rawText.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count <= 80 { return cleaned }
        return String(cleaned.prefix(80)) + "..."
    }
}
