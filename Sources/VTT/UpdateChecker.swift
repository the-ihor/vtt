#if DIRECT_DISTRIBUTION
import AppKit
import Security

/// Self-update for the direct-download build (the App Store channel updates
/// through Apple). Checks a small version feed on the website daily, and on
/// the user's request from the menu bar. When a newer build exists it
/// downloads the notarized dmg, verifies the new app is signed by our team,
/// swaps /Applications/VTT.app, and relaunches. Any failure falls back to
/// opening the dmg so the user can drag-install manually.
@MainActor
final class UpdateChecker {
    /// Published by scripts/make-devid.sh on every release.
    private static let feedURL = URL(string: "https://vtt.the-ihor.com/version.json")!
    private static let teamID = "752556J5V6"
    private static let lastCheckKey = "updateLastCheckAt"
    /// At most one quiet check per day.
    private static let quietInterval: TimeInterval = 24 * 3600

    struct Feed: Decodable {
        let version: String
        let build: Int
        let dmg: URL
        let notes: String?
    }

    private var timer: Timer?
    private var installing = false

    /// Kick off the daily background cadence.
    func start() {
        Task { await checkQuietly() }
        // Re-check while the app stays running for weeks (timer fires hourly,
        // the quiet-interval gate makes it effectively daily).
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in await self.checkQuietly() }
        }
    }

    private var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func checkQuietly() async {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last > Self.quietInterval else { return }
        await check(interactive: false)
    }

    /// `interactive` = explicitly requested from the menu: also report
    /// "up to date" and errors, not just available updates.
    func check(interactive: Bool) async {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        do {
            var request = URLRequest(url: Self.feedURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            if feed.build > currentBuild {
                offer(feed)
            } else if interactive {
                inform("You're up to date", "VTT \(currentVersion) is the latest version.")
            }
        } catch {
            if interactive {
                inform("Couldn't check for updates", error.localizedDescription)
            }
        }
    }

    // MARK: - Update flow

    private func offer(_ feed: Feed) {
        guard !installing else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "VTT \(feed.version) is available"
        var info = "You have \(currentVersion). The update downloads in the background and relaunches when ready."
        if let notes = feed.notes, !notes.isEmpty { info = notes + "\n\n" + info }
        alert.informativeText = info
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        installing = true
        Task {
            defer { installing = false }
            await downloadAndInstall(feed)
        }
    }

    private func downloadAndInstall(_ feed: Feed) async {
        let fm = FileManager.default
        let dmg = fm.temporaryDirectory.appendingPathComponent("VTT-update.dmg")
        let mount = fm.temporaryDirectory.appendingPathComponent("VTT-update-mount")

        do {
            let (downloaded, _) = try await URLSession.shared.download(from: feed.dmg)
            try? fm.removeItem(at: dmg)
            try fm.moveItem(at: downloaded, to: dmg)

            try? fm.removeItem(at: mount)
            try await run("/usr/bin/hdiutil", [
                "attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path,
            ])
            defer {
                Task.detached { try? await Self.runDetachable("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
            }

            let newApp = mount.appendingPathComponent("VTT.app")
            try verifySignature(at: newApp)

            // Replace the running bundle in place. Deleting a running app is
            // fine on macOS — open files stay mapped until we relaunch.
            let dest = Bundle.main.bundleURL
            try fm.removeItem(at: dest)
            try await run("/usr/bin/ditto", [newApp.path, dest.path])

            // Hand the relaunch to a detached shell that outlives us.
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"\(dest.path)\""]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            // Manual fallback: hand the user the verified-notarized dmg.
            inform(
                "Couldn't install automatically",
                "\(error.localizedDescription)\n\nThe update dmg will open — drag VTT into Applications to finish."
            )
            NSWorkspace.shared.open(dmg)
        }
    }

    /// The new bundle must be validly signed by our Developer ID team —
    /// protects the swap even if the download URL were ever compromised.
    private func verifySignature(at url: URL) throws {
        var staticCode: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard status == errSecSuccess, let staticCode else {
            throw NSError(domain: "VTTUpdate", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The downloaded app couldn't be read for verification.",
            ])
        }
        var requirement: SecRequirement?
        status = SecRequirementCreateWithString(
            "anchor apple generic and certificate leaf[subject.OU] = \"\(Self.teamID)\"" as CFString,
            [], &requirement
        )
        guard status == errSecSuccess, let requirement else {
            throw NSError(domain: "VTTUpdate", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Internal signature requirement error.",
            ])
        }
        status = SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            requirement
        )
        guard status == errSecSuccess else {
            throw NSError(domain: "VTTUpdate", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "The downloaded app failed signature verification — update aborted.",
            ])
        }
    }

    // MARK: - Helpers

    private func run(_ tool: String, _ arguments: [String]) async throws {
        try await Self.runDetachable(tool, arguments)
    }

    private static func runDetachable(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: NSError(domain: "VTTUpdate", code: Int(p.terminationStatus), userInfo: [
                        NSLocalizedDescriptionKey: "\(URL(fileURLWithPath: tool).lastPathComponent) failed (exit \(p.terminationStatus)).",
                    ]))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }

    private func inform(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
#endif
