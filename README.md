# VTT

A native macOS menu-bar app with a WisprFlow-style floating dictation bar.

A borderless pill floats at the bottom-center of the screen, always on top and
across all Spaces. It stays out of the way when idle and expands into an
animated waveform while recording — and it **never steals keyboard focus**, so
transcribed text can later be inserted into whatever app you're typing in.

> Status: scaffold. The floating bar, hotkey, menu-bar item, and recording
> state machine work. Actual audio capture + transcription are stubbed
> (`AppState.startRecording` / `stopRecording`).

## Run

```bash
# Quick iteration (raw binary, no bundle):
swift run

# Proper .app bundle (needed for mic/accessibility permissions):
./scripts/make-app.sh
open build/VTT.app

# Build, sign, strip the Gatekeeper quarantine flag, install to /Applications, launch:
./scripts/install.sh
```

`install.sh` honours a few env vars: `CONFIG=debug`, `DEST=~/Applications`,
`SIGN_ID="Developer ID Application: …"` (defaults to ad-hoc), and `NO_LAUNCH=1`.

## Controls

- **⌃⌥Space** (Control–Option–Space) — toggle dictation
- **Menu-bar waveform icon** — toggle dictation, show/hide the bar, quit
- **Click the pill** — toggle dictation

## Layout

| File | Role |
|------|------|
| `main.swift` | Bootstraps `NSApplication` as an accessory (no Dock icon) |
| `AppDelegate.swift` | Wires up the panel, menu-bar item, hotkey, screen tracking |
| `FloatingPanel.swift` | Non-activating, always-on-top borderless `NSPanel` |
| `FloatingBarView.swift` | SwiftUI pill: idle / recording waveform / transcribing |
| `AppState.swift` | Recording lifecycle (`idle → recording → transcribing`) |
| `HotKey.swift` | Global Carbon hotkey |

## Next steps

1. Capture audio with `AVAudioEngine` in `AppState.startRecording()`.
2. Transcribe (on-device `SpeechAnalyzer`/`SFSpeechRecognizer`, or a cloud API).
3. Insert the result into the focused app via the Accessibility API or paste.
4. Feed live mic levels into `Waveform` instead of the synthetic sine motion.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE.md):
use, modify, and contribute freely for noncommercial purposes. You may not use
it commercially or ship a competing product without a separate commercial
license from the author (mgorunuch.igor@gmail.com).
