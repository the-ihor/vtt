@preconcurrency import AVFoundation
import Speech

/// On-device transcription via the macOS 26 `SpeechAnalyzer` / `SpeechTranscriber`
/// pipeline. Streams mic audio (converted to the analyzer's preferred format)
/// through an `AsyncStream` and reports volatile + finalized results.
///
/// Results are consumed on their own task, concurrently with `analyzer.start`,
/// because `start(inputSequence:)` does not return until the input ends.
///
/// `@unchecked Sendable`: state is touched from the main actor, the audio tap
/// thread, and the analyzer tasks, all guarded by `lock`.
@available(macOS 26, *)
final class AppleSpeechAnalyzerTranscriber: SpeechTranscribing, @unchecked Sendable {
    let source: SpeechSource = .appleSpeechAnalyzer

    private let preferredLocale: String
    private let audioEngine = AVAudioEngine()

    init(localeIdentifier: String = "en-US") {
        preferredLocale = localeIdentifier
    }
    private var analyzer: SpeechAnalyzer?
    private var module: SpeechTranscriber?
    private var driverTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?

    private let lock = NSLock()
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var onPartial: (@Sendable (String) -> Void)?
    private var onLevel: (@Sendable (Float) -> Void)?
    private var finalized = ""
    private var volatile = ""
    private var started = false

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speechOK else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Lifecycle

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        guard SpeechTranscriber.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        withLock {
            self.onPartial = onPartial
            self.onLevel = onLevel
            self.finalized = ""
            self.volatile = ""
            self.started = false
        }
        driverTask = Task { [weak self] in
            guard let self else { return }
            await self.run()
        }
    }

    /// Resolve a supported locale (the system locale, e.g. en_UA, may not be
    /// supported), install the model if needed, then stream audio + results.
    private func run() async {
        guard let locale = await resolveLocale() else {
            return
        }

        let module = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [module])
        withLock {
            self.module = module
            self.analyzer = analyzer
        }

        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }

            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            withLock {
                self.analyzerFormat = format
                self.inputContinuation = continuation
            }

            // Consume results concurrently; start(inputSequence:) blocks until
            // the input ends, so it can't also drive the results loop.
            let results = Task { [weak self] in
                guard let self else { return }
                await self.consumeResults(module)
            }
            withLock { self.resultsTask = results }

            try startAudio(to: format)
            withLock { self.started = true }
            try await analyzer.start(inputSequence: stream)
        } catch {
            NSLog("VTT: SpeechAnalyzer error: \(error)")
            // The engine may already be capturing when the analyzer fails —
            // stop it here or the mic stays held until the next finish/cancel.
            teardownAudio()
        }
    }

    private func resolveLocale() async -> Locale? {
        if let match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: preferredLocale)) {
            return match
        }
        if let match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) {
            return match
        }
        if let english = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) {
            return english
        }
        return await SpeechTranscriber.supportedLocales.first
    }

    private func consumeResults(_ module: SpeechTranscriber) async {
        do {
            for try await result in module.results {
                let text = String(result.text.characters)
                let callback: (@Sendable (String) -> Void)? = withLock {
                    if result.isFinal {
                        let segment = text.sentencePunctuated()
                        if !segment.isEmpty {
                            self.finalized = self.finalized.isEmpty
                                ? segment : self.finalized + " " + segment
                        }
                        self.volatile = ""
                    } else {
                        self.volatile = text
                    }
                    return self.onPartial
                }
                callback?(withLock { self.combinedText() })
            }
        } catch {
        }
    }

    func finish() async -> String {
        teardownAudio()
        withLock {
            inputContinuation?.finish()
            inputContinuation = nil
        }
        await driverTask?.value

        let (didStart, analyzer, results) = withLock { (started, self.analyzer, self.resultsTask) }
        if didStart, let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        } else {
            results?.cancel()
        }
        await results?.value
        return withLock { combinedText() }
    }

    func cancel() {
        teardownAudio()
        let (analyzer, results) = withLock {
            inputContinuation?.finish()
            inputContinuation = nil
            finalized = ""
            volatile = ""
            return (self.analyzer, self.resultsTask)
        }
        driverTask?.cancel()
        results?.cancel()
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
    }

    // MARK: - Audio

    private func startAudio(to analyzerFormat: AVAudioFormat?) throws {
        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        let converter: AVAudioConverter? = {
            guard let analyzerFormat, analyzerFormat != inputFormat else { return nil }
            return AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }()
        withLock { self.converter = converter }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.appendAudio(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func appendAudio(_ buffer: AVAudioPCMBuffer) {
        let (continuation, format, converter, onLevel) = withLock {
            (inputContinuation, analyzerFormat, self.converter, self.onLevel)
        }
        onLevel?(AudioLevel.normalized(buffer))
        guard let continuation else { return }

        if let format, let converter {
            guard let converted = convert(buffer, using: converter, to: format) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        } else {
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
    }

    private func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        nonisolated(unsafe) var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return nil }
        return out.frameLength > 0 ? out : nil
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    /// Caller must hold `lock`.
    private func combinedText() -> String {
        if volatile.isEmpty { return finalized }
        if finalized.isEmpty { return volatile }
        return finalized + " " + volatile
    }
}
