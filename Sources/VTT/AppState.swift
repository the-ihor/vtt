import AppKit
import Combine
import Speech
import SwiftUI

extension Notification.Name {
    /// Posted when a free-tier user tries to dictate past the daily limit.
    static let vttFreeLimitReached = Notification.Name("vttFreeLimitReached")
    /// Posted to ask an open Settings window to switch to the VTT Pro tab.
    static let vttShowProTab = Notification.Name("vttShowProTab")
}

/// Estimated cloud spend on a single day, for the spend trend graph.
struct DailySpend: Identifiable, Sendable {
    let date: Date
    let cost: Double
    var id: Date { date }
}

/// Shared, observable state for the floating bar and the dictation lifecycle.
@MainActor
final class AppState: ObservableObject {
    enum Mode: Equatable {
        case idle
        case recording
        case transcribing
    }

    @Published private(set) var mode: Mode = .idle

    /// Live transcript while recording.
    @Published var partialText: String = ""

    /// Final transcript from the last completed dictation.
    @Published var lastTranscript: String = ""

    /// Smoothed 0...1 mic level driving the waveform while recording.
    @Published private(set) var level: Float = 0

    /// True between hitting record and the audio pipeline actually going live.
    /// The macOS 26 SpeechAnalyzer installs its on-device language model on
    /// first use, which can take a while; surfaced as "Preparing…" in the bar
    /// so the user knows to wait rather than thinking it's listening already.
    @Published private(set) var preparing = false

    /// Default speech backend, used for any language without an override.
    @Published var source: SpeechSource = .appleOnDevice

    /// Optional per-language provider overrides (language code → provider). A
    /// language with no entry falls back to `source`. Lets you route, say,
    /// Russian to a cloud engine while English stays on-device.
    @Published var languageProviders: [String: SpeechSource] {
        didSet { persistLanguageProviders() }
    }

    /// Provider chosen for a language: its explicit override, or the smart
    /// default (see `defaultProvider(for:)`).
    func provider(for code: String) -> SpeechSource {
        languageProviders[Languages.named(code).code] ?? defaultProvider(for: code)
    }

    /// The automatic provider for a language when the user hasn't overridden it:
    /// Apple's macOS 26 SpeechAnalyzer when it supports the language and its
    /// on-device model is installed, then the legacy on-device recognizer if it
    /// supports the language, then the global fallback provider.
    func defaultProvider(for code: String) -> SpeechSource {
        if #available(macOS 26, *),
           isSupported(code, by: .appleSpeechAnalyzer),
           isModelInstalled(code) {
            return .appleSpeechAnalyzer
        }
        if Languages.isSupported(code, by: .appleOnDevice) {
            return .appleOnDevice
        }
        return source
    }

    /// The provider that would handle a recording started right now.
    var activeProvider: SpeechSource { provider(for: resolvedLanguage.code) }

    /// Available models per provider, loaded from GitHub with bundled fallback.
    let modelCatalog = ModelCatalog()

    /// User-selected model per provider (provider rawValue → model id).
    @Published var selectedModels: [String: String] {
        didSet { persistSelectedModels() }
    }

    /// The model id to use for a provider: the user's choice if still offered,
    /// otherwise the first (default) model in the catalog.
    func model(for source: SpeechSource) -> String {
        let available = modelCatalog.models(for: source)
        if let id = selectedModels[source.rawValue], available.contains(where: { $0.id == id }) {
            return id
        }
        return available.first?.id ?? ""
    }

    /// Provider handling the in-flight/last recording, for the floating bar.
    @Published private(set) var displayProvider: SpeechSource = .appleOnDevice

    /// Active transcription language (ISO 639-1 code). Persisted, passed to the
    /// provider so it transcribes in this language.
    @Published var activeLanguage: String {
        didSet { UserDefaults.standard.set(activeLanguage, forKey: "activeLanguage") }
    }

    /// Languages from the user's enabled macOS keyboard input sources. The
    /// active language is one of these or `Languages.auto`. Derived from the system.
    @Published private(set) var selectorLanguages: [String]

    /// Language codes the macOS 26 SpeechAnalyzer actually supports, probed from
    /// the system. Empty until loaded (and on older OSes), in which case support
    /// falls back to the static list.
    @Published private(set) var analyzerSupportedCodes: Set<String> = []

