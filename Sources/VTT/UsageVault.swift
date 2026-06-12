import Foundation
import CryptoKit
import IOKit

/// Tamper-resistant store for the free-tier daily usage counter.
///
/// The honest limitation: with no server, a determined attacker who reverse-
/// engineers the binary can always bypass a local limit. The goal here is only
/// to remove the *trivial* bypass (a one-line `defaults delete`) and raise the
/// bar to "understand the code, find every store, and forge a device-bound
/// signature" — i.e. real effort, not a casual reset.
///
/// How it raises the bar:
/// - The record lives in the **Keychain and a hidden Application Support file**,
///   not UserDefaults, so it survives reinstall and isn't editable with `defaults`.
/// - Each copy is **HMAC-SHA256 signed** with a key derived from an obfuscated
///   in-binary secret mixed with this machine's hardware UUID, so the number
///   can't be hand-edited and a copy can't be moved to another Mac.
/// - **Tamper → fail closed**: a well-formed but wrongly-signed blob is treated
///   as a fully-spent day, so editing the value backfires.
/// - **take-max** across copies + a backward-clock guard, so deleting one store
///   or winding the clock back doesn't grant a fresh allowance.
enum UsageVault {

    /// Effective usage for *today*, already adjusted for day rollover, clock
    /// roll-back and tampering. Mirrors the old `loadDailyUsage()` contract.
    static func loadToday(failClosedSeconds: Double, failClosedBegs: Int)
        -> (day: Date, seconds: Double, begs: Int)
    {
        var records: [Record] = []
        var tampered = false
        for raw in [keychainRead(), fileRead()] {
            guard let raw else { continue }
            switch decode(raw) {
            case .valid(let r):   records.append(r)
            case .tampered:       tampered = true
            case .unreadable:     break
            }
        }

        // Never let the clock move backward relative to what we last saw.
        let now = Date()
        let maxSeen = records.map(\.lastSeen).max() ?? now
        let trustedNow = max(now, maxSeen)
        let today = Calendar.current.startOfDay(for: trustedNow)

        // Editing a blob (valid format, bad signature) burns the whole day.
        if tampered {
            return (today, failClosedSeconds, failClosedBegs)
        }

        let todays = records.filter { Calendar.current.isDate($0.day, inSameDayAs: today) }
        guard !todays.isEmpty else { return (today, 0, 0) }
        return (today,
                todays.map(\.seconds).max() ?? 0,
                todays.map(\.begs).max() ?? 0)
    }

    /// Persist today's counters to every backing store, signed.
    static func save(day: Date, seconds: Double, begs: Int) {
        let record = Record(day: Calendar.current.startOfDay(for: day),
                            seconds: seconds, begs: begs, lastSeen: Date())
        let blob = encode(record)
        keychainWrite(blob)
        fileWrite(blob)
    }

    /// Wipe every store (used by the in-app developer reset, not shipped to users).
    static func reset() {
        keychainWrite(nil)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Record

    private struct Record {
        let day: Date
        let seconds: Double
        let begs: Int
        let lastSeen: Date

        /// Deterministic payload so the signature is stable across runs.
        var payload: String {
            "\(day.timeIntervalSinceReferenceDate)|\(seconds)|\(begs)|\(lastSeen.timeIntervalSinceReferenceDate)"
        }

        static func parse(_ payload: String) -> Record? {
            let p = payload.split(separator: "|", omittingEmptySubsequences: false)
            guard p.count == 4,
                  let d = Double(p[0]), let s = Double(p[1]),
                  let b = Int(p[2]), let l = Double(p[3]) else { return nil }
            return Record(day: Date(timeIntervalSinceReferenceDate: d), seconds: s,
                         begs: b, lastSeen: Date(timeIntervalSinceReferenceDate: l))
        }
    }

    private enum Decoded { case valid(Record), tampered, unreadable }

    // MARK: - Sign / verify

    /// `base64(payload).base64(hmac)` — present-but-wrong-mac means tampering.
    private static func encode(_ r: Record) -> String {
        let payload = Data(r.payload.utf8)
        let mac = Data(HMAC<SHA256>.authenticationCode(for: payload, using: key))
        return payload.base64EncodedString() + "." + mac.base64EncodedString()
    }

    private static func decode(_ blob: String) -> Decoded {
        let parts = blob.split(separator: ".", maxSplits: 1)
        guard parts.count == 2,
              let payload = Data(base64Encoded: String(parts[0])),
              let mac = Data(base64Encoded: String(parts[1])),
              let text = String(data: payload, encoding: .utf8),
              let record = Record.parse(text)
        else { return .unreadable }

        let expected = Data(HMAC<SHA256>.authenticationCode(for: payload, using: key))
        // Constant-time-ish compare; well-formed blob with a bad mac is tampering.
        guard mac.count == expected.count,
              zip(mac, expected).reduce(0, { $0 | ($1.0 ^ $1.1) }) == 0
        else { return .tampered }
        return .valid(record)
    }

    /// Signing key = HMAC(obfuscated in-binary secret, this Mac's hardware UUID).
    /// Binds blobs to the binary *and* the machine; not a plaintext string.
    private static let key: SymmetricKey = {
        let secret = Data(obfuscatedSecret.map { $0 ^ 0x5A })
        let bound = HMAC<SHA256>.authenticationCode(for: Data(hardwareUUID.utf8),
                                                    using: SymmetricKey(data: secret))
        return SymmetricKey(data: Data(bound))
    }()

    /// App secret, stored XOR-0x5A so it isn't a readable string in the binary.
    private static let obfuscatedSecret: [UInt8] = [
        0x39, 0x2f, 0x3e, 0x6b, 0x1d, 0x77, 0x52, 0x08, 0x6e, 0x14, 0x3a, 0x29, 0x60, 0x4c, 0x1b, 0x35,
        0x7a, 0x06, 0x4f, 0x21, 0x58, 0x13, 0x2c, 0x6d, 0x09, 0x44, 0x3f, 0x70, 0x1e, 0x5b, 0x27, 0x62,
    ]

    private static let hardwareUUID: String = {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(svc) }
        if let cf = IORegistryEntryCreateCFProperty(svc, "IOPlatformUUID" as CFString,
                                                    kCFAllocatorDefault, 0)?.takeRetainedValue(),
           let uuid = cf as? String {
            return uuid
        }
        return "vtt-unknown-device"
    }()

    // MARK: - Keychain backend (survives reinstall, not visible to `defaults`)

    private static let kcService = "com.the-ihor.vtt.s"
    private static let kcAccount = "d"

    private static func keychainRead() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainWrite(_ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount,
        ]
        guard let value else { SecItemDelete(base as CFDictionary); return }
        let data = Data(value.utf8)
        let status = SecItemUpdate(base as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    // MARK: - File backend (disguised name in Application Support)

    private static let fileURL: URL = {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent(".vtt-dcache", isDirectory: false)
    }()

    private static func fileRead() -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func fileWrite(_ blob: String) {
        try? Data(blob.utf8).write(to: fileURL, options: [.atomic])
    }
}
