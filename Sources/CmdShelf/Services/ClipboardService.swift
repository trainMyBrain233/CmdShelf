import AppKit
import Foundation

protocol ClipboardServiceProtocol {
    func copy(text: String) throws
    func readCurrentText() -> String?
}

final class ClipboardService: ClipboardServiceProtocol {
    func copy(text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if !success {
            throw AppError.clipboardUnavailable
        }
    }

    func readCurrentText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
