import AppKit
import Carbon.HIToolbox

/// A key + modifier combination for a global hotkey, persisted in settings.
struct HotkeyChord: Equatable, Sendable {
    /// Virtual key code (`kVK_*`), same numbering as `NSEvent.keyCode`.
    var keyCode: UInt32
    /// Carbon modifier mask (`controlKey | optionKey | shiftKey | cmdKey`).
    var modifiers: UInt32
    /// Whether this hotkey is currently active.
    var enabled: Bool = true

    static let f13 = HotkeyChord(keyCode: UInt32(kVK_F13), modifiers: 0)
    static let ctrlSpace = HotkeyChord(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey)
    )
    static let ctrlOptSpace = HotkeyChord(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | optionKey)
    )

    /// The same chord, switched off — for presets that default to disabled.
    var disabled: HotkeyChord {
        var c = self
        c.enabled = false
        return c
    }

    /// Human-readable chord, e.g. "⌃⌥Space" or "F13".
    var display: String {
        Self.modifierString(modifiers) + Self.keyName(keyCode)
    }

    static func modifierString(_ mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey)  != 0 { s += "⌥" }
        if mods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if mods & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    /// Convert Cocoa modifier flags (from a recorded `NSEvent`) to a Carbon mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    static func keyName(_ code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_A: "A"; case kVK_ANSI_B: "B"; case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"; case kVK_ANSI_E: "E"; case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"; case kVK_ANSI_H: "H"; case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"; case kVK_ANSI_K: "K"; case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"; case kVK_ANSI_N: "N"; case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"; case kVK_ANSI_Q: "Q"; case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"; case kVK_ANSI_T: "T"; case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"; case kVK_ANSI_W: "W"; case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"; case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"; case kVK_ANSI_1: "1"; case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"; case kVK_ANSI_4: "4"; case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"; case kVK_ANSI_7: "7"; case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Escape: "Esc"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "⌦"
        case kVK_LeftArrow: "←"; case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"; case kVK_DownArrow: "↓"
        case kVK_Home: "Home"; case kVK_End: "End"
        case kVK_PageUp: "Page Up"; case kVK_PageDown: "Page Down"
        case kVK_ANSI_Minus: "-"; case kVK_ANSI_Equal: "="
        case kVK_ANSI_LeftBracket: "["; case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_Backslash: "\\"; case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Quote: "'"; case kVK_ANSI_Comma: ","
        case kVK_ANSI_Period: "."; case kVK_ANSI_Slash: "/"
        case kVK_ANSI_Grave: "`"
        case kVK_F1: "F1"; case kVK_F2: "F2"; case kVK_F3: "F3"
        case kVK_F4: "F4"; case kVK_F5: "F5"; case kVK_F6: "F6"
        case kVK_F7: "F7"; case kVK_F8: "F8"; case kVK_F9: "F9"
        case kVK_F10: "F10"; case kVK_F11: "F11"; case kVK_F12: "F12"
        case kVK_F13: "F13"; case kVK_F14: "F14"; case kVK_F15: "F15"
        case kVK_F16: "F16"; case kVK_F17: "F17"; case kVK_F18: "F18"
        case kVK_F19: "F19"; case kVK_F20: "F20"
        default: "Key \(code)"
        }
    }
}

// Codable in an extension so the memberwise initializer survives, and tolerant
// of older stored data that predates the `enabled` field.
extension HotkeyChord: Codable {
    enum CodingKeys: String, CodingKey { case keyCode, modifiers, enabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try c.decode(UInt32.self, forKey: .keyCode)
        modifiers = try c.decode(UInt32.self, forKey: .modifiers)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Registers one or more process-wide hotkeys through the Carbon Events API —
/// the only reliable way to grab a global shortcut without Accessibility
/// permission. A single event handler dispatches every registered chord to
/// `action`.
@MainActor
final class HotKey {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private let signature: OSType

    init(signature: OSType = 0x56_54_54_31, action: @escaping () -> Void) {
        self.signature = signature
        self.action = action
        installHandler()
    }

    /// Replace the set of registered chords. Only `enabled` chords are armed;
    /// duplicates and unregisterable chords are skipped silently.
    func setChords(_ chords: [HotkeyChord]) {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()

        for (index, chord) in chords.filter(\.enabled).enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(
                chord.keyCode, chord.modifiers, id,
                GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref { refs.append(ref) }
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                let hk = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                // Only act on this instance's own hotkeys; let others fall
                // through to the next handler in the chain.
                let handled: Bool = MainActor.assumeIsolated {
                    var hotKeyID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    guard status == noErr, hotKeyID.signature == hk.signature else {
                        return false
                    }
                    hk.action()
                    return true
                }
                return handled ? noErr : OSStatus(eventNotHandledErr)
            },
            1, &spec, selfPtr, &handler
        )
    }

    isolated deinit {
        for ref in refs { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
