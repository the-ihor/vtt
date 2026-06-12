import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey!
    private var cancelHotKey: HotKey!
    private var toggleItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupPanel()
        setupStatusItem()
        setupHotKey()
        observeScreenChanges()
        observeMode()
        observeFreeLimit()
    }

    /// When a free-tier user hits the daily limit, offer to subscribe — or to
    /// "beg" for one more recording if they have begs left for today.
    private func observeFreeLimit() {
        NotificationCenter.default.addObserver(
            forName: .vttFreeLimitReached,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.presentFreeLimitPrompt() }
        }
    }

    private func presentFreeLimitPrompt() {
        NSApp.activate(ignoringOtherApps: true)
        NSSound.beep()

        let begs = state.begsRemaining
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "You've used today's free dictation"

        if begs > 0 {
            alert.informativeText = """
            Remove the daily cap with Unlimited Dictation — or beg for one more \
            recording today. You have \(begs) beg\(begs == 1 ? "" : "s") left.
            """
            alert.addButton(withTitle: "Beg one more (\(begs) left)")
            alert.addButton(withTitle: "Subscribe…")
            alert.addButton(withTitle: "Not now")
            switch alert.runModal() {
            case .alertFirstButtonReturn: state.begOneMore()
            case .alertSecondButtonReturn: showProTab()
            default: break
            }
        } else {
            alert.informativeText = "You're out of begs for today. Subscribe to Unlimited Dictation to remove the daily cap."
            alert.addButton(withTitle: "Subscribe…")
            alert.addButton(withTitle: "Not now")
            if alert.runModal() == .alertFirstButtonReturn { showProTab() }
        }
    }

    private func showProTab() {
        openSettings()
        // Defer so the freshly-created SettingsView has subscribed.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .vttShowProTab, object: nil)
        }
    }

    /// An accessory (LSUIElement) app has no menu bar, so the standard
    /// Cut/Copy/Paste keyboard shortcuts aren't delivered to text fields. A
    /// minimal Edit menu restores ⌘X / ⌘C / ⌘V / ⌘A (e.g. pasting an API key).
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Floating bar

    private func setupPanel() {
        // Includes the 20pt transparent margin the SwiftUI view adds for its
        // shadow. Wide enough that the pill can grow to show live transcript
        // text; the panel is transparent so the extra width is invisible.
        let size = NSSize(width: 380, height: 66)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))

        let host = NSHostingView(rootView: FloatingBarView(state: state))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        // Hidden until dictation starts; the hotkey summons it.
    }

    /// Show the pill while active, hide it when idle.
    private func observeMode() {
        state.$mode
            .removeDuplicates()
            .sink { [weak self] mode in
                guard let self else { return }
                if mode == .idle {
                    self.panel.orderOut(nil)
                } else if !self.panel.isVisible {
                    self.panel.positionAtBottomCenter()
                    self.panel.orderFrontRegardless()
                }
                // Grab Escape globally only while recording.
                let escape = HotkeyChord(keyCode: UInt32(kVK_Escape), modifiers: 0)
                self.cancelHotKey.setChords(mode == .recording ? [escape] : [])
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "VTT"
        )

        let menu = NSMenu()
        let toggle = menu.addItem(
            withTitle: "Toggle Dictation",
            action: #selector(toggleDictation),
            keyEquivalent: ""
        )
        toggle.target = self
        toggleItem = toggle
        menu.addItem(
            withTitle: "Paste Latest Transcription",
            action: #selector(pasteLatest),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit VTT",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    // MARK: - Hotkey

    private func setupHotKey() {
        hotKey = HotKey { [weak self] in
            self?.state.toggle()
        }
        // Escape cancels an in-progress recording. Registered only while
        // recording (see observeMode) so it doesn't grab Escape otherwise.
        cancelHotKey = HotKey(signature: 0x56_54_54_32) { [weak self] in // 'VTT2'
            self?.state.cancelRecording()
        }
        // Register the current chords and re-register whenever they change.
        // combineLatest emits immediately, performing the initial registration.
        state.$primaryHotkey
            .combineLatest(state.$alternativeHotkey)
            .sink { [weak self] primary, alternative in
                self?.applyHotkeys(primary: primary, alternative: alternative)
            }
            .store(in: &cancellables)
    }

    private func applyHotkeys(primary: HotkeyChord, alternative: HotkeyChord) {
        var chords = [primary]
        if alternative != primary { chords.append(alternative) }
        hotKey.setChords(chords)
        toggleItem?.title = "Toggle Dictation  (\(primary.display))"
    }

    // MARK: - Screen handling

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.positionAtBottomCenter() }
        }
    }

    // MARK: - Actions

    @objc private func toggleDictation() {
        state.toggle()
    }

    @objc private func pasteLatest() {
        state.pasteLatest()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 440),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "VTT Settings"
            // System Settings-style: transparent, full-height title bar so the
            // sidebar runs to the top with the traffic lights floating over it.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(
                rootView: SettingsView(state: state, permissions: state.permissions)
            )
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
