import AppKit
import AVFoundation
import ApplicationServices
import Speech

/// Observable wrapper around the system permissions VTT cares about:
/// microphone (to record), Speech Recognition (Apple providers), and
/// Accessibility (to paste into the focused app when auto-insert is on).
/// Refreshed lazily — macOS doesn't push changes.
@MainActor
final class Permissions: ObservableObject {
    @Published private(set) var mic: AVAuthorizationStatus
    @Published private(set) var speech: SFSpeechRecognizerAuthorizationStatus
    @Published private(set) var accessibilityTrusted: Bool

    init() {
        mic = AVCaptureDevice.authorizationStatus(for: .audio)
        speech = SFSpeechRecognizer.authorizationStatus()
        accessibilityTrusted = AXIsProcessTrusted()
    }

    /// Re-read the current status from the system (e.g. after the user returns
    /// from System Settings).
    func refresh() {
        mic = AVCaptureDevice.authorizationStatus(for: .audio)
        speech = SFSpeechRecognizer.authorizationStatus()
        accessibilityTrusted = AXIsProcessTrusted()
    }

    // MARK: - Speech Recognition

    /// Prompt for Speech Recognition the first time; otherwise bounce to
    /// System Settings, since macOS only shows the in-app prompt once.
    func requestSpeech() {
        switch speech {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in
                Task { @MainActor in self.refresh() }
            }
        default:
            openSettings(pane: "Privacy_SpeechRecognition")
        }
    }

    // MARK: - Microphone

    /// Prompt for mic access the first time; otherwise bounce to System Settings,
    /// since macOS only shows the in-app prompt once.
    func requestMic() {
        switch mic {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.refresh() }
            }
        default:
            openSettings(pane: "Privacy_Microphone")
        }
    }

    // MARK: - Accessibility

    /// Show the system Accessibility prompt (which deep-links to the right pane)
    /// if we aren't trusted yet, and refresh our cached state.
    func requestAccessibility() {
        if !accessibilityTrusted {
            // Literal value of `kAXTrustedCheckOptionPrompt`; referencing the
            // global directly trips Swift 6 concurrency checks.
            _ = AXIsProcessTrustedWithOptions(
                ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            )
        } else {
            openSettings(pane: "Privacy_Accessibility")
        }
        refresh()
    }

    // MARK: - Helpers

    private func openSettings(pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
