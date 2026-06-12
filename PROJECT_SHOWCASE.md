# VTT — Voice-to-Text for macOS
### Speak. It types. Anywhere on your Mac.

---

## 🎤 The Pitch

**VTT turns your voice into text in any app — instantly.**

A tiny floating bar sits at the bottom of your screen. Hit a hotkey, talk, and your
words appear right where your cursor is — in Slack, in your code editor, in an email,
anywhere. No window switching. No copy-paste. No friction.

It's the dictation experience macOS should have shipped with.

---

## ✨ What It Does

> A polished, native macOS menu-bar app for instant voice dictation —
> **privacy-first on-device** *or* **best-in-class cloud accuracy**, your choice.

### 🪶 The Floating Bar
- A WisprFlow-style "pill" that floats on top of everything — across Spaces and full-screen apps
- **Never steals focus** — keep typing while it listens
- Live animated waveform that dances to your voice
- Real-time transcript preview as you speak
- States at a glance: *idle → recording → transcribing*

### 🧠 Five Transcription Engines
| Engine | Type | Highlight |
|---|---|---|
| **Apple On-Device** | 🔒 Private | Nothing leaves your Mac |
| **Apple SpeechAnalyzer** | 🔒 Private | Next-gen on-device, downloadable models |
| **Deepgram Nova-3** | ☁️ Cloud | Live streaming, instant results |
| **ElevenLabs Scribe** | ☁️ Cloud | Top-tier accuracy |
| **OpenAI gpt-4o-transcribe** | ☁️ Cloud | State-of-the-art model |

### 🌍 Speaks Your Language — All 26 of Them
English · Spanish · French · German · Italian · Portuguese · Dutch · Russian ·
Ukrainian · Polish · Turkish · Swedish · Danish · Norwegian · Finnish · Czech ·
Romanian · Greek · Arabic · Hebrew · Hindi · Chinese · Japanese · Korean ·
Indonesian · Vietnamese

- **Auto-detects** your active keyboard language
- **Per-language routing** — keep English on-device, send Russian to the cloud. Your rules.

### ⚡ Built for Flow
- Global hotkeys (plus a backup hotkey, and Esc to cancel mid-sentence)
- Auto-insert into *any* app via the Accessibility API
- Optional system-audio muting while you record
- **Dictation history** — your last 50 transcripts, one click to copy or re-paste

### 💳 Fair, Modular Monetization
- **15 free minutes every day** — no account required
- A few "one more" bonus recordings when you hit the cap
- **VTT Pro — $9.99/mo** removes the limit (App Store, StoreKit 2)
- **Tamper-resistant by design**: hardware-bound HMAC-SHA256 usage vault with clock-rollback protection

### 📊 Cloud Spend, Fully Transparent
- Per-provider usage tracking with estimated USD cost
- Daily breakdowns + a 30-day spend trend chart
- Know exactly what your dictation costs — before the bill arrives

---

## 🛠️ Under the Hood

**100% native. Zero external Swift dependencies.**

```
Swift 6  ·  SwiftUI + AppKit  ·  macOS 14+  ·  Intel & Apple Silicon
```

| Layer | Technology |
|---|---|
| **Audio** | AVFoundation — 16 kHz mono PCM capture |
| **Speech** | Apple Speech & SpeechAnalyzer frameworks |
| **Payments** | StoreKit 2 |
| **Auto-insert** | Accessibility / ApplicationServices |
| **Hotkeys** | Carbon global hotkey API |
| **Security** | CryptoKit (HMAC) + Keychain + IOKit (hardware ID) |
| **Charts** | Swift Charts |
| **Cloud** | Deepgram (WebSocket), ElevenLabs, OpenAI |
| **Build** | Swift Package Manager |

**Plus a full go-to-market kit:** marketing landing page, 7 blog articles, legal pages,
SEO, and a code-driven hero video built in Remotion (React/TypeScript).

---

## 📐 By the Numbers

| | |
|---|---|
| **Swift source** | ~4,200 lines across 23 files |
| **Transcription engines** | 5 |
| **Languages** | 26 |
| **Marketing pages & articles** | 49 files |
| **External Swift dependencies** | 0 |

---

## 🗓️ Timeline

> **An intensive 2-day build sprint.**

- **Day 1 — June 6, 2026:** Core app, transcription pipeline & subscription system
- **Day 2 — June 7, 2026:** Feature completion, landing page & marketing video
- **24 commits** · start-to-shippable in roughly two days

---

## 🎯 The Takeaway

VTT is a **production-ready showcase of deep macOS platform craft** —
non-activating panels, Carbon hotkeys, the Accessibility API, hardware-bound
secure storage, StoreKit 2, and Swift 6 strict concurrency — all wrapped in a
clean, focused product with privacy options, a fair free tier, and a complete
marketing presence.

**Speak. It types. Anywhere.**