    /// Language codes whose on-device SpeechAnalyzer model is installed.
    @Published private(set) var analyzerInstalledCodes: Set<String> = []

    /// In-flight model downloads: language code → 0...1 progress.
    @Published private(set) var analyzerDownloading: [String: Double] = [:]

    /// Language code shown in the bar for the in-flight recording.
    @Published private(set) var displayLanguage: String = ""

    /// The concrete language to transcribe in: the active one, or — when set to
    /// `auto` — whatever keyboard is currently active.
    var resolvedLanguage: AppLanguage {
        if activeLanguage == Languages.auto {
            return Languages.named(KeyboardLanguages.currentCode() ?? Languages.systemDefault)
        }
        return Languages.named(activeLanguage)
    }

    /// Show the live (interim) transcript inside the floating bar. Persisted.
    /// Has no effect for backends that don't stream partials.
    @Published var showLiveText: Bool {
        didSet { UserDefaults.standard.set(showLiveText, forKey: "showLiveText") }
    }

    /// Mute system audio output while dictating, restoring it on stop. Persisted.
    @Published var muteWhileRecording: Bool {
        didSet { UserDefaults.standard.set(muteWhileRecording, forKey: "muteWhileRecording") }
    }

    /// When on, the final transcript is pasted into the focused app (needs
    /// Accessibility access). Persisted across launches.
    @Published var autoInsert: Bool {
        didSet { UserDefaults.standard.set(autoInsert, forKey: "autoInsert") }
    }

    /// Primary global hotkey that toggles dictation. Persisted.
    @Published var primaryHotkey: HotkeyChord {
        didSet { Self.persist(primaryHotkey, forKey: "primaryHotkey") }
    }

    /// Secondary global hotkey that also toggles dictation. Persisted.
    @Published var alternativeHotkey: HotkeyChord {
        didSet { Self.persist(alternativeHotkey, forKey: "alternativeHotkey") }
    }

    /// Seconds of audio sent to each cloud provider, keyed by `source.rawValue`.
    /// Persisted, used to estimate spend.
    @Published private(set) var usageSeconds: [String: Double]

    /// Per-day cloud usage for the spend breakdown and trend graph:
    /// `"yyyy-MM-dd"` → (`source.rawValue` → seconds). Pruned to recent days.
    @Published private(set) var dailyCloudSeconds: [String: [String: Double]]

    /// Free-tier dictation allowance per calendar day, across every engine.
    /// Beyond this, recording is gated behind VTT Pro.
    static let freeSecondsPerDay: Double = 15 * 60

    /// Seconds of dictation used so far in the current local day (all engines).
    /// Resets at midnight. Persisted so the limit survives relaunches.
    @Published private(set) var secondsUsedToday: Double = 0

    /// How many extra "beg one more" recordings a free user may grant
    /// themselves per day once the time cap is spent.
    static let begsPerDay = 3

    /// "Beg one more" grants used so far today. Resets at midnight.
    @Published private(set) var begsUsedToday: Int = 0

    /// Start-of-day the `secondsUsedToday` / `begsUsedToday` counters apply to.
    private var usageDay: Date

    /// VTT Pro subscription / entitlement. Drives whether the daily cap applies.
    let store = SubscriptionStore()

    /// Mirror the subscription store's changes so views observing only AppState
    /// (and `isPro` reads) stay in sync when the entitlement flips.
    private var storeObserver: AnyCancellable?

    /// Whether the user has unlimited dictation.
    var isPro: Bool { store.isPro }

    /// Seconds of free dictation left today (0 once the cap is hit).
    var remainingFreeSeconds: Double { max(0, Self.freeSecondsPerDay - secondsUsedToday) }

    /// Whether a new recording is currently allowed.
    var canRecord: Bool { isPro || remainingFreeSeconds > 0 }

    /// "Beg one more" grants left today (0 for Pro users — they never need it).
    var begsRemaining: Int { isPro ? 0 : max(0, Self.begsPerDay - begsUsedToday) }

    /// System permission state surfaced in Settings.
    let permissions = Permissions()

    private var recordingStart: Date?
    private var recordingSource: SpeechSource = .appleOnDevice

    /// The transcriber for the in-flight recording, chosen from `source` when
    /// recording starts and reused through `finish()`.
    private var transcriber: SpeechTranscribing?

