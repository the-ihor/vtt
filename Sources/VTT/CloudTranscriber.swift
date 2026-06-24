import AVFoundation
import Foundation

/// A cloud speech-to-text endpoint that turns a WAV blob into text.
protocol CloudSpeechAPI: Sendable {
    var source: SpeechSource { get }
    func transcribe(wav: Data, apiKey: String, language: String) async throws -> String
}

/// Push-to-talk cloud transcriber: records locally while the user speaks, then
/// uploads the whole clip on `finish()`. (Batch, not live streaming.)
///
/// `@unchecked Sendable`: the wrapped `AudioRecorder` is itself thread-safe and
/// the API/key are immutable.
final class CloudTranscriber: SpeechTranscribing, @unchecked Sendable {
    let api: CloudSpeechAPI
    var source: SpeechSource { api.source }

    private let recorder = AudioRecorder()
    private let apiKey: String
    private let language: String

    init(api: CloudSpeechAPI, apiKey: String, language: String) {
        self.api = api
        self.apiKey = apiKey
        self.language = language
    }

    func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        guard !apiKey.isEmpty else { throw TranscriptionError.notAuthorized }
        try recorder.start(onLevel: onLevel)
    }

    func finish() async -> String {
        guard let wav = recorder.finish() else { return "" }
        do {
            return try await api.transcribe(wav: wav, apiKey: apiKey, language: language)
        } catch {
            NSLog("VTT: \(source.rawValue) transcription failed: \(error)")
            return ""
        }
    }

    func cancel() { recorder.cancel() }
}

// MARK: - Providers

/// Deepgram Nova-3 prerecorded endpoint: raw WAV body, token auth.
struct DeepgramAPI: CloudSpeechAPI {
    let source: SpeechSource = .deepgram
    /// Custom-vocabulary terms biased via Nova-3 keyterm prompting.
    var keyterms: [String] = []

    func transcribe(wav: Data, apiKey: String, language: String) async throws -> String {
        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
        ]
        // Nova-3 biases recognition via keyterm prompting (one param per term).
        components.queryItems! += keyterms.map { URLQueryItem(name: "keyterm", value: $0) }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = wav

        let (data, response) = try await URLSession.shared.data(for: request)
        try Cloud.checkHTTP(response, data)

        struct Response: Decodable {
            struct Results: Decodable { let channels: [Channel] }
            struct Channel: Decodable { let alternatives: [Alternative] }
            struct Alternative: Decodable { let transcript: String }
            let results: Results
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results.channels.first?.alternatives.first?.transcript ?? ""
    }
}

/// OpenAI `gpt-4o-transcribe`: multipart upload, Bearer auth.
struct OpenAIAPI: CloudSpeechAPI {
    let source: SpeechSource = .openAI
    var model: String = "gpt-4o-transcribe"
    /// Optional vocabulary/style hint biasing recognition (custom dictionary).
    var prompt: String = ""

    func transcribe(wav: Data, apiKey: String, language: String) async throws -> String {
        var body = MultipartBody()
        body.addField("model", model.isEmpty ? "gpt-4o-transcribe" : model)
        body.addField("response_format", "json")
        body.addField("language", language)
        if !prompt.isEmpty { body.addField("prompt", prompt) }
        body.addFile("file", filename: "audio.wav", contentType: "audio/wav", data: wav)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.finalized()

        let (data, response) = try await URLSession.shared.data(for: request)
        try Cloud.checkHTTP(response, data)
        return try JSONDecoder().decode(Cloud.TextResponse.self, from: data).text
    }
}

/// ElevenLabs Scribe: multipart upload, `xi-api-key` auth.
struct ElevenLabsAPI: CloudSpeechAPI {
    let source: SpeechSource = .elevenLabs
    var model: String = "scribe_v1"
    /// Tag non-speech events like (laughter). Off keeps dictation text clean.
    var tagAudioEvents: Bool = false
    /// Explicit sampling temperature (0...2); nil leaves it to the API default.
    var temperature: Double? = nil
    /// Custom-vocabulary terms. ElevenLabs only honours keyterms on Scribe v2,
    /// so they're sent only when that model is selected.
    var keyterms: [String] = []

    func transcribe(wav: Data, apiKey: String, language: String) async throws -> String {
        let modelID = model.isEmpty ? "scribe_v1" : model
        var body = MultipartBody()
        body.addField("model_id", modelID)
        body.addField("language_code", language)
        body.addField("tag_audio_events", tagAudioEvents ? "true" : "false")
        if let temperature {
            body.addField("temperature", String(format: "%.2f", temperature))
        }
        // keyterms is an array → repeated form fields (one per term), matching
        // the official SDK's encoding. Keyterm prompting is Scribe v2 only.
        if modelID == "scribe_v2" {
            for term in keyterms { body.addField("keyterms", term) }
        }
        body.addFile("file", filename: "audio.wav", contentType: "audio/wav", data: wav)

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.finalized()

        let (data, response) = try await URLSession.shared.data(for: request)
        try Cloud.checkHTTP(response, data)
        return try JSONDecoder().decode(Cloud.TextResponse.self, from: data).text
    }
}

// MARK: - HTTP helpers

enum Cloud {
    /// Shared `{ "text": ... }` shape returned by OpenAI and ElevenLabs.
    struct TextResponse: Decodable { let text: String }

    enum Error: Swift.Error { case http(status: Int, body: String) }

    static func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw Error.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }
}

/// Minimal `multipart/form-data` body builder.
struct MultipartBody {
    private let boundary = "vtt-boundary-\(UUID().uuidString)"
    private var data = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(_ name: String, _ value: String) {
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.appendString("\(value)\r\n")
    }

    mutating func addFile(_ name: String, filename: String, contentType: String, data fileData: Data) {
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        data.appendString("Content-Type: \(contentType)\r\n\r\n")
        data.append(fileData)
        data.appendString("\r\n")
    }

    func finalized() -> Data {
        var result = data
        result.appendString("--\(boundary)--\r\n")
        return result
    }
}

private extension Data {
    mutating func appendString(_ string: String) { append(Data(string.utf8)) }
}
