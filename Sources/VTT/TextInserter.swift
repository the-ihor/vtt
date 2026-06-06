import AppKit
import CoreGraphics

/// Inserts text into whatever app currently has keyboard focus by synthesizing
/// a ⌘V paste. Requires Accessibility trust to post events into other apps —
/// see `Permissions.requestAccessibility()`.
enum TextInserter {
    /// Posts ⌘V. The caller is expected to have placed `text` on the pasteboard.
    static func paste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 0x09 // 'v'

        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
