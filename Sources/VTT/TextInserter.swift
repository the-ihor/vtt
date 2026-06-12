import AppKit
import CoreGraphics

/// Inserts text into whatever app currently has keyboard focus by synthesizing
/// a ⌘V paste. Requires Accessibility trust to post events into other apps —
/// see `Permissions.requestAccessibility()`.
/// Snapshot/restore of the general pasteboard so a programmatic paste can
/// leave the user's copy buffer exactly as it found it.
enum Clipboard {
    typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    /// Capture every pasteboard item with all of its representations.
    static func snapshot() -> Snapshot {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var reps: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { reps[type] = data }
            }
            return reps
        }
    }

    /// Put a snapshot back. An empty snapshot restores an empty pasteboard.
    static func restore(_ snapshot: Snapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { reps -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in reps { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

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
