@preconcurrency import AVFoundation
import Foundation

/// Computes a normalized 0...1 loudness from a mic buffer, for the waveform.
enum AudioLevel {
    /// RMS mapped through a dB floor so quiet rooms read ~0 and speech fills the bar.
    static func normalized(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = Int(buffer.frameLength)
        let samples = channels[0]

        var sum: Float = 0
        for i in 0..<frames {
            let s = samples[i]
            sum += s * s
        }
        let rms = (sum / Float(frames)).squareRoot()
        guard rms > 0 else { return 0 }

        let db = 20 * log10(rms)
        let floor: Float = -50
        return max(0, min(1, (db - floor) / -floor))
    }
}
