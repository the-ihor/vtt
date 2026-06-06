import Foundation
import Speech

/// Whether a provider can actually run on this machine, with a human note.
struct ProviderAvailability: Sendable {
    let ok: Bool
    let note: String
}

extension SpeechSource {
    /// Checks the system requirements for this provider (OS version, on-device
    /// model support) — independent of whether VTT has implemented it yet.
    var availability: ProviderAvailability {
        switch self {
        case .appleOnDevice:
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
                return .init(ok: false, note: "Speech recognition isn't available for English.")
            }
            return recognizer.supportsOnDeviceRecognition
                ? .init(ok: true, note: "On-device English model is installed.")
                : .init(ok: false, note: "On-device recognition isn't supported on this Mac.")

        case .appleSpeechAnalyzer:
            if #available(macOS 26, *) {
                return .init(ok: true, note: "macOS 26 detected — your system qualifies.")
            }
            return .init(ok: false, note: "Requires macOS 26 or later.")

        case .deepgram, .elevenLabs, .openAI:
            return .init(ok: true, note: "Runs over the network; requires an API key.")
        }
    }
}
