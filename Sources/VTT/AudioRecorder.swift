@preconcurrency import AVFoundation

/// Captures microphone audio into 16 kHz mono 16-bit PCM and emits a WAV blob —
/// the lingua franca accepted by the cloud transcription APIs.
///
/// `@unchecked Sendable`: `pcm` is touched from the audio tap thread and the
/// main actor, guarded by `lock`.
final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var pcm = Data()
    private var converter: AVAudioConverter?
    private var onLevel: (@Sendable (Float) -> Void)?

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    func start(onLevel: @escaping @Sendable (Float) -> Void) throws {
        lock.lock(); pcm = Data(); self.onLevel = onLevel; lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    /// Stop capture and return the recording as a WAV blob (nil if empty).
    func finish() -> Data? {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        let samples = lock.withLock { pcm }
        return samples.isEmpty ? nil : Self.wav(pcm: samples, format: targetFormat)
    }

    func cancel() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        lock.withLock { pcm = Data() }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { onLevel }?(AudioLevel.normalized(buffer))
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        nonisolated(unsafe) var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0,
              let channel = out.int16ChannelData
        else { return }

        let byteCount = Int(out.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channel[0], count: byteCount)
        lock.withLock { pcm.append(data) }
    }

    /// Wrap raw PCM in a 44-byte RIFF/WAVE header.
    private static func wav(pcm: Data, format: AVAudioFormat) -> Data {
        let channels = UInt16(format.channelCount)
        let sampleRate = UInt32(format.sampleRate)
        let bitsPerSample: UInt16 = 16
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = UInt32(pcm.count)

        var header = Data()
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }
        header.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36 + dataSize))
        header.append(contentsOf: Array("WAVE".utf8))
        header.append(contentsOf: Array("fmt ".utf8))
        appendLE(UInt32(16))            // fmt chunk size
        appendLE(UInt16(1))             // PCM
        appendLE(channels)
        appendLE(sampleRate)
        appendLE(byteRate)
        appendLE(blockAlign)
        appendLE(bitsPerSample)
        header.append(contentsOf: Array("data".utf8))
        appendLE(dataSize)

        return header + pcm
    }
}
