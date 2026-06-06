import Foundation

/// A selectable transcription model for a provider.
struct ProviderModel: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
}

/// The per-provider list of available models, loaded from a JSON file hosted on
/// GitHub (so models can be added without shipping an app update) and cached
/// locally. Falls back to a bundled default when offline / before first load.
///
/// Remote shape (keyed by `SpeechSource.rawValue`):
/// ```
/// { "deepgram": [ { "id": "nova-3", "name": "Nova-3" } ], "openAI": [ … ] }
/// ```
@MainActor
final class ModelCatalog: ObservableObject {
    /// Raw file on the repo's main branch.
    static let remoteURL = URL(string:
        "https://raw.githubusercontent.com/the-ihor/vtt/main/config/models.json")!

    private static let cacheKey = "modelCatalogJSON"

    @Published private(set) var models: [String: [ProviderModel]]

    init() {
        models = Self.loadCached() ?? Self.bundledDefaults
    }

    /// Models offered for a provider (empty for engines without a choice).
    func models(for source: SpeechSource) -> [ProviderModel] {
        models[source.rawValue] ?? []
    }

    /// Fetch the latest catalog from GitHub; keep the cached/bundled copy on
    /// failure so the picker always has something to show.
    func refresh() async {
        do {
            var request = URLRequest(url: Self.remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let decoded = try JSONDecoder().decode([String: [ProviderModel]].self, from: data)
            guard !decoded.isEmpty else { return }
            models = decoded
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        } catch {
            NSLog("VTT: model catalog refresh failed: \(error)")
        }
    }

    private static func loadCached() -> [String: [ProviderModel]]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: [ProviderModel]].self, from: data),
              !decoded.isEmpty
        else { return nil }
        return decoded
    }

    /// Shipped defaults — also the first entry per provider is the engine's
    /// current default model.
    static let bundledDefaults: [String: [ProviderModel]] = [
        SpeechSource.deepgram.rawValue: [
            ProviderModel(id: "nova-3", name: "Nova-3"),
            ProviderModel(id: "nova-2", name: "Nova-2"),
        ],
        SpeechSource.openAI.rawValue: [
            ProviderModel(id: "gpt-4o-transcribe", name: "GPT-4o Transcribe"),
            ProviderModel(id: "gpt-4o-mini-transcribe", name: "GPT-4o mini Transcribe"),
            ProviderModel(id: "whisper-1", name: "Whisper"),
        ],
        SpeechSource.elevenLabs.rawValue: [
            ProviderModel(id: "scribe_v1", name: "Scribe v1"),
        ],
    ]
}
