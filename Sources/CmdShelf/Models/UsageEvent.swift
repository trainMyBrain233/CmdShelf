import Foundation

enum UsageItemType: String, CaseIterable, Codable {
    case cmd
    case sop
}

enum UsageEventType: String, CaseIterable, Codable {
    case copy
    case open
    case edit
}

struct UsageEvent: Identifiable, Hashable, Codable {
    var id: UUID
    var itemType: UsageItemType
    var itemID: UUID
    var eventType: UsageEventType
    var createdAt: Date

    init(
        id: UUID = UUID(),
        itemType: UsageItemType,
        itemID: UUID,
        eventType: UsageEventType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.itemType = itemType
        self.itemID = itemID
        self.eventType = eventType
        self.createdAt = createdAt
    }
}
