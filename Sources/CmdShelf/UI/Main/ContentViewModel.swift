import Foundation

@MainActor
final class CmdShelfWorkspaceViewModel: ObservableObject {
    enum SidebarSelection: Hashable {
        case allCommands
        case sops
        case inbox
        case mostUsed
        case recentlyAdded
        case tag(String)
    }

    enum ContentFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case commandsOnly = "Commands"
        case sopsOnly = "SOPs"
        case pinnedOnly = "Pinned"

        var id: String { rawValue }
    }

    @Published var searchText: String = ""
    @Published var sidebarSelection: SidebarSelection = .allCommands
    @Published var filter: ContentFilter = .all
    @Published var selectedItemID: UUID?

    @Published private(set) var commands: [Command] = []
    @Published private(set) var sops: [Sop] = []
    @Published private(set) var inboxItems: [InboxItem] = []
    @Published private(set) var categories: [CmdShelfDesign.Category] = []
    @Published private(set) var inboxUnreadCount: Int = 0
    @Published private(set) var isDatabaseConnected: Bool = false

    private weak var appState: AppState?

    func attach(appState: AppState) {
        self.appState = appState
        sync(from: appState)
    }

    func sync(from appState: AppState) {
        let newCommands = appState.commands
        let newSops = appState.sops
        let newInboxItems = appState.inboxItems
        let newInboxUnreadCount = newInboxItems.count
        let newIsDatabaseConnected = appState.isDatabaseConnected
        let newCategories = buildCategories(
            groups: appState.availableGroups,
            commands: newCommands,
            sops: newSops
        )

        if commands != newCommands {
            commands = newCommands
        }
        if sops != newSops {
            sops = newSops
        }
        if inboxItems != newInboxItems {
            inboxItems = newInboxItems
        }
        if inboxUnreadCount != newInboxUnreadCount {
            inboxUnreadCount = newInboxUnreadCount
        }
        if isDatabaseConnected != newIsDatabaseConnected {
            isDatabaseConnected = newIsDatabaseConnected
        }
        if categories != newCategories {
            categories = newCategories
        }

        if case .tag(let tag) = sidebarSelection,
           !newCategories.contains(where: { $0.name.caseInsensitiveCompare(tag) == .orderedSame }) {
            sidebarSelection = .allCommands
        }
        normalizeSelection()
    }

    var visibleItems: [CmdShelfDesign.LibraryItem] {
        let scoped: [CmdShelfDesign.LibraryItem] = {
            switch sidebarSelection {
            case .allCommands:
                return sortItemsByHeatThenTime(commands.map { .command($0) })
            case .sops:
                return sortItemsByHeatThenTime(sops.map { .sop($0) })
            case .inbox:
                return inboxItems
                    .sorted(by: { $0.createdAt > $1.createdAt })
                    .map { .inbox($0) }
            case .mostUsed:
                return sortItemsByHeatThenTime(allItems)
                    .filter {
                        if case .inbox = $0 { return false }
                        return true
                    }
            case .recentlyAdded:
                return allItems.sorted { $0.createdAt > $1.createdAt }
            case .tag(let tag):
                return sortItemsByHeatThenTime(allItems.filter { item in
                    switch item {
                    case .command(let command):
                        return command.groupName.caseInsensitiveCompare(tag) == .orderedSame
                    case .sop(let sop):
                        return sop.groupName.caseInsensitiveCompare(tag) == .orderedSame
                    case .inbox:
                        return false
                    }
                })
            }
        }()

        let filterSource: [CmdShelfDesign.LibraryItem] = {
            switch filter {
            case .all:
                return scoped
            case .commandsOnly, .sopsOnly, .pinnedOnly:
                // Search mode filter should work globally instead of being blocked by sidebar scope.
                return sortItemsByHeatThenTime(allItems)
            }
        }()

        let byFilter = filterSource.filter { item in
            switch filter {
            case .all:
                return true
            case .commandsOnly:
                if case .command = item { return true }
                return false
            case .sopsOnly:
                if case .sop = item { return true }
                return false
            case .pinnedOnly:
                if case .command(let command) = item {
                    return command.isPinned
                }
                return false
            }
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return byFilter }

        return byFilter.filter { item in
            if item.title.localizedCaseInsensitiveContains(keyword) { return true }
            if item.preview.localizedCaseInsensitiveContains(keyword) { return true }
            if item.category.localizedCaseInsensitiveContains(keyword) { return true }

            switch item {
            case .command(let command):
                return command.content.localizedCaseInsensitiveContains(keyword)
                    || (command.description ?? "").localizedCaseInsensitiveContains(keyword)
            case .sop(let sop):
                return sop.bodyMarkdown.localizedCaseInsensitiveContains(keyword)
            case .inbox(let inbox):
                return inbox.rawText.localizedCaseInsensitiveContains(keyword)
            }
        }
    }

    var selectedItem: CmdShelfDesign.LibraryItem? {
        if let selectedItemID, let exact = visibleItems.first(where: { $0.id == selectedItemID }) {
            return exact
        }
        return visibleItems.first
    }

    func select(_ item: CmdShelfDesign.LibraryItem) {
        selectedItemID = item.id
    }

    func isSelected(_ item: CmdShelfDesign.LibraryItem) -> Bool {
        item.id == selectedItem?.id
    }

    func createNewCommand() {
        let preferredGroup = categories.first?.name ?? "General"
        let command = Command(
            title: "New Command",
            content: "echo \"hello from CmdShelf\"",
            description: nil,
            groupName: preferredGroup,
            isPinned: true
        )
        saveCommand(command)
    }

    func saveCommand(_ command: Command) {
        guard let appState else { return }
        sidebarSelection = .allCommands
        selectedItemID = command.id
        Task {
            _ = await appState.saveCommand(command)
        }
    }

    func deleteCommand(_ command: Command) {
        guard let appState else { return }
        if selectedItemID == command.id {
            selectedItemID = nil
        }
        Task {
            await appState.deleteCommand(id: command.id)
        }
    }

    func saveSop(_ sop: Sop) {
        guard let appState else { return }
        sidebarSelection = .sops
        selectedItemID = sop.id
        Task {
            _ = await appState.saveSop(sop)
        }
    }

    func deleteSop(_ sop: Sop) {
        guard let appState else { return }
        if selectedItemID == sop.id {
            selectedItemID = nil
        }
        Task {
            await appState.deleteSop(id: sop.id)
        }
    }

    func copy(item: CmdShelfDesign.LibraryItem) {
        guard let appState else { return }
        switch item {
        case .command(let command):
            appState.copyCommand(command)
        case .sop(let sop):
            let block = CodeBlock(language: nil, content: sop.bodyMarkdown, range: nil, origin: .fenced)
            appState.copyCodeBlock(block, from: sop)
        case .inbox:
            break
        }
    }

    func convertInboxToCommand(_ inboxItem: InboxItem) {
        guard let appState else { return }
        Task {
            await appState.moveInboxItemToCommand(inboxItem)
        }
    }

    func convertInboxToSop(_ inboxItem: InboxItem) {
        guard let appState else { return }
        Task {
            await appState.moveInboxItemToSop(inboxItem)
        }
    }

    func deleteInbox(_ inboxItem: InboxItem) {
        guard let appState else { return }
        Task {
            await appState.deleteInboxItem(id: inboxItem.id)
        }
    }

    func addGroup(named name: String) {
        guard let appState else { return }
        appState.addCustomGroup(name: name)
        sync(from: appState)
    }

    func renameGroup(from oldName: String, to newName: String) {
        guard let appState else { return }
        if case .tag(let selectedTag) = sidebarSelection,
           selectedTag.caseInsensitiveCompare(oldName) == .orderedSame {
            sidebarSelection = .tag(newName)
        }
        Task {
            await appState.renameGroup(from: oldName, to: newName)
        }
    }

    func deleteGroup(named name: String) {
        guard let appState else { return }
        Task {
            await appState.deleteGroup(name: name)
        }
    }

    private var allItems: [CmdShelfDesign.LibraryItem] {
        commands.map { .command($0) }
            + sops.map { .sop($0) }
            + inboxItems.map { .inbox($0) }
    }

    private func normalizeSelection() {
        guard let selectedItemID else {
            self.selectedItemID = visibleItems.first?.id
            return
        }

        if !visibleItems.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = visibleItems.first?.id
        }
    }

    private func buildCategories(groups: [String], commands: [Command], sops: [Sop]) -> [CmdShelfDesign.Category] {
        let scoredGroups = groups
            .filter { $0.caseInsensitiveCompare("General") != .orderedSame }
            .map { group -> (name: String, heat: Int, latest: Date) in
                let matchedCommands = commands.filter {
                    $0.groupName.caseInsensitiveCompare(group) == .orderedSame
                }
                let matchedSops = sops.filter {
                    $0.groupName.caseInsensitiveCompare(group) == .orderedSame
                }

                let heat = matchedCommands.reduce(0, { $0 + $1.copyCount })
                    + matchedSops.reduce(0, { $0 + $1.copyCount })

                let latestCommandTime = matchedCommands.map { $0.lastCopiedAt ?? $0.updatedAt }.max()
                let latestSopTime = matchedSops.map { $0.lastUsedAt ?? $0.updatedAt }.max()
                let latest = [latestCommandTime, latestSopTime]
                    .compactMap { $0 }
                    .max() ?? Date.distantPast

                return (group, heat, latest)
            }
            .sorted { lhs, rhs in
                if lhs.heat != rhs.heat {
                    return lhs.heat > rhs.heat
                }
                if lhs.latest != rhs.latest {
                    return lhs.latest > rhs.latest
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return scoredGroups.map { group in
            CmdShelfDesign.Category(name: group.name, symbol: symbol(for: group.name))
        }
    }

    private func sortItemsByHeatThenTime(_ items: [CmdShelfDesign.LibraryItem]) -> [CmdShelfDesign.LibraryItem] {
        items.sorted { lhs, rhs in
            let lhsIsInbox: Bool = {
                if case .inbox = lhs { return true }
                return false
            }()
            let rhsIsInbox: Bool = {
                if case .inbox = rhs { return true }
                return false
            }()

            if lhsIsInbox != rhsIsInbox {
                return !lhsIsInbox
            }

            if lhs.uses != rhs.uses {
                return lhs.uses > rhs.uses
            }

            let lhsTime = rankingTime(for: lhs)
            let rhsTime = rankingTime(for: rhs)
            if lhsTime != rhsTime {
                return lhsTime > rhsTime
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func rankingTime(for item: CmdShelfDesign.LibraryItem) -> Date {
        switch item {
        case .command(let command):
            return command.lastCopiedAt ?? command.updatedAt
        case .sop(let sop):
            return sop.lastUsedAt ?? sop.updatedAt
        case .inbox(let inbox):
            return inbox.createdAt
        }
    }

    private func symbol(for group: String) -> String {
        switch group.lowercased() {
        case "git":
            return "point.topleft.down.curvedto.point.bottomright.up"
        case "docker":
            return "shippingbox.fill"
        case "k8s", "kubernetes":
            return "hexagon.2.fill"
        case "swift":
            return "swift"
        case "ops":
            return "wrench.and.screwdriver.fill"
        default:
            return "tag.fill"
        }
    }
}
