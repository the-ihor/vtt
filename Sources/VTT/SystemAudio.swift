import CoreAudio
import Foundation

/// Mutes the default system output device while dictating and restores its
/// previous state afterwards, so playing audio doesn't bleed into the mic.
enum SystemAudio {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var savedMute: Bool?

    /// Mute the default output, remembering whether it was already muted.
    static func mute() {
        guard let device = defaultOutputDevice(), let current = mute(of: device) else { return }
        lock.lock(); savedMute = current; lock.unlock()
        setMute(device, to: true)
    }

    /// Restore the output to its pre-`mute()` state. Safe to call when nothing
    /// was muted (no-op).
    static func restore() {
        lock.lock(); let saved = savedMute; savedMute = nil; lock.unlock()
        guard let saved, let device = defaultOutputDevice() else { return }
        setMute(device, to: saved)
    }

    // MARK: - CoreAudio

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr ? device : nil
    }

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    /// Current mute state, or nil if the device doesn't expose a settable mute.
    private static func mute(of device: AudioObjectID) -> Bool? {
        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
              settable.boolValue else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value != 0
    }

    private static func setMute(_ device: AudioObjectID, to muted: Bool) {
        var address = muteAddress()
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
    }
}
