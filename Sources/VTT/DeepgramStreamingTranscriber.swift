@preconcurrency import AVFoundation
import Foundation

/// Live Deepgram transcription over a WebSocket: streams 16 kHz mono PCM frames
/// and reports interim + finalized transcripts as you speak (Nova-3).
///
/// `@unchecked Sendable`: state is touched from the main actor, the audio tap
/// thread, and the WebSocket receive handler, all guarded by `lock`.
final class DeepgramStreamingTranscriber: SpeechTranscribing, @unchecked Sendable {
    let source: SpeechSource = .deepgram

    private let apiKey: String
    private let language: String
    private let model: String
    private let keyterms: [String]
    private let session = URLSession(configuration: .default)
    private let audioEngine = AVAudioEngine()
    private var webSocket: URLSessionWebSocketTask?

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
    )!

    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var onPartial: (@Sendable (String) -> Void)?
    private var onLevel: (@Sendable (Float) -> Void)?
    private var finalized = ""
    private var interim = ""
    private var closed = false
    private var finishContinuation: CheckedContinuation<String, Never>?

    init(apiKey: String, language: String, model: String = "nova-3", keyterms: [String] = []) {
        self.apiKey = apiKey
        self.language = language
        self.model = model.isEmpty ? "nova-3" : model
        self.keyterms = keyterms
    }

    deinit {
        // Safety net: if we're released without a clean finish()/cancel(), make
        // sure neither the mic engine nor the Deepgram WebSocket lingers.
        teardownAudio()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Lifecycle

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        guard !apiKey.isEmpty else { throw TranscriptionError.notAuthorized }
        withLock {
            self.onPartial = onPartial
            self.onLevel = onLevel
            self.finalized = ""
            self.interim = ""
            self.closed = false
        }

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
        ]
        // Nova-3 biases via keyterm prompting; older models use keyword boosting.
        let keytermParam = model.hasPrefix("nova-3") ? "keyterm" : "keywords"
        components.queryItems! += keyterms.map { URLQueryItem(name: keytermParam, value: $0) }
        var request = URLRequest(url: components.url!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let socket = session.webSocketTask(with: request)
        webSocket = socket
        socket.resume()
        receive()

        try startAudio()
    }

    func finish() async -> String {
        teardownAudio()
        // Ask Deepgram to flush and finalize, then wait for it to close.
        webSocket?.send(.string("{\"type\":\"CloseStream\"}")) { _ in }

        let text = await withCheckedContinuation { cont in
            let immediate: String? = withLock {
                if closed { return combined() }
                finishContinuation = cont
                return nil
            }
            if let immediate {
                cont.resume(returning: immediate)
            } else {
                // Safety net so a stalled socket can't hang the UI.
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    self?.handleClose()
                }
            }
        }
        // A WebSocket-level close handshake (not a bare task cancel) so Deepgram
        // tears down its /listen session instead of holding it open until its own
        // idle timeout. Then drop the URLSession so nothing lingers in the pool.
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session.finishTasksAndInvalidate()
        return text
    }

    func cancel() {
        teardownAudio()
        withLock {
            closed = true
            finalized = ""
            interim = ""
        }
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session.invalidateAndCancel()
    }

    // MARK: - WebSocket

    private func receive() {
        // Don't re-arm the listener once we've closed/torn down.
        if withLock({ closed }) { return }
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.handleClose()
            case .success(let message):
                switch message {
                case .string(let text): self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { self.handleMessage(text) }
                @unknown default: break
                }
                self.receive() // keep listening (receive is one-shot)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(DeepgramMessage.self, from: data),
              let transcript = message.channel?.alternatives.first?.transcript
        else { return }

        let callback: (@Sendable (String) -> Void)? = withLock {
            if message.is_final == true {
                if !transcript.isEmpty {
                    finalized = finalized.isEmpty ? transcript : finalized + " " + transcript
                }
                interim = ""
            } else {
                interim = transcript
            }
            return onPartial
        }
        callback?(withLock { combined() })
    }

    private func handleClose() {
        let cont: CheckedContinuation<String, Never>? = withLock {
            closed = true
            let c = finishContinuation
            finishContinuation = nil
            return c
        }
        cont?.resume(returning: withLock { combined() })
    }

    // MARK: - Audio

    private func startAudio() throws {
        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        withLock { self.converter = converter }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.send(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func send(_ buffer: AVAudioPCMBuffer) {
        let (converter, onLevel) = withLock { (self.converter, self.onLevel) }
        onLevel?(AudioLevel.normalized(buffer))
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        nonisolated(unsafe) var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let channel = out.int16ChannelData else { return }

        let data = Data(bytes: channel[0], count: Int(out.frameLength) * MemoryLayout<Int16>.size)
        webSocket?.send(.data(data)) { _ in }
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    /// Caller must hold `lock`.
    private func combined() -> String {
        if interim.isEmpty { return finalized }
        if finalized.isEmpty { return interim }
        return finalized + " " + interim
    }
}

private struct DeepgramMessage: Decodable {
    let is_final: Bool?
    let channel: Channel?

    struct Channel: Decodable { let alternatives: [Alternative] }
    struct Alternative: Decodable { let transcript: String }
}
