import SwiftUI

/// The visible pill. Compact and quiet when idle; expands into a live waveform
/// (and optional transcript) while recording, mirroring WisprFlow's floating bar.
struct FloatingBarView: View {
    @ObservedObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        pill
            // Transparent margin around the pill gives the soft shadow room to
            // render; the panel is sized to match so nothing gets clipped.
            .padding(20)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85),
                value: state.mode
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85),
                value: state.preparing
            )
            // Fill the hosting view and center, so the pill sits dead-center
            // regardless of its intrinsic width.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The glyph + waveform are visual; speak state transitions instead.
            .onChange(of: state.mode) { _, mode in
                AccessibilityNotification.Announcement(announcement(for: mode)).post()
            }
    }

    private var pill: some View {
        HStack(spacing: 7) {
            statusGlyph
            content
            if !state.displayLanguage.isEmpty {
                Text(state.displayLanguage.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 26)
        .background(Capsule().fill(Color.black))
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 7, y: 2)
        .onTapGesture { state.toggle() }
        // One element for assistive tech: the waveform/glyph are decoration,
        // the whole pill is the start/stop control.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Dictation")
        .accessibilityValue(statusDescription)
        .accessibilityHint(
            state.mode == .recording
                ? "Stops recording and inserts the transcript"
                : "Starts dictation"
        )
        .accessibilityAction { state.toggle() }
    }

    /// Spoken state for VoiceOver — covers what the glyph, waveform, and
    /// language tag convey visually.
    private var statusDescription: String {
        var parts: [String] = []
        if state.preparing {
            parts.append("Preparing")
        } else {
            switch state.mode {
            case .idle: parts.append("Idle")
            case .recording: parts.append("Recording")
            case .transcribing: parts.append("Transcribing")
            }
        }
        if let liveText { parts.append(liveText) }
        if !state.displayLanguage.isEmpty {
            parts.append("Language \(state.displayLanguage.uppercased())")
        }
        return parts.joined(separator: ", ")
    }

    private func announcement(for mode: AppState.Mode) -> String {
        switch mode {
        case .idle: "Dictation stopped"
        case .recording: "Recording"
        case .transcribing: "Transcribing"
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusGlyph: some View {
        Image(systemName: glyphName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(glyphTint)
    }

    @ViewBuilder
    private var content: some View {
        if state.preparing {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
                    .frame(width: 14)
                    .tint(.white)
                Text("Preparing…")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.95))
            }
        } else {
            modeContent
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch state.mode {
        case .idle, .recording:
            HStack(spacing: 7) {
                Waveform(
                    level: state.mode == .recording ? state.level : 0,
                    animated: !reduceMotion
                )
                .frame(width: 64)
                if let liveText {
                    Text(liveText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 240, alignment: .trailing)
                }
            }
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
                .frame(width: 16)
                .tint(.white)
        }
    }

    /// The interim transcript to show in the bar, or nil when it shouldn't show
    /// (toggle off, provider doesn't stream, or nothing transcribed yet).
    private var liveText: String? {
        guard state.mode == .recording,
              state.showLiveText,
              state.displayProvider.streamsPartials
        else { return nil }
        let text = state.partialText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var glyphName: String {
        if state.preparing { return "hourglass" }
        switch state.mode {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .transcribing: return "waveform"
        }
    }

    private var glyphTint: Color {
        if state.preparing { return .orange }
        switch state.mode {
        case .idle: return .white
        case .recording: return .red
        case .transcribing: return .blue
        }
    }
}

/// Bars whose height tracks the live mic `level` (0...1), with a gentle sine
/// shimmer for motion so silence still looks alive. With Reduce Motion on the
/// shimmer is frozen — bars still rise with the mic level, so recording
/// feedback survives, but nothing moves on its own.
private struct Waveform: View {
    let level: Float
    var animated = true
    private let barCount = 11

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                bars(t: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(t: 0)
        }
    }

    private func bars(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let barWidth = (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.9))
                        .frame(width: barWidth, height: height(i, t, geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(_ index: Int, _ t: TimeInterval, _ maxHeight: CGFloat) -> CGFloat {
        let phase = Double(index) * 0.55
        let shimmer = (sin(t * 7 + phase) * 0.5 + 0.5) * 0.5
            + (sin(t * 3.3 + phase * 1.7) * 0.5 + 0.5) * 0.5
        // Idle: a low ~12% baseline. Louder mic level lifts and emphasizes the
        // shimmer so the bars visibly react to speech.
        let lvl = Double(level)
        let amplitude = 0.12 + lvl * (0.25 + 0.6 * shimmer)
        return max(2, maxHeight * CGFloat(min(1, amplitude)))
    }
}