    /// Build the backend for the selected provider. Unimplemented providers
    /// fall back to the classic on-device recognizer.
    private func makeTranscriber(for provider: SpeechSource) -> SpeechTranscribing {
        let language = resolvedLanguage
        switch provider {
        case .appleSpeechAnalyzer:
            if #available(macOS 26, *) {
                return AppleSpeechAnalyzerTranscriber(localeIdentifier: language.locale)
            }
            return AppleSpeechTranscriber(localeIdentifier: language.locale)
        case .appleOnDevice:
            return AppleSpeechTranscriber(localeIdentifier: language.locale)
        case .deepgram:
            return DeepgramStreamingTranscriber(apiKey: apiKey(for: .deepgram), language: language.code, model: model(for: .deepgram))
        case .elevenLabs:
            return CloudTranscriber(api: ElevenLabsAPI(model: model(for: .elevenLabs)), apiKey: apiKey(for: .elevenLabs), language: language.code)
        case .openAI:
            return CloudTranscriber(api: OpenAIAPI(model: model(for: .openAI)), apiKey: apiKey(for: .openAI), language: language.code)
        }
    }

    /// Read the stored API key for a cloud provider (empty if unset).
    func apiKey(for source: SpeechSource) -> String {
        Keychain.get(source.rawValue) ?? ""
    }

    /// Store (or clear) the API key for a cloud provider. Trims stray
    /// whitespace/newlines that often come with a pasted key and break auth.
    func setAPIKey(_ key: String, for source: SpeechSource) {
        Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: source.rawValue)
        objectWillChange.send()
    }

    init() {
        usageSeconds = Self.loadUsage()
        dailyCloudSeconds = Self.loadDailyCloud()
        languageProviders = Self.loadLanguageProviders()
        selectedModels = Self.loadSelectedModels()
        let daily = Self.loadDailyUsage()
        usageDay = daily.day
        secondsUsedToday = daily.seconds
        begsUsedToday = daily.begs
        autoInsert = UserDefaults.standard.bool(forKey: "autoInsert")
        // Default the live-text toggle on unless the user has turned it off.
        showLiveText = UserDefaults.standard.object(forKey: "showLiveText") as? Bool ?? true
        muteWhileRecording = UserDefaults.standard.object(forKey: "muteWhileRecording") as? Bool ?? true
        activeLanguage = UserDefaults.standard.string(forKey: "activeLanguage") ?? Languages.auto
        selectorLanguages = Languages.keyboard().map(\.code)
        primaryHotkey = Self.load(forKey: "primaryHotkey") ?? .f13
        alternativeHotkey = Self.load(forKey: "alternativeHotkey") ?? .ctrlOptSpace

        // Keep the active language valid (auto, or one of the keyboard languages).
        if activeLanguage != Languages.auto, !selectorLanguages.contains(activeLanguage) {
            activeLanguage = Languages.auto
        }

        // Re-publish when the subscription entitlement changes so `isPro`-driven
        // UI updates even when a view observes only AppState.
        storeObserver = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        Task { @MainActor in await refreshAnalyzerModels() }
        Task { @MainActor in await modelCatalog.refresh() }
    }

    private func persistSelectedModels() {
        guard let data = try? JSONEncoder().encode(selectedModels) else { return }
        UserDefaults.standard.set(data, forKey: "selectedModels")
    }

    private static func loadSelectedModels() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: "selectedModels"),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    // MARK: - SpeechAnalyzer language models

    /// Probe the system for which languages SpeechAnalyzer supports and which
    /// models are installed, so the UI can distinguish "supported", "not
    /// downloaded", and "not supported" accurately. No-op before macOS 26.
    func refreshAnalyzerModels() async {
        guard #available(macOS 26, *), SpeechTranscriber.isAvailable else { return }

        // `supportedLocales` is the set of locales whose transcription assets
        // actually exist (installed or downloadable). The per-locale resolver
        // `supportedLocale(equivalentTo:)` over-reports — it maps e.g. "ru" to a
        // locale whose asset doesn't exist, so a download attempt fails with
        // "asset not found". Trust the enumerated list.
        let supported = await SpeechTranscriber.supportedLocales
        analyzerSupportedCodes = Set(supported.compactMap { $0.language.languageCode?.identifier })

        let installed = await SpeechTranscriber.installedLocales
        analyzerInstalledCodes = Set(installed.compactMap { $0.language.languageCode?.identifier })
    }

    /// Download + install the SpeechAnalyzer model for a language, publishing
    /// progress so Settings can show a bar.
    func downloadAnalyzerModel(code: String) async {
        guard #available(macOS 26, *) else { return }
        let language = Languages.named(code)
        // Resolve against the authoritative supported list so we only ever try
        // to fetch an asset that actually exists.
        guard let locale = await SpeechTranscriber.supportedLocales.first(where: {
            $0.language.languageCode?.identifier == language.code
        }) else { return }

        let module = SpeechTranscriber(
            locale: locale, transcriptionOptions: [],
            reportingOptions: [.volatileResults], attributeOptions: []
        )
        do {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
                NSLog("VTT: model for \(code) (\(locale.identifier)) already installed")
                analyzerInstalledCodes.insert(language.code)
                return
            }
            analyzerDownloading[code] = 0
            let progress = request.progress
            let poll = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.analyzerDownloading[code] = progress.fractionCompleted
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
            defer { poll.cancel() }

            try await request.downloadAndInstall()
            analyzerDownloading[code] = nil
            analyzerInstalledCodes.insert(language.code)
        } catch {
            NSLog("VTT: SpeechAnalyzer model download for \(code) failed: \(error)")
            analyzerDownloading[code] = nil
        }
    }

    /// Whether a provider can transcribe a language. For SpeechAnalyzer this
    /// reflects the system's real capabilities once probed; otherwise it falls
    /// back to the static support list.
    func isSupported(_ code: String, by provider: SpeechSource) -> Bool {
        if provider == .appleSpeechAnalyzer, !analyzerSupportedCodes.isEmpty {
            return analyzerSupportedCodes.contains(Languages.named(code).code)
        }
        return Languages.isSupported(code, by: provider)
    }

    /// Whether the on-device model for a language is installed (SpeechAnalyzer).
    func isModelInstalled(_ code: String) -> Bool {
        analyzerInstalledCodes.contains(Languages.named(code).code)
    }

    /// Languages a provider supports, narrowed to the engine's real set for
    /// SpeechAnalyzer once known.
    func supportedLanguages(by provider: SpeechSource) -> [AppLanguage] {
        let base = Languages.supported(by: provider)
        guard provider == .appleSpeechAnalyzer, !analyzerSupportedCodes.isEmpty else { return base }
        return base.filter { analyzerSupportedCodes.contains($0.code) }
    }

    /// Re-read keyboard languages from the system (they can change at runtime).
    func refreshLanguages() {
        selectorLanguages = Languages.keyboard().map(\.code)
        if activeLanguage != Languages.auto, !selectorLanguages.contains(activeLanguage) {
            activeLanguage = Languages.auto
        }
    }

    /// Restore both hotkeys to their factory defaults.
    func resetHotkeys() {
        primaryHotkey = .f13
        alternativeHotkey = .ctrlOptSpace
    }

    private static func load(forKey key: String) -> HotkeyChord? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyChord.self, from: data)
    }

    private static func persist(_ chord: HotkeyChord, forKey key: String) {
        guard let data = try? JSONEncoder().encode(chord) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Cloud usage / spend

    /// Estimated USD spent on a provider so far.
    func estimatedCost(for source: SpeechSource) -> Double {
        (usageSeconds[source.rawValue] ?? 0) / 60 * (source.costPerMinute ?? 0)
    }

    /// Estimated USD across all cloud providers.
    var totalCloudCost: Double {
        SpeechSource.allCases.reduce(0) { $0 + estimatedCost(for: $1) }
    }

    func resetUsage() {
        usageSeconds = [:]
        persistUsage()
        dailyCloudSeconds = [:]
        persistDailyCloud()
    }

    // MARK: - Cloud spend windows & history

    /// Estimated USD spent on cloud providers today.
    var cloudCostToday: Double { cloudCost(on: Date()) }

    /// Estimated USD spent on cloud providers in the current calendar month.
    var cloudCostThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return dailyCloudSeconds.reduce(0) { acc, entry in
            guard let day = Self.day(fromKey: entry.key),
                  cal.isDate(day, equalTo: now, toGranularity: .month) else { return acc }
            return acc + Self.cost(of: entry.value)
        }
    }

    /// Estimated USD spent on cloud providers on a given day.
    func cloudCost(on day: Date) -> Double {
        Self.cost(of: dailyCloudSeconds[Self.dayKey(day)] ?? [:])
    }

    /// Cloud spend per day for the last `days` days (oldest first), including
    /// zero-spend days, for the trend graph.
    func recentDailyCloudCost(days: Int) -> [DailySpend] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailySpend(date: day, cost: cloudCost(on: day))
        }
    }

    private static func cost(of perProvider: [String: Double]) -> Double {
        perProvider.reduce(0) { acc, kv in
            guard let src = SpeechSource(rawValue: kv.key) else { return acc }
            return acc + kv.value / 60 * (src.costPerMinute ?? 0)
        }
    }

    /// Keep roughly four months of history so the log can't grow unbounded.
    private func pruneDailyCloud() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: Date()) else { return }
        dailyCloudSeconds = dailyCloudSeconds.filter { key, _ in
            guard let day = Self.day(fromKey: key) else { return false }
            return day >= Calendar.current.startOfDay(for: cutoff)
        }
    }

    private func persistDailyCloud() {
        guard let data = try? JSONEncoder().encode(dailyCloudSeconds) else { return }
        UserDefaults.standard.set(data, forKey: "dailyCloudSeconds")
    }

    private static func loadDailyCloud() -> [String: [String: Double]] {
        guard let data = UserDefaults.standard.data(forKey: "dailyCloudSeconds"),
              let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data)
        else { return [:] }
        return decoded
    }

    /// "yyyy-MM-dd" in the local time zone, the key for `dailyCloudSeconds`.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }
    private static func day(fromKey key: String) -> Date? { dayKeyFormatter.date(from: key) }

    // MARK: - Daily free-tier metering

    /// Roll the daily counter over to zero when the calendar day changes.
    /// Call before reading or mutating the daily usage.
    func refreshUsage() {
        let today = Calendar.current.startOfDay(for: Date())
        guard !Calendar.current.isDate(usageDay, inSameDayAs: today) else { return }
        usageDay = today
        secondsUsedToday = 0
        begsUsedToday = 0
        persistDailyUsage()
    }

    /// Grant one extra recording when a free user is out of time and chooses to
    /// "beg" for more. Consumes a daily beg and starts recording immediately.
    func begOneMore() {
        refreshUsage()
        guard begsRemaining > 0 else { return }
        begsUsedToday += 1
        persistDailyUsage()
        startRecording(bypassingLimit: true)
    }

    /// Record one completed dictation: always toward the daily free-tier cap,
    /// and toward per-provider lifetime spend for billable cloud engines.
    private func recordDictation(_ seconds: Double, for source: SpeechSource) {
        refreshUsage()
        secondsUsedToday += seconds
        persistDailyUsage()

        if source.category == .network {
            usageSeconds[source.rawValue, default: 0] += seconds
            persistUsage()

            let key = Self.dayKey(Date())
            dailyCloudSeconds[key, default: [:]][source.rawValue, default: 0] += seconds
            pruneDailyCloud()
            persistDailyCloud()
        }
    }

    private func persistDailyUsage() {
        UserDefaults.standard.set(usageDay, forKey: "dailyUsageDay")
        UserDefaults.standard.set(secondsUsedToday, forKey: "dailyUsageSeconds")
        UserDefaults.standard.set(begsUsedToday, forKey: "dailyBegs")
    }

    /// Load today's usage, or zero if the stored counters are from a past day.
    private static func loadDailyUsage() -> (day: Date, seconds: Double, begs: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        if let storedDay = UserDefaults.standard.object(forKey: "dailyUsageDay") as? Date,
           Calendar.current.isDate(storedDay, inSameDayAs: today) {
            return (today,
                    UserDefaults.standard.double(forKey: "dailyUsageSeconds"),
                    UserDefaults.standard.integer(forKey: "dailyBegs"))
        }
        return (today, 0, 0)
    }

    private func persistUsage() {
        guard let data = try? JSONEncoder().encode(usageSeconds) else { return }
        UserDefaults.standard.set(data, forKey: "usageSeconds")
    }

    private static func loadUsage() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: "usageSeconds"),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persistLanguageProviders() {
        let raw = languageProviders.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(raw) else { return }
        UserDefaults.standard.set(data, forKey: "languageProviders")
    }

    private static func loadLanguageProviders() -> [String: SpeechSource] {
        guard let data = UserDefaults.standard.data(forKey: "languageProviders"),
              let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let provider = SpeechSource(rawValue: pair.value) { result[pair.key] = provider }
        }
    }

    var isRecording: Bool { mode == .recording }

    func toggle() {
        switch mode {
        case .idle, .transcribing:
            startRecording()
        case .recording:
            stopRecording()
        }
    }

    /// - Parameter bypassingLimit: skip the free-tier gate (used by
    ///   `begOneMore()`, which has already consumed a beg grant).
    func startRecording(bypassingLimit: Bool = false) {
        guard mode != .recording else { return }

        // Free-tier gate: block once the daily allowance is spent (Pro is
        // unlimited). Checked at start only — an in-flight recording is never
        // cut off mid-sentence.
        if !bypassingLimit {
            refreshUsage()
            guard canRecord else {
                NotificationCenter.default.post(name: .vttFreeLimitReached, object: nil)
                return
            }
        }

        mode = .recording
        partialText = ""
        level = 0

        displayLanguage = resolvedLanguage.code
        let activeProvider = provider(for: resolvedLanguage.code)
        displayProvider = activeProvider
        // Only the SpeechAnalyzer engine has a meaningful warm-up (model
        // install); other backends are live the moment they start, so showing
        // "Preparing…" for them would just flicker.
        preparing = activeProvider == .appleSpeechAnalyzer
        let transcriber = makeTranscriber(for: activeProvider)
        self.transcriber = transcriber
        recordingStart = Date()
        recordingSource = activeProvider
        if muteWhileRecording { SystemAudio.mute() }

        Task { @MainActor in
            let granted = await transcriber.requestAuthorization()
            guard granted else {
                NSLog("VTT: speech/mic permission not granted")
                SystemAudio.restore()
                preparing = false
                mode = .idle
                return
            }
            do {
                try transcriber.start(
                    onPartial: { [weak self] partial in
                        Task { @MainActor in self?.partialText = partial }
                    },
                    onLevel: { [weak self] value in
                        Task { @MainActor in self?.updateLevel(value) }
                    }
                )
            } catch {
                NSLog("VTT: failed to start transcription: \(error)")
                SystemAudio.restore()
                preparing = false
                mode = .idle
            }
        }
    }

    /// Abort the in-progress recording without producing or inserting text.
    func cancelRecording() {
        guard mode == .recording else { return }
        transcriber?.cancel()
        transcriber = nil
        partialText = ""
        level = 0
        preparing = false
        SystemAudio.restore()
        mode = .idle
    }

    /// Exponential smoothing so the bar glides rather than flickers.
    private func updateLevel(_ value: Float) {
        guard mode == .recording else { return }
        // The first level callback comes from the audio tap, i.e. capture is
        // live — clear the "Preparing…" state and start the billing clock now
        // so a slow first-run model install isn't charged against the daily cap.
        if preparing {
            preparing = false
            recordingStart = Date()
        }
        level = level * 0.6 + value * 0.4
    }

    func stopRecording() {
        guard mode == .recording else { return }
        mode = .transcribing

        level = 0
        preparing = false
        SystemAudio.restore()

        let start = recordingStart
        let usedSource = recordingSource
        recordingStart = nil

        Task { @MainActor in
            guard let transcriber else { mode = .idle; return }
            let text = await transcriber.finish()
            lastTranscript = text

            // Meter usage by recording duration when a transcript came back:
            // the daily free-tier cap counts every engine, cloud spend only the
            // billable ones.
            if !text.isEmpty, let start {
                recordDictation(Date().timeIntervalSince(start), for: usedSource)
            }
            if !text.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                if autoInsert {
                    permissions.refresh()
                    if permissions.accessibilityTrusted {
                        TextInserter.paste()
                    } else {
                        NSLog("VTT: auto-insert on but Accessibility not granted")
                    }
                }
            }
            // Release the backend so its AVAudioEngine deallocates and the mic
            // indicator turns off while idle.
            self.transcriber = nil
            mode = .idle
        }
    }
}
