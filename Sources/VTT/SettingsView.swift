import AppKit
import AVFoundation
import Carbon.HIToolbox
import Charts
import Speech
import SwiftUI

/// Tab to show in Settings: one per provider, plus a shared General tab.
private enum SettingsTab: Hashable {
    case provider(SpeechSource)
    case general
    case pro
}

/// Native settings pane: a tab per speech provider, opened on the active one.
struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var permissions: Permissions
    @State private var tab: SettingsTab

    init(state: AppState, permissions: Permissions) {
        _state = ObservedObject(wrappedValue: state)
        _permissions = ObservedObject(wrappedValue: permissions)
        // Always open on General.
        _tab = State(initialValue: .general)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $tab) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsTab.general)

                Label("Subscription", systemImage: state.isPro ? "checkmark.seal.fill" : "sparkles")
                    .tag(SettingsTab.pro)

                ForEach(ProviderCategory.allCases, id: \.self) { category in
                    Section(category.title) {
                        ForEach(SpeechSource.allCases.filter { $0.category == category }) { provider in
                            Label {
                                Text(provider.shortName)
                            } icon: {
                                ProviderIcon(provider: provider)
                            }
                            .tag(SettingsTab.provider(provider))
                        }
                    }
                }
            }
            // navigationSplitViewColumnWidth is ignored for the sidebar column
            // on macOS (FB10749141); a minWidth frame on the List is honored.
            .frame(minWidth: 220, idealWidth: 230)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            content
                .navigationTitle(title)
        }
        .frame(width: 760, height: 440)
        .onAppear {
            permissions.refresh()
            state.refreshLanguages()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            permissions.refresh()
            state.refreshLanguages()
            state.refreshUsage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vttShowProTab)) { _ in
            tab = .pro
        }
    }

    private var title: String {
        switch tab {
        case .provider(let provider): provider.displayName
        case .general: "General"
        case .pro: "Subscription"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .provider(let provider):
            ProviderTab(
                provider: provider,
                isActive: state.source == provider,
                makeActive: { state.source = provider },
                state: state,
                permissions: permissions,
                catalog: state.modelCatalog
            )
        case .general:
            GeneralTab(state: state, permissions: permissions)
        case .pro:
            ProTab(state: state, store: state.store)
        }
    }
}

/// A single provider's tab: status, activation, and its access buttons.
private struct ProviderTab: View {
    let provider: SpeechSource
    let isActive: Bool
    let makeActive: () -> Void
    @ObservedObject var state: AppState
    @ObservedObject var permissions: Permissions
    @ObservedObject var catalog: ModelCatalog

