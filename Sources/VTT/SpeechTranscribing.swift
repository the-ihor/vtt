import Foundation

/// A selectable speech-to-text backend.
enum SpeechSource: String, CaseIterable, Identifiable, Sendable {
    /// Apple's classic Speech framework, forced on-device. macOS 13+.
    case appleOnDevice
    /// Apple's `SpeechAnalyzer` pipeline. macOS 26+.
    case appleSpeechAnalyzer
    /// Deepgram Nova-3 cloud transcription.
    case deepgram
    /// ElevenLabs Scribe cloud transcription.
    case elevenLabs
    /// OpenAI (gpt-4o-transcribe) cloud transcription.
    case openAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleOnDevice: "Apple — On-Device (Legacy)"
        case .appleSpeechAnalyzer: "Apple — SpeechAnalyzer (macOS 26)"
        case .deepgram: "Deepgram (Nova-3)"
        case .elevenLabs: "ElevenLabs (Scribe)"
        case .openAI: "OpenAI (gpt-4o-transcribe)"
        }
    }

    /// Compact label for the Settings sidebar.
    var shortName: String {
        switch self {
        case .appleOnDevice: "Apple Legacy"
        case .appleSpeechAnalyzer: "Apple Speech"
        case .deepgram: "Deepgram"
        case .elevenLabs: "ElevenLabs"
        case .openAI: "OpenAI"
        }
    }

    /// SF Symbol for the Settings sidebar / tab.
    var symbol: String {
        switch self {
        case .appleOnDevice: "apple.logo"
        case .appleSpeechAnalyzer: "apple.logo"
        case .deepgram: "bolt.horizontal.fill"
        case .elevenLabs: "speaker.wave.2.fill"
        case .openAI: "sparkles"
        }
    }

    /// Bundled brand-logo file name (without extension), used in place of the
    /// SF Symbol when present in the app bundle. nil = use the SF Symbol.
    var logoAsset: String? {
        switch self {
        case .appleOnDevice, .appleSpeechAnalyzer: nil
        case .deepgram: "deepgram"
        case .elevenLabs: "elevenlabs"
        case .openAI: "openai"
        }
    }

    var isImplemented: Bool { true }

    /// One-line summary shown under the provider in Settings.
    var blurb: String {
        switch self {
        case .appleOnDevice:
            "Apple's legacy on-device Speech framework. No audio leaves your Mac."
        case .appleSpeechAnalyzer:
            "Apple's newer SpeechAnalyzer pipeline (macOS 26)."
        case .deepgram:
            "Deepgram Nova-3. Live streaming cloud transcription. Sends audio to Deepgram."
        case .elevenLabs:
            "ElevenLabs Scribe. High-accuracy cloud transcription. Sends audio to ElevenLabs."
        case .openAI:
            "OpenAI gpt-4o-transcribe. Sends audio to OpenAI."
        }
    }

    /// What the provider needs before it can run.
    var access: ProviderAccess {
        switch self {
        case .appleOnDevice, .appleSpeechAnalyzer: .speechRecognition
        case .deepgram, .elevenLabs, .openAI: .apiKey
        }
    }

    /// Whether the provider runs locally or sends audio over the network.
    var category: ProviderCategory {
        switch self {
        case .appleOnDevice, .appleSpeechAnalyzer: .onDevice
        case .deepgram, .elevenLabs, .openAI: .network
        }
    }

    /// Approximate USD cost per minute of audio (nil = free / on-device).
    /// Public list prices as of early 2026 — estimate only.
    var costPerMinute: Double? {
        switch self {
        case .appleOnDevice, .appleSpeechAnalyzer: nil
        case .deepgram: 0.0077    // Nova-3 streaming, ~$0.46/hr
        case .elevenLabs: 0.0067  // Scribe, ~$0.40/hr
        case .openAI: 0.006       // gpt-4o-transcribe, $0.006/min
        }
    }

    /// Whether the backend emits a live (interim) transcript while recording.
    /// Cloud providers here are batch, so they only produce a final result.
    var streamsPartials: Bool {
        switch self {
        case .appleOnDevice, .appleSpeechAnalyzer, .deepgram: true
        case .elevenLabs, .openAI: false
        }
    }
}

/// Sidebar grouping for providers.
enum ProviderCategory: CaseIterable, Sendable {
    case onDevice
    case network

    var title: String {
        switch self {
        case .onDevice: "On-Device Providers"
        case .network: "Network Providers"
        }
    }
}

/// The kind of access a provider needs, so Settings can offer the right button.
enum ProviderAccess: Sendable {
    /// Apple's on-device/Speech-framework recognition authorization.
    case speechRecognition
    /// A user-supplied API key (cloud providers).
    case apiKey
}

/// A streaming transcriber: authorize, start capturing + emitting partials,
/// then finish to get the final text. Implementations own their audio capture.
protocol SpeechTranscribing: Sendable {
    var source: SpeechSource { get }

    /// Prompt for mic + recognition permission. Returns whether granted.
    func requestAuthorization() async -> Bool

    /// Begin capturing audio. `onPartial` fires with the running transcript
    /// (only for backends that stream); `onLevel` fires with the 0...1 mic level.
    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws

    /// Stop capturing and resolve with the final transcript.
    func finish() async -> String

    /// Abort without producing a transcript.
    func cancel()
}

enum TranscriptionError: Error {
    case recognizerUnavailable
    case notAuthorized
}

extension String {
    /// A trimmed copy ending in sentence punctuation — used to mark a finalized
    /// transcript segment as "stopped" (adds "." when none is present).
    func sentencePunctuated() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        return ".!?…".contains(last) ? trimmed : trimmed + "."
    }
}
