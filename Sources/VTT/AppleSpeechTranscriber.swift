import AVFoundation
import Speech

/// On-device transcription via `SFSpeechRecognizer` + `AVAudioEngine`.
///
/// `SFSpeechRecognizer` finalizes a recognition after a pause in speech (and
/// has a ~1-minute cap). To support continuous dictation we accumulate each
/// finalized segment into `finalized` and immediately start a fresh recognition
/// request — keeping the audio engine running — so later utterances append
/// instead of replacing earlier ones.
///
/// `@unchecked Sendable`: state is touched from the main actor and from the
/// recognition/audio callback threads, guarded by `lock`.
final class AppleSpeechTranscriber: SpeechTranscribing, @unchecked Sendable {
    let source: SpeechSource = .appleOnDevice

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()

    init(localeIdentifier: String = "en-US") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onPartial: (@Sendable (String) -> Void)?
    private var onLevel: (@Sendable (Float) -> Void)?
    private var finalized = ""   // accumulated, already-finalized segments
    private var latest = ""      // running text of the current segment
    private var finishing = false
    private var finishContinuation: CheckedContinuation<String, Never>?

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Lifecycle

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        withLock {
            self.onPartial = onPartial
            self.onLevel = onLevel
            self.finalized = ""
            self.latest = ""
            self.finishing = false
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        startSegment()
    }

    /// Begin a fresh recognition request/task feeding off the running engine.
    private func startSegment() {
        guard let recognizer else { return }
        // Don't start another segment once we're finishing up.
        if withLock({ finishing }) { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        // Optimize for free-form dictation rather than short command phrases.
        request.taskHint = .dictation

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                let cb: (@Sendable (String) -> Void)? = self.withLock {
                    // The recognizer resets formattedString to a new utterance
                    // after a pause without sending isFinal — fold the prior
                    // utterance in so it isn't replaced.
                    if self.isReset(from: self.latest, to: text) {
                        self.foldLatest()
                    }
                    self.latest = text
                    return self.onPartial
                }
                cb?(self.withLock { self.combined() })
                if result.isFinal { self.segmentFinished() }
            }
            if error != nil { self.segmentFinished() }
        }

        withLock {
            self.request = request
            self.task = task
            self.latest = ""
        }
    }

    /// A segment finalized (pause, cap, error, or `endAudio`). Fold its text
    /// into `finalized`, then either resolve `finish()` or start the next one.
    private func segmentFinished() {
        let (finishing, cont, partial): (Bool, CheckedContinuation<String, Never>?, (@Sendable (String) -> Void)?) = withLock {
            foldLatest()
            task = nil
            request = nil
            if self.finishing {
                let c = finishContinuation
                finishContinuation = nil
                return (true, c, nil)
            }
            return (false, nil, onPartial)
        }

        if finishing {
            cont?.resume(returning: withLock { finalized })
        } else {
            partial?(withLock { combined() })
            startSegment() // keep listening for the next utterance
        }
    }

    func finish() async -> String {
        teardownAudio()

        return await withCheckedContinuation { cont in
            let immediate: String? = withLock {
                finishing = true
                if task == nil { return finalized } // nothing in flight
                finishContinuation = cont
                return nil
            }
            if let immediate {
                cont.resume(returning: immediate)
            } else {
                withLock { request?.endAudio() } // flush → triggers final result
                // Safety net: if the recognizer never delivers a final result,
                // resolve with what we have so the caller isn't stuck holding
                // this transcriber (and its engine — i.e. the mic) forever.
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self?.forceFinish()
                }
            }
        }
    }

    /// Resolve a `finish()` whose final recognition callback never arrived.
    private func forceFinish() {
        let cont: CheckedContinuation<String, Never>? = withLock {
            guard let c = finishContinuation else { return nil }
            finishContinuation = nil
            task?.cancel()
            task = nil
            request = nil
            foldLatest()
            return c
        }
        cont?.resume(returning: withLock { finalized })
    }

    func cancel() {
        teardownAudio()
        let cont: CheckedContinuation<String, Never>? = withLock {
            finishing = true
            task?.cancel()
            task = nil
            request = nil
            let c = finishContinuation
            finishContinuation = nil
            return c
        }
        cont?.resume(returning: "")
    }

    // MARK: - Helpers

    private func append(_ buffer: AVAudioPCMBuffer) {
        let (request, onLevel) = withLock { (self.request, self.onLevel) }
        request?.append(buffer)
        onLevel?(AudioLevel.normalized(buffer))
    }

    /// Move the current segment into `finalized`, terminated with a period so it
    /// reads as "stopped". Caller must hold `lock`.
    private func foldLatest() {
        let segment = latest.sentencePunctuated()
        if !segment.isEmpty {
            finalized = finalized.isEmpty ? segment : finalized + " " + segment
        }
        latest = ""
    }

    /// True when `new` is a brand-new utterance rather than a continuation/
    /// revision of `old` — i.e. it no longer starts with `old`'s first word.
    private func isReset(from old: String, to new: String) -> Bool {
        guard !old.isEmpty else { return false }
        let firstWord = String(old.prefix { $0 != " " })
        return !new.hasPrefix(firstWord)
    }

    /// Finalized text plus the in-progress segment. Caller must hold `lock`.
    private func combined() -> String {
        if latest.isEmpty { return finalized }
        if finalized.isEmpty { return latest }
        return finalized + " " + latest
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
}
