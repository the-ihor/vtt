import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// First-run welcome flow: explains the app, walks through the three system
/// permissions, offers launch-at-login, then hands off to Settings. Shown once
/// (see `AppDelegate.showOnboardingIfNeeded`); every step is skippable —
/// permissions can always be granted later from Settings.
struct OnboardingView: View {
    @ObservedObject var permissions: Permissions
    @ObservedObject var state: AppState
    /// Called when the user finishes (or skips past) the flow.
    let finish: () -> Void

    @State private var step: Int

    /// `initialStep` lets repeat showings (missing permissions on a later
    /// launch) jump straight to the permissions page instead of the welcome.
    init(
        permissions: Permissions,
        state: AppState,
        initialStep: Int = 0,
        finish: @escaping () -> Void
    ) {
        self.permissions = permissions
        self.state = state
        self.finish = finish
        _step = State(initialValue: initialStep)
    }
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    /// TCC grants flip in System Settings without telling us — poll while the
    /// window is up so the checkmarks go green the moment the user returns.
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let stepCount = 5

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 44)
                .padding(.top, 36)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(.bar)
        }
        .frame(width: 540, height: 600)
        .onReceive(poll) { _ in permissions.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: permissionsStep
        case 2: hotkeyStep
        case 3: startupStep
        default: doneStep
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            LogoMark()
                .frame(width: 84, height: 84)
            Text("Welcome to VTT")
                .font(.system(size: 30, weight: .bold))
            Text("You talk. It types — right where your cursor is, in any app.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 6) {
                Label("On-device and private by default", systemImage: "lock.shield")
                Label("Press \(state.primaryHotkey.display) to start or stop dictating", systemImage: "keyboard")
                Label("Lives in your menu bar — no Dock icon", systemImage: "menubar.arrow.up.rectangle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .labelStyle(OnboardingChecklistLabelStyle())
            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                "Permissions",
                "VTT needs three system permissions to do its job. macOS will ask once for each — everything stays under your control in System Settings."
            )

            OnboardingPermissionRow(
                icon: "mic.fill",
                title: "Microphone",
                detail: "Captures your voice while you dictate.",
                granted: permissions.mic == .authorized,
                action: permissions.requestMic
            )
            OnboardingPermissionRow(
                icon: "waveform",
                title: "Speech Recognition",
                detail: "Lets Apple's on-device engines turn speech into text.",
                granted: permissions.speech == .authorized,
                action: permissions.requestSpeech
            )
            OnboardingPermissionRow(
                icon: "keyboard.badge.ellipsis",
                title: "Accessibility",
                detail: "Types the transcript right at your cursor. macOS opens System Settings — enable VTT there, then come back.",
                granted: permissions.accessibilityTrusted,
                action: permissions.requestAccessibility
            )

            Text("You can skip any of these — Settings has the same buttons.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var hotkeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                "Your dictation key",
                "One shortcut starts and stops dictation — anywhere on your Mac, in any app."
            )

            HStack(spacing: 16) {
                Spacer()
                OnboardingHotkeyRecorder(chord: $state.primaryHotkey)
                Spacer()
            }
            .padding(.vertical, 18)

            Divider()

            Toggle(isOn: $state.alternativeHotkey.enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alternative shortcut")
                    Text("A second way to trigger dictation — handy if the main one clashes in some app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if state.alternativeHotkey.enabled {
                HStack {
                    Spacer()
                    OnboardingHotkeyRecorder(chord: $state.alternativeHotkey, compact: true)
                    Spacer()
                }
            }

            Text("Press it once to start, again to stop. Everything stays changeable in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var startupStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                "Start with your Mac",
                "A dictation tool is most useful when it's always one keystroke away. VTT is tiny and idle until you call it."
            )

            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch VTT at login")
                    Text("Adds VTT to your login items. Change anytime in Settings or System Settings › General › Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
    }

    private var doneStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.system(size: 30, weight: .bold))
            Text("Put your cursor in any text field, press \(state.primaryHotkey.display), and speak.\nSettings opens next so you can pick engines and languages.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func stepHeader(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 24, weight: .bold))
            Text(sub).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<Self.stepCount, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of \(Self.stepCount)")
            Spacer()
            Button(step == Self.stepCount - 1 ? "Open Settings" : "Continue") {
                if step == Self.stepCount - 1 {
                    finish()
                } else {
                    step += 1
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Login item

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't update login items: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// The four brand waveform bars (logo-mark geometry on a 1024 grid).
private struct LogoMark: View {
    private static let bars: [(x: CGFloat, y: CGFloat, h: CGFloat)] = [
        (236, 392, 240), (388, 202, 620), (540, 320, 384), (692, 250, 524),
    ]

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 1024
            ForEach(0..<Self.bars.count, id: \.self) { i in
                let b = Self.bars[i]
                Capsule()
                    .fill(Color(red: 0.95, green: 0.23, blue: 0.11))
                    .frame(width: 96 * s, height: b.h * s)
                    .offset(x: b.x * s, y: b.y * s)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One permission: icon, explanation, and a live status / grant control.
private struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Grant…", action: action)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
        .accessibilityElement(children: .combine)
        .accessibilityValue(granted ? "Granted" : "Not granted")
    }
}

/// Big chord display + recorder: click, press the new combination, done.
/// Esc cancels. Same recording mechanics as Settings' HotkeyRow.
private struct OnboardingHotkeyRecorder: View {
    @Binding var chord: HotkeyChord
    var compact = false
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 10) {
            Text(recording ? "Press keys…" : chord.display)
                .font(.system(size: compact ? 20 : 34, weight: .bold))
                .monospaced()
                .frame(minWidth: compact ? 160 : 240)
                .padding(.vertical, compact ? 10 : 18)
                .padding(.horizontal, compact ? 18 : 28)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.quaternary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            recording ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
            Button(recording ? "Cancel (Esc)" : "Change…") {
                recording ? stop() : start()
            }
            .accessibilityLabel("Change dictation shortcut")
            .accessibilityValue(recording ? "Recording, press keys now" : chord.display)
        }
        .accessibilityElement(children: .contain)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == UInt16(kVK_Escape), flags.subtracting(.function).isEmpty {
                stop()
                return nil
            }
            chord = HotkeyChord(
                keyCode: UInt32(event.keyCode),
                modifiers: HotkeyChord.carbonModifiers(from: flags),
                enabled: chord.enabled
            )
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Checklist label: fixed-width icon column so the texts align.
private struct OnboardingChecklistLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .frame(width: 22)
                .foregroundStyle(Color.accentColor)
            configuration.title
        }
    }
}
