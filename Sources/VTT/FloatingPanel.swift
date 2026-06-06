import AppKit

/// A borderless, non-activating panel that floats above all normal windows and
/// never steals key focus from the app the user is typing in — the core trick
/// behind a WisprFlow-style floating bar.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isMovableByWindowBackground = true

        // Transparent so the SwiftUI capsule defines the visible shape.
        backgroundColor = .clear
        isOpaque = false
        // The SwiftUI layer renders its own soft, GPU-composited shadow, so the
        // window's hard rectangular shadow is turned off.
        hasShadow = false

        // Stay visible across spaces and over full-screen apps, and never
        // participate in window cycling.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    // Allow mouse interaction without ever becoming the key/main window so the
    // user's frontmost app keeps its insertion point.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Pin the panel to the bottom-center of the screen containing the cursor.
    func positionAtBottomCenter(bottomInset: CGFloat = 48) {
        let screen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        guard let visible = screen?.visibleFrame else { return }
        let size = frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + bottomInset
        )
        setFrameOrigin(origin)
    }
}
