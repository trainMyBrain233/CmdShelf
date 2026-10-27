import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openMainWindow = Self(
        "openPalette",
        default: .init(.d, modifiers: [.command])
    )
}

final class HotkeyService {
    var onOpenMainWindow: (() -> Void)?

    func register() {
        KeyboardShortcuts.onKeyUp(for: .openMainWindow) { [weak self] in
            self?.onOpenMainWindow?()
        }
    }
}