    var body: some View {
        Form {
            Section {
                let availability = provider.availability
                HStack(spacing: 12) {
                    Image(systemName: availability.ok
                        ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(availability.ok ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(availability.ok ? "Available on your system" : "Not available")
                            .font(.headline)
                        Text(availability.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section {
                Text(provider.blurb)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LabeledContent("Status") {
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    } else if provider.isImplemented {
                        Button("Use this provider", action: makeActive)
                    } else {
                        Text("Coming soon").foregroundStyle(.secondary)
                    }
                }
            }

            Section("Access") {
                switch provider.access {
                case .speechRecognition:
                    PermissionRow(
                        title: "Microphone",
                        granted: permissions.mic == .authorized,
                        detail: "Needed to capture your voice.",
                        action: permissions.requestMic
                    )
                    PermissionRow(
                        title: "Speech Recognition",
                        granted: permissions.speech == .authorized,
                        detail: speechDetail,
                        action: permissions.requestSpeech
                    )
                case .apiKey:
                    PermissionRow(
                        title: "Microphone",
                        granted: permissions.mic == .authorized,
                        detail: "Needed to capture your voice.",
                        action: permissions.requestMic
                    )
                    APIKeyField(state: state, provider: provider)
                }
            }

            let models = catalog.models(for: provider)
            if !models.isEmpty {
                Section("Model") {
                    Picker("Model", selection: modelBinding) {
                        ForEach(models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    Text("Models are kept up to date from VTT's catalog.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Your languages") {
                ForEach(state.selectorLanguages, id: \.self) { code in
                    LangSupportRow(state: state, code: code, provider: provider)
                }
            }

            if provider == .appleSpeechAnalyzer {
                AnalyzerModelSection(state: state, codes: state.selectorLanguages)
            }

            Section("Supported languages") {
                Text(state.supportedLanguages(by: provider).map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    /// Picker binding for the provider's model: reads the effective model,
    /// stores the user's pick.
    private var modelBinding: Binding<String> {
        Binding(
            get: { state.model(for: provider) },
            set: { state.selectedModels[provider.rawValue] = $0 }
        )
    }

    private var speechDetail: String {
        switch permissions.speech {
        case .authorized: "Granted."
        case .denied, .restricted: "Denied — open System Settings to allow."
        default: "On-device; forced when supported, so no audio leaves your Mac."
        }
    }
}

/// Shared settings that aren't provider-specific.
private struct GeneralTab: View {
    @ObservedObject var state: AppState
    @ObservedObject var permissions: Permissions

    var body: some View {
        Form {
            Section("Speech") {
                Picker("Provider", selection: $state.source) {
                    ForEach(SpeechSource.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section("Language") {
                Picker("Language", selection: $state.activeLanguage) {
                    Text("Default language (current keyboard language)").tag(Languages.auto)
                    ForEach(state.selectorLanguages, id: \.self) { code in
                        Text(Languages.named(code).name).tag(code)
                    }
                }
                Text("From your keyboard input sources (System Settings › Keyboard).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Provider per language") {
                ForEach(state.selectorLanguages, id: \.self) { code in
                    Picker(Languages.named(code).name, selection: providerBinding(code)) {
                        Text("Default (\(state.defaultProvider(for: code).shortName))").tag(SpeechSource?.none)
                        ForEach(SpeechSource.allCases) { provider in
                            let ok = state.isSupported(code, by: provider)
                            Text(ok ? provider.shortName : "\(provider.shortName) (not supported)")
                                .tag(SpeechSource?.some(provider))
                                .disabled(!ok)
                        }
                    }
                }
                Text("Each language defaults to the best on-device Apple engine — the newer Speech when its model is installed, otherwise the legacy one. Override any language here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey") {
                HotkeyRow(title: "Toggle dictation", chord: $state.primaryHotkey)
                HotkeyRow(title: "Alternative", chord: $state.alternativeHotkey)
                HStack {
                    Text("Include ⌘⌥⌃⇧ modifiers. Esc cancels recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset to defaults", action: state.resetHotkeys)
                }
            }

            Section("Floating bar") {
                Toggle("Show live transcript in the bar", isOn: $state.showLiveText)
                Text("Only for providers that stream while you speak (on-device). Cloud providers show the result after you stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("While dictating") {
                Toggle("Mute system audio", isOn: $state.muteWhileRecording)
                Text("Silences playback while you record, then restores it when you stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auto-insert") {
                Toggle("Paste transcript into the focused app", isOn: $state.autoInsert)

                PermissionRow(
                    title: "Accessibility",
                    granted: permissions.accessibilityTrusted,
                    detail: "Required to paste into other apps.",
                    action: permissions.requestAccessibility
                )
                .disabled(!state.autoInsert)
            }

            Section("Cloud spend (estimated)") {
                LabeledContent("Today") {
                    Text(money(state.cloudCostToday)).foregroundStyle(.secondary)
                }
                LabeledContent("This month") {
                    Text(money(state.cloudCostThisMonth)).foregroundStyle(.secondary)
                }

                SpendChart(data: state.recentDailyCloudCost(days: 30))

                ForEach(SpeechSource.allCases.filter { $0.category == .network }) { provider in
                    LabeledContent(provider.shortName) {
                        Text(money(state.estimatedCost(for: provider)))
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Total flushed") {
                    Text(money(state.totalCloudCost)).bold()
                }
                HStack {
                    Text("Rough estimate from public usage rates. Check each provider's dashboard for real billing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset", action: state.resetUsage)
                }
            }

            Section {
                LabeledContent("Version", value: "0.1.0")
            }
        }
        .formStyle(.grouped)
    }

    private func money(_ value: Double) -> String { String(format: "$%.4f", value) }

    /// Binding for a language's provider override: `nil` means "use the default".
    private func providerBinding(_ code: String) -> Binding<SpeechSource?> {
        let key = Languages.named(code).code
        return Binding(
            get: { state.languageProviders[key] },
            set: { newValue in
                if let newValue {
                    // Never commit a provider that can't handle this language.
                    guard state.isSupported(code, by: newValue) else { return }
                    state.languageProviders[key] = newValue
                } else {
                    state.languageProviders.removeValue(forKey: key)
                }
            }
        )
    }
}

/// A compact bar chart of estimated daily cloud spend.
private struct SpendChart: View {
    let data: [DailySpend]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if data.allSatisfy({ $0.cost <= 0 }) {
                Text("No cloud spend in the last 30 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                Chart(data) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Spend", day.cost)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                .frame(height: 70)
                Text("Daily spend · last 30 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The subscription tab: the paywall for free users, the status and management
/// for subscribers. Copy is scoped to the dictation plan and transparent about
/// the modular roadmap so it reads honestly once other plans exist.
private struct ProTab: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: SubscriptionStore

    var body: some View {
        Form {
            if store.isPro {
                Section {
                    Label("\(SubscriptionStore.planName) is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("No daily limit on speech-to-text, on every engine. Thanks for supporting VTT.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Manage subscription", action: openManageSubscriptions)
                    Button("Restore purchases") { Task { await store.restore() } }
                        .disabled(store.working)
                }
                RoadmapNote()
            } else {
                Section(SubscriptionStore.planName) {
                    Text("Dictate without limits")
                        .font(.title3).bold()
                    Text("This plan unlocks **speech-to-text** — it removes the daily free limit so you can dictate as much as you like, on every engine.")
                        .foregroundStyle(.secondary)
                }

                Section("Today's free usage") {
                    DailyUsageBar(state: state)
                    Text("Out of dictation for today? When you trigger dictation you can beg for one more — \(state.begsRemaining) of \(AppState.begsPerDay) left today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Subscribe — \(store.displayPrice)/month")
                            if store.working { ProgressView().controlSize(.small) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.working || store.monthly == nil)

                    Button("Restore purchases") { Task { await store.restore() } }
                        .disabled(store.working)

                    if store.monthly == nil {
                        Text("Subscriptions are unavailable right now. Make sure you're signed in to the App Store and try again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = store.lastError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                RoadmapNote()

                Section {
                    Text("Auto-renewing subscription billed through your Apple ID. Cancel anytime in System Settings › Apple ID › Subscriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await store.refresh() }
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Progress bar of today's free-tier usage as a percentage — deliberately
/// metric-free (no minutes/length/word counts), so users can track how much is
/// left without exposing how the limit is measured.
private struct DailyUsageBar: View {
    @ObservedObject var state: AppState

    private var fraction: Double {
        guard AppState.freeSecondsPerDay > 0 else { return 0 }
        return min(1, state.secondsUsedToday / AppState.freeSecondsPerDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: fraction)
                .tint(fraction >= 1 ? .red : .accentColor)
            Text("\(Int((fraction * 100).rounded()))% used today")
                .font(.caption)
                .foregroundStyle(fraction >= 1 ? .red : .secondary)
        }
    }
}

/// Transparency note explaining VTT's modular plans, so this dictation
/// subscription reads honestly once other paid modules exist.
private struct RoadmapNote: View {
    var body: some View {
        Section("How VTT pricing works") {
            Label {
                Text("You pay only for what you use. This plan covers **dictation** (speech-to-text) — that's its whole scope, today and always.")
            } icon: {
                Image(systemName: "mic.fill")
            }
            Label {
                Text("Bigger features we're building, like **transcription pipelines**, will be separate add-ons with their own price. Subscribing here never bundles or pre-charges for them.")
            } icon: {
                Image(systemName: "square.stack.3d.up")
            }
            Label {
                Text("New modules won't change or take anything away from this plan. What you buy is what you keep.")
            } icon: {
                Image(systemName: "lock.shield")
            }
        }
        .font(.callout)
    }
}

/// A hotkey row: an enable switch plus a click-to-record control. While
/// recording, the next non-modifier key press (with its modifiers) becomes the
/// chord; Esc cancels.
private struct HotkeyRow: View {
    let title: String
    @Binding var chord: HotkeyChord
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Button(action: toggle) {
                    Text(recording ? "Press keys…" : chord.display)
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .tint(recording ? .accentColor : nil)
                .disabled(!chord.enabled && !recording)

                Toggle("", isOn: $chord.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Esc with no modifiers cancels recording.
            if event.keyCode == UInt16(kVK_Escape),
               flags.subtracting(.function).isEmpty {
                stop()
                return nil
            }
            chord = HotkeyChord(
                keyCode: UInt32(event.keyCode),
                modifiers: HotkeyChord.carbonModifiers(from: flags),
                enabled: chord.enabled
            )
            stop()
            return nil // swallow the event so it doesn't reach the app
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Sidebar icon for a provider: the official logo from the app bundle if one
/// was dropped in, otherwise the tinted SF Symbol fallback.
private struct ProviderIcon: View {
    let provider: SpeechSource

    var body: some View {
        if let asset = provider.logoAsset,
           let url = Bundle.main.url(forResource: asset, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            // The bundled brand marks are monochrome glyphs; render them as
            // template images in the default label color so they stay visible
            // in both light and dark mode.
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: provider.symbol)
        }
    }
}

/// A row showing whether a selector language is supported by a provider.
private struct LangSupportRow: View {
    @ObservedObject var state: AppState
    let code: String
    let provider: SpeechSource

    var body: some View {
        let supported = state.isSupported(code, by: provider)
        LabeledContent(Languages.named(code).name) {
            // SpeechAnalyzer distinguishes a supported-but-not-yet-downloaded
            // model from an unsupported language; other providers only have
            // supported / not supported.
            if provider == .appleSpeechAnalyzer, supported {
                let installed = state.isModelInstalled(code)
                Label(installed ? "Downloaded" : "Not downloaded",
                      systemImage: installed ? "checkmark.circle.fill" : "arrow.down.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(installed ? .green : .secondary)
            } else {
                Label(supported ? "Supported" : "Not supported",
                      systemImage: supported ? "checkmark.circle.fill" : "xmark.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(supported ? .green : .secondary)
            }
        }
    }
}

/// Lists each of the user's languages with its on-device model status and a
/// download button, so models can be pre-fetched instead of installing on
/// first dictation. Backed by `AppState`, the single source of truth for
/// SpeechAnalyzer support/install state.
private struct AnalyzerModelSection: View {
    @ObservedObject var state: AppState
    let codes: [String]

    var body: some View {
        Section("On-device models") {
            Text("Download a language's model so dictation starts instantly. Otherwise it installs the first time you use that language.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if #available(macOS 26, *) {
                ForEach(codes, id: \.self) { code in
                    ModelRow(state: state, code: code)
                }
            } else {
                Text("Downloadable speech models require macOS 26 or later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: codes) { await state.refreshAnalyzerModels() }
    }
}

/// A single language's model status + download control.
private struct ModelRow: View {
    @ObservedObject var state: AppState
    let code: String

    var body: some View {
        LabeledContent(Languages.named(code).name) {
            if !state.isSupported(code, by: .appleSpeechAnalyzer) {
                Text("Not supported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let fraction = state.analyzerDownloading[code] {
                HStack(spacing: 8) {
                    ProgressView(value: fraction).frame(width: 80)
                    Text("\(Int(fraction * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else if state.isModelInstalled(code) {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Download") {
                    Task { await state.downloadAnalyzerModel(code: code) }
                }
                .controlSize(.small)
            }
        }
    }
}

/// Secure entry for a cloud provider's API key, persisted in the Keychain.
private struct APIKeyField: View {
    @ObservedObject var state: AppState
    let provider: SpeechSource
    @State private var key = ""

    var body: some View {
        SecureField("API key", text: $key)

        HStack {
            Text(state.apiKey(for: provider).isEmpty ? "No key saved." : "Key saved.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save") { state.setAPIKey(key, for: provider) }
                .disabled(key == state.apiKey(for: provider))
        }
        .task(id: provider) { key = state.apiKey(for: provider) }
    }
}

/// A labeled status row: green check when granted, an Enable button otherwise.
private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let detail: String
    let action: () -> Void

    var body: some View {
        LabeledContent(title) {
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Enable…", action: action)
            }
        }
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
