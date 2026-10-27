import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var dbStatus: DBStatus = .disconnected
    @Published var currentError: AppError?
    @Published var currentToast: AppToast?
    @Published var hasCompletedInitialBootstrap = false

    @Published var commands: [Command] = []
    @Published var sops: [Sop] = []
    @Published var inboxItems: [InboxItem] = []

    @Published var activeTab: MainTab = .commands
    @Published var selectedGroup: String?
    @Published var selectedCommandID: UUID?
    @Published var selectedSopID: UUID?
    @Published var selectedInboxID: UUID?
    @Published var customGroups: [String] = []

    @Published var mysqlConfig: MySQLConfig
    @Published var migrationStatusText: String = "Pending"
    @Published var paletteFocusNonce = UUID()

    private let configStore: MySQLConfigStore
    private let defaults: UserDefaults
    private let poolProvider: MySQLPoolProvider
    private let migrationRunner: MigrationRunner

    private let clipboardService: ClipboardServiceProtocol
    private let markdownExtractor: MarkdownCodeBlockExtractorProtocol
    private let hotkeyService: HotkeyService

    private var commandRepository: CommandRepositoryProtocol?
    private var sopRepository: SopRepositoryProtocol?
    private var inboxRepository: InboxRepositoryProtocol?
    private var usageRepository: UsageRepositoryProtocol?
    private var searchService: SearchServiceProtocol?

    private var didBootstrap = false
    private var didApplyCustomAppIcon = false
    private weak var mainWindow: NSWindow?
    private weak var settingsWindow: NSWindow?
    private var pendingMainWindowFocus = false
    private var pendingSettingsWindowFocus = false

    private let customGroupsKey = "cmdshelf.custom.groups.v1"

    private lazy var paletteWindowController = CommandPaletteWindowController(appState: self)

    init(
        configStore: MySQLConfigStore = MySQLConfigStore(),
        defaults: UserDefaults = .standard,
        poolProvider: MySQLPoolProvider = MySQLPoolProvider(),
        clipboardService: ClipboardServiceProtocol = ClipboardService(),
        markdownExtractor: MarkdownCodeBlockExtractorProtocol = MarkdownCodeBlockExtractor(),
        hotkeyService: HotkeyService = HotkeyService()
    ) {
        self.configStore = configStore
        self.defaults = defaults
        self.poolProvider = poolProvider
        self.migrationRunner = MigrationRunner(poolProvider: poolProvider)
        self.clipboardService = clipboardService
        self.markdownExtractor = markdownExtractor
        self.hotkeyService = hotkeyService
        self.mysqlConfig = .default
        self.customGroups = []
        self.customGroups = loadCustomGroups()

        self.hotkeyService.onOpenMainWindow = { [weak self] in
            Task { @MainActor in
                self?.handleGlobalHotkey()
            }
        }
    }

    var isDatabaseConnected: Bool {
        dbStatus == .connected
    }

    var databaseStatusLabel: String {
        switch dbStatus {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .testing: return "Testing"
        }
    }

    var availableGroups: [String] {
        var set = Set<String>()
        set.insert("General")
        for group in customGroups {
            set.insert(group)
        }
        for command in commands {
            set.insert(command.groupName)
        }
        for sop in sops {
            set.insert(sop.groupName)
        }
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var filteredCommands: [Command] {
        guard let selectedGroup, !selectedGroup.isEmpty else {
            return commands
        }
        return commands.filter { $0.groupName == selectedGroup }
    }

    var filteredSops: [Sop] {
        guard let selectedGroup, !selectedGroup.isEmpty else {
            return sops
        }
        return sops.filter { $0.groupName == selectedGroup }
    }

    var selectedCommand: Command? {
        guard let selectedCommandID else { return nil }
        return commands.first { $0.id == selectedCommandID }
    }

    var selectedSop: Sop? {
        guard let selectedSopID else { return nil }
        return sops.first { $0.id == selectedSopID }
    }

    var selectedInboxItem: InboxItem? {
        guard let selectedInboxID else { return nil }
        return inboxItems.first { $0.id == selectedInboxID }
    }

    var topCommands: [Command] {
        commands.sorted {
            if $0.copyCount != $1.copyCount {
                return $0.copyCount > $1.copyCount
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        applyCustomAppIconIfNeeded()

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        hotkeyService.register()
        await reconnectAndMigrate()
        hasCompletedInitialBootstrap = true
    }

    func assignMainWindow(_ window: NSWindow?) {
        mainWindow = window
        configureMainWindowSizeLimits(window)
        if pendingMainWindowFocus {
            focusMainWindowIfPossible()
        }
    }

    func assignSettingsWindow(_ window: NSWindow?) {
        settingsWindow = window
        if pendingSettingsWindowFocus {
            focusSettingsWindowIfPossible()
        }
    }

    func openMainWindow() {
        hideSettingsWindowIfPossible()
        closePalette()

        pendingMainWindowFocus = true
        activateAppToFront()
        focusMainWindowIfPossible()

        DispatchQueue.main.async { [weak self] in
            self?.focusMainWindowIfPossible()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.focusMainWindowIfPossible()
        }
    }

    func handleGlobalHotkey() {
        if shouldCloseMainWindowForHotkeyToggle() {
            hideMainWindowIfPossible()
            return
        }
        openMainWindow()
    }

    func prepareForSettingsOpen() {
        hideMainWindowIfPossible()
        closePalette()

        pendingSettingsWindowFocus = true
        activateAppToFront()
        focusSettingsWindowIfPossible()

        DispatchQueue.main.async { [weak self] in
            self?.focusSettingsWindowIfPossible()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.focusSettingsWindowIfPossible()
        }
    }

    func openSettingsWindowLegacy() {
        prepareForSettingsOpen()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func openPalette() {
        presentPalette()
    }

    func openPaletteFromMenuBar() {
        hideMainWindowIfPossible()
        hideSettingsWindowIfPossible()
        presentPalette()
    }

    private func presentPalette() {
        paletteFocusNonce = UUID()
        activateAppToFront()
        paletteWindowController.showPalette()
    }

    func closePalette() {
        paletteWindowController.closePalette()
    }

    func testConnection() async {
        let effectiveConfig = MySQLConfig.default
        mysqlConfig = effectiveConfig
        dbStatus = .testing
        do {
            try await poolProvider.testConnection(effectiveConfig)
            dbStatus = .connected
        } catch {
            dbStatus = .disconnected
            currentError = mapError(error)
        }
    }

    func saveConfigurationAndReconnect() async {
        let effectiveConfig = MySQLConfig.default
        mysqlConfig = effectiveConfig
        configStore.save(effectiveConfig)
        await reconnectAndMigrate()
    }

    func reconnectAndMigrate() async {
        let effectiveConfig = MySQLConfig.default
        mysqlConfig = effectiveConfig
        print(
            "[CmdShelf] MySQL profile host=\(effectiveConfig.host) port=\(effectiveConfig.port) user=\(effectiveConfig.username) database=\(effectiveConfig.database)"
        )
        dbStatus = .testing
        migrationStatusText = "Running migrations..."

        do {
            try validate(config: effectiveConfig)
            try await migrationRunner.runMigrations(config: effectiveConfig)
            migrationStatusText = "Schema ready"

            try await poolProvider.rebuildPool(with: effectiveConfig)
            wireRepositories()
            try await ensureSeedDataIfNeeded()
            try await reloadAllData()

            dbStatus = .connected
        } catch {
            dbStatus = .disconnected
            currentError = mapError(error)
            migrationStatusText = "Failed"
        }
    }

    func reloadAll() async {
        do {
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func saveCommand(_ command: Command, showSuccessToast: Bool = true) async -> Bool {
        guard let commandRepository else {
            currentError = .databaseDisconnected
            return false
        }

        do {
            try await commandRepository.upsert(command)
            try await usageRepository?.add(itemType: .cmd, itemID: command.id, eventType: .edit)
            try await reloadAllData()
            if showSuccessToast {
                showToast(message: "Command saved", style: .success, icon: "checkmark.circle.fill")
            }
            return true
        } catch {
            currentError = mapError(error)
            return false
        }
    }

    func deleteCommand(id: UUID) async {
        guard let commandRepository else {
            currentError = .databaseDisconnected
            return
        }

        do {
            try await commandRepository.delete(id: id)
            if selectedCommandID == id {
                selectedCommandID = nil
            }
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func saveSop(_ sop: Sop, showSuccessToast: Bool = true) async -> Bool {
        guard let sopRepository else {
            currentError = .databaseDisconnected
            return false
        }

        do {
            try await sopRepository.upsert(sop)
            try await usageRepository?.add(itemType: .sop, itemID: sop.id, eventType: .edit)
            try await reloadAllData()
            if showSuccessToast {
                showToast(message: "SOP saved", style: .success, icon: "checkmark.circle.fill")
            }
            return true
        } catch {
            currentError = mapError(error)
            return false
        }
    }

    func deleteSop(id: UUID) async {
        guard let sopRepository else {
            currentError = .databaseDisconnected
            return
        }

        do {
            try await sopRepository.delete(id: id)
            if selectedSopID == id {
                selectedSopID = nil
            }
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func addCustomGroup(name: String) {
        let normalized = normalizeGroupName(name)
        guard !normalized.isEmpty else { return }

        let existing = Set(availableGroups.map { $0.lowercased() })
        guard !existing.contains(normalized.lowercased()) else { return }

        customGroups.append(normalized)
        customGroups.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        persistCustomGroups()
    }

    func renameGroup(from oldName: String, to newName: String) async {
        let oldNormalized = normalizeGroupName(oldName)
        let newNormalized = normalizeGroupName(newName)

        guard !oldNormalized.isEmpty, !newNormalized.isEmpty else { return }
        guard oldNormalized.caseInsensitiveCompare(newNormalized) != .orderedSame else { return }
        guard oldNormalized.caseInsensitiveCompare("General") != .orderedSame else {
            currentError = .validationFailed("General group cannot be renamed")
            return
        }

        let existing = Set(availableGroups.map { $0.lowercased() })
        if existing.contains(newNormalized.lowercased()) {
            currentError = .validationFailed("Group already exists")
            return
        }

        do {
            try await migrateGroupName(from: oldNormalized, to: newNormalized)
            replaceOrInsertCustomGroup(old: oldNormalized, new: newNormalized)
            persistCustomGroups()
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func deleteGroup(name: String) async {
        let normalized = normalizeGroupName(name)
        guard !normalized.isEmpty else { return }

        guard normalized.caseInsensitiveCompare("General") != .orderedSame else {
            currentError = .validationFailed("General group cannot be deleted")
            return
        }

        do {
            try await migrateGroupName(from: normalized, to: "General")
            customGroups.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
            persistCustomGroups()
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func searchPalette(query: String, limit: Int = 20) async -> [SearchResult] {
        guard let searchService else { return [] }
        do {
            return try await searchService.search(query: query, limit: limit)
        } catch {
            currentError = mapError(error)
            return []
        }
    }

    func copyCommand(_ command: Command) {
        do {
            try clipboardService.copy(text: command.content)
            showToast(message: "Command copied", style: .success, icon: "doc.on.doc.fill")
        } catch {
            currentError = mapError(error)
            return
        }

        guard commandRepository != nil else { return }

        Task {
            do {
                try await commandRepository?.recordCopy(id: command.id)
                try await reloadAllData()
            } catch {
                // Copy succeeded; usage stats failure should not interrupt user flow with alerts.
                print("[CmdShelf] warning: record command copy failed: \(error.localizedDescription)")
            }
        }
    }

    func copyCodeBlock(_ block: CodeBlock, from sop: Sop) {
        do {
            try clipboardService.copy(text: block.content)
            showToast(message: "SOP copied", style: .success, icon: "doc.on.doc.fill")
        } catch {
            currentError = mapError(error)
            return
        }

        guard sopRepository != nil else { return }

        Task {
            do {
                try await sopRepository?.recordCopy(id: sop.id)
                try await reloadAllData()
            } catch {
                // Copy succeeded; usage stats failure should not interrupt user flow with alerts.
                print("[CmdShelf] warning: record SOP copy failed: \(error.localizedDescription)")
            }
        }
    }

    func codeBlocks(for sop: Sop) -> [CodeBlock] {
        markdownExtractor.extract(from: sop.bodyMarkdown)
    }

    func captureClipboardToInbox() async {
        guard let inboxRepository else {
            currentError = .databaseDisconnected
            return
        }

        guard let text = clipboardService.readCurrentText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentError = .validationFailed("Clipboard has no text")
            return
        }

        do {
            let detectedType = detectType(for: text)
            try await inboxRepository.add(rawText: text, detectedType: detectedType)
            try await reloadAllData()
            showToast(message: "Captured to Inbox", style: .success, icon: "tray.and.arrow.down.fill")
        } catch {
            currentError = mapError(error)
        }
    }

    func deleteInboxItem(id: UUID) async {
        guard let inboxRepository else {
            currentError = .databaseDisconnected
            return
        }

        do {
            try await inboxRepository.delete(id: id)
            if selectedInboxID == id {
                selectedInboxID = nil
            }
            try await reloadAllData()
        } catch {
            currentError = mapError(error)
        }
    }

    func moveInboxItemToCommand(_ item: InboxItem, title: String? = nil) async {
        let command = Command(
            title: title ?? "From Inbox \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
            content: item.rawText,
            description: "Imported from Inbox",
            groupName: "General"
        )

        let saved = await saveCommand(command, showSuccessToast: false)
        guard saved else { return }
        await deleteInboxItem(id: item.id)
        showToast(message: "Saved Inbox as Command", style: .success, icon: "checkmark.circle.fill")
    }

    func moveInboxItemToSop(_ item: InboxItem, title: String? = nil) async {
        let sop = Sop(
            title: title ?? "From Inbox \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
            bodyMarkdown: item.rawText,
            groupName: "General"
        )

        let saved = await saveSop(sop, showSuccessToast: false)
        guard saved else { return }
        await deleteInboxItem(id: item.id)
        showToast(message: "Saved Inbox as SOP", style: .success, icon: "checkmark.circle.fill")
    }

    func focusOn(result: SearchResult) {
        openMainWindow()
        switch result {
        case .command(let command):
            activeTab = .commands
            selectedCommandID = command.id
        case .sop(let sop):
            activeTab = .sops
            selectedSopID = sop.id
        }
    }

    private func detectType(for text: String) -> InboxDetectedType {
        let lower = text.lowercased()

        let commandPrefixes = ["git", "docker", "kubectl", "ssh", "cd", "make", "python", "pip", "conda"]
        if text.contains("\n") || commandPrefixes.contains(where: { lower.hasPrefix($0 + " ") || lower == $0 }) {
            return .cmd
        }

        if text.contains("#") || text.contains("```") || text.contains("- [ ]") {
            return .sop
        }

        return .text
    }

    private func wireRepositories() {
        let commandRepo = CommandRepository(poolProvider: poolProvider)
        let sopRepo = SopRepository(poolProvider: poolProvider)

        self.commandRepository = commandRepo
        self.sopRepository = sopRepo
        self.inboxRepository = InboxRepository(poolProvider: poolProvider)
        self.usageRepository = UsageRepository(poolProvider: poolProvider)
        self.searchService = SearchService(commandRepository: commandRepo, sopRepository: sopRepo)
    }

    private func reloadAllData() async throws {
        guard
            let commandRepository,
            let sopRepository,
            let inboxRepository
        else {
            throw AppError.databaseDisconnected
        }

        commands = try await commandRepository.list(group: nil, sort: .usage)
        sops = try await sopRepository.list(group: nil)
        inboxItems = try await inboxRepository.list()

        if let selectedCommandID, !commands.contains(where: { $0.id == selectedCommandID }) {
            self.selectedCommandID = nil
        }
        if let selectedSopID, !sops.contains(where: { $0.id == selectedSopID }) {
            self.selectedSopID = nil
        }
        if let selectedInboxID, !inboxItems.contains(where: { $0.id == selectedInboxID }) {
            self.selectedInboxID = nil
        }
    }

    private func ensureSeedDataIfNeeded() async throws {
        guard let commandRepository, let sopRepository else {
            return
        }

        let existingCommands = try await commandRepository.list(group: nil, sort: .usage)
        let existingSops = try await sopRepository.list(group: nil)

        if existingCommands.isEmpty {
            let c1 = Command(
                title: "List staged git diff",
                content: "git diff --staged",
                description: "Review staged changes before commit",
                groupName: "Git",
                isPinned: true
            )
            let c2 = Command(
                title: "Tail app logs",
                content: "tail -f /var/log/system.log",
                description: "Live follow system log",
                groupName: "Ops"
            )
            try await commandRepository.upsert(c1)
            try await commandRepository.upsert(c2)
        }

        if existingSops.isEmpty {
            let sop = Sop(
                title: "Release Checklist",
                bodyMarkdown: """
                # Release Checklist

                1. Run tests
                2. Build release
                3. Tag and push

                ```bash
                swift test
                swift build -c release
                git tag v1.0.0
                git push --tags
                ```
                """,
                groupName: "Ops"
            )
            try await sopRepository.upsert(sop)
        }
    }

    private func migrateGroupName(from oldName: String, to newName: String) async throws {
        let affectedCommands = commands.filter { $0.groupName.caseInsensitiveCompare(oldName) == .orderedSame }
        let affectedSops = sops.filter { $0.groupName.caseInsensitiveCompare(oldName) == .orderedSame }

        guard !affectedCommands.isEmpty || !affectedSops.isEmpty else {
            return
        }

        guard let commandRepository, let sopRepository else {
            throw AppError.databaseDisconnected
        }

        for command in affectedCommands {
            var updated = command
            updated.groupName = newName
            updated.updatedAt = Date()
            try await commandRepository.upsert(updated)
        }

        for sop in affectedSops {
            var updated = sop
            updated.groupName = newName
            updated.updatedAt = Date()
            try await sopRepository.upsert(updated)
        }
    }

    private func replaceOrInsertCustomGroup(old: String, new: String) {
        if let index = customGroups.firstIndex(where: { $0.caseInsensitiveCompare(old) == .orderedSame }) {
            customGroups[index] = new
        } else {
            customGroups.append(new)
        }
        customGroups.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func normalizeGroupName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCustomGroups() -> [String] {
        guard let rawGroups = defaults.stringArray(forKey: customGroupsKey) else {
            return []
        }

        var seen = Set<String>()
        let normalized = rawGroups
            .map(normalizeGroupName)
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare("General") != .orderedSame }
            .filter { group in
                let key = group.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }

        return normalized.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func persistCustomGroups() {
        defaults.set(customGroups, forKey: customGroupsKey)
    }

    private func validate(config: MySQLConfig) throws {
        guard !config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.configurationInvalid("Host cannot be empty")
        }
        guard config.port > 0 && config.port < 65536 else {
            throw AppError.configurationInvalid("Port must be between 1 and 65535")
        }
        guard !config.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.configurationInvalid("Username cannot be empty")
        }
        guard !config.database.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.configurationInvalid("Database cannot be empty")
        }
    }

    private func mapError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error.localizedDescription)
    }

    private func applyCustomAppIconIfNeeded() {
        guard !didApplyCustomAppIcon else { return }
        guard let iconURL = Bundle.module.url(forResource: "AppIcon-1024", withExtension: "png") else { return }
        guard let iconImage = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = iconImage
        didApplyCustomAppIcon = true
    }

    private func showToast(message: String, style: AppToast.Style, icon: String) {
        currentToast = AppToast(message: message, style: style, icon: icon)
    }

    private func activateAppToFront() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
    }

    func ensureMainWindowFocused() {
        activateAppToFront()
        guard let mainWindow else { return }
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.makeKeyAndOrderFront(nil)
    }

    func ensureSettingsWindowFocused() {
        activateAppToFront()
        guard let settingsWindow else { return }
        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private func focusMainWindowIfPossible() {
        guard let mainWindow else { return }
        activateAppToFront()
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.makeKeyAndOrderFront(nil)
        pendingMainWindowFocus = false
    }

    private func focusSettingsWindowIfPossible() {
        guard let settingsWindow else { return }
        activateAppToFront()
        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }
        settingsWindow.makeKeyAndOrderFront(nil)
        pendingSettingsWindowFocus = false
    }

    private func hideMainWindowIfPossible() {
        mainWindow?.orderOut(nil)
    }

    private func shouldCloseMainWindowForHotkeyToggle() -> Bool {
        guard NSApp.isActive else { return false }
        guard let mainWindow else { return false }
        guard mainWindow.isVisible, !mainWindow.isMiniaturized else { return false }
        if #available(macOS 10.13, *) {
            return mainWindow.occlusionState.contains(.visible)
        }
        return true
    }

    private func hideSettingsWindowIfPossible() {
        settingsWindow?.orderOut(nil)
    }

    private func configureMainWindowSizeLimits(_ window: NSWindow?) {
        guard let window else { return }

        let minSize = NSSize(width: 980, height: 640)
        let maxSize = NSSize(width: 1240, height: 860)
        window.contentMinSize = minSize
        window.contentMaxSize = maxSize

        let current = window.frame
        let clampedWidth = min(max(current.size.width, minSize.width), maxSize.width)
        let clampedHeight = min(max(current.size.height, minSize.height), maxSize.height)
        guard clampedWidth != current.size.width || clampedHeight != current.size.height else { return }

        let centerX = current.midX
        let centerY = current.midY
        let resizedFrame = NSRect(
            x: centerX - (clampedWidth / 2),
            y: centerY - (clampedHeight / 2),
            width: clampedWidth,
            height: clampedHeight
        )
        window.setFrame(resizedFrame, display: true, animate: false)
    }
}
