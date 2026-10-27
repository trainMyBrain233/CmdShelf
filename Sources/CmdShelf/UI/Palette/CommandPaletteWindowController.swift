import AppKit
import SwiftUI

final class CommandPaletteWindowController: NSWindowController {
    private weak var appState: AppState?
    private let hostingController: NSHostingController<CommandPaletteView>

    init(appState: AppState) {
        self.appState = appState
        self.hostingController = NSHostingController(rootView: CommandPaletteView(appState: appState))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Command Palette"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPalette() {
        guard let appState else { return }

        hostingController.rootView = CommandPaletteView(appState: appState)
        window?.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func closePalette() {
        close()
    }
}
