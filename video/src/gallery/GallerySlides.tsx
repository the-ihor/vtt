import { AbsoluteFill, Img, staticFile } from "remotion";
import { C, fontFamily } from "../theme";

// Product Hunt gallery slides — 2540×1520 stills (2× PH's 1270×760).
// Same brand system as the landing: paper, ink, accent red, Space Grotesk.

const PAGE = { width: 2540, height: 1520 } as const;

/* ---------- shared pieces ---------- */

const Mark: React.FC<{ size?: number }> = ({ size = 56 }) => {
  const s = size / 1024;
  const bars = [
    { x: 236, y: 392, h: 240 },
    { x: 388, y: 202, h: 620 },
    { x: 540, y: 320, h: 384 },
    { x: 692, y: 250, h: 524 },
  ];
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      {bars.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: b.x * s,
            top: b.y * s,
            width: 96 * s,
            height: b.h * s,
            borderRadius: 48 * s,
            background: C.accent,
          }}
        />
      ))}
    </div>
  );
};

const Slide: React.FC<{
  kicker?: string;
  title: React.ReactNode;
  sub?: React.ReactNode;
  children?: React.ReactNode;
  center?: boolean;
}> = ({ kicker, title, sub, children, center }) => (
  <AbsoluteFill
    style={{
      background: C.paper,
      fontFamily,
      color: C.ink,
      padding: "110px 140px 90px",
      flexDirection: "column",
    }}
  >
    {/* corner brand */}
    <div style={{ position: "absolute", top: 70, right: 90, display: "flex", alignItems: "center", gap: 18, opacity: 0.85 }}>
      <Mark size={46} />
      <span style={{ fontWeight: 700, fontSize: 40, letterSpacing: "-0.04em" }}>VTT</span>
    </div>

    {kicker ? (
      <div style={{ fontSize: 30, fontWeight: 600, letterSpacing: "0.16em", textTransform: "uppercase", color: C.accent, marginBottom: 26 }}>
        {kicker}
      </div>
    ) : null}
    <div style={{ fontSize: 124, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 1.02, maxWidth: 1900 }}>{title}</div>
    {sub ? (
      <div style={{ fontSize: 46, fontWeight: 500, color: C.muted, marginTop: 34, lineHeight: 1.35, maxWidth: 1800 }}>{sub}</div>
    ) : null}

    <div
      style={{
        flex: 1,
        display: "flex",
        alignItems: "center",
        justifyContent: center ? "center" : "flex-start",
        flexDirection: "column",
        marginTop: 40,
      }}
    >
      {children}
    </div>

    <div style={{ position: "absolute", bottom: 56, left: 140, fontSize: 28, fontWeight: 500, letterSpacing: "0.1em", textTransform: "uppercase", color: C.faint }}>
      vtt.the-ihor.com
    </div>
    <div style={{ position: "absolute", bottom: 56, right: 140, fontSize: 28, fontWeight: 500, letterSpacing: "0.1em", textTransform: "uppercase", color: C.faint }}>
      free · macOS
    </div>
  </AbsoluteFill>
);

/** Static recreation of the floating dictation bar (mirrors ui/DictationBar). */
const Bar: React.FC<{ text: string; lang?: string; width?: number; caret?: boolean }> = ({
  text,
  lang = "EN",
  width = 1560,
  caret = true,
}) => {
  const heights = [10, 22, 30, 18, 26, 34, 14, 24, 32, 20, 28, 12, 26, 18, 30, 16];
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 34,
        width,
        height: 168,
        padding: "0 52px",
        borderRadius: 84,
        background: "#0d0d0f",
        boxShadow: "0 52px 110px -45px rgba(19,18,16,.6)",
        fontFamily,
      }}
    >
      <span style={{ width: 38, height: 38, borderRadius: 10, background: C.accent, flexShrink: 0 }} />
      <div style={{ display: "flex", alignItems: "center", gap: 7, height: 44 }}>
        {heights.map((h, i) => (
          <div key={i} style={{ width: 5, height: h + 8, background: "rgba(255,255,255,.55)", borderRadius: 3 }} />
        ))}
      </div>
      <div style={{ flex: 1, textAlign: "right", color: "#fff", fontSize: 52, fontWeight: 500, letterSpacing: "-0.01em", whiteSpace: "nowrap", overflow: "hidden" }}>
        {text}
        {caret ? <span style={{ opacity: 0.7 }}>|</span> : null}
      </div>
      <span style={{ fontSize: 38, fontWeight: 600, color: "rgba(255,255,255,.55)", flexShrink: 0 }}>{lang}</span>
    </div>
  );
};

/** Framed app screenshot with optional callout pills along a side. */
const Shot: React.FC<{ src: string; width: number }> = ({ src, width }) => (
  <div
    style={{
      width,
      borderRadius: 28,
      overflow: "hidden",
      boxShadow: "0 60px 120px -50px rgba(19,18,16,.55), 0 0 0 1px rgba(19,18,16,.08)",
      lineHeight: 0,
      background: "#fff",
    }}
  >
    <Img src={staticFile(src)} style={{ width: "100%" }} />
  </div>
);

const Callout: React.FC<{ label: string; side?: "left" | "right" }> = ({ label, side = "right" }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 0, flexDirection: side === "right" ? "row" : "row-reverse" }}>
    <div style={{ width: 14, height: 14, borderRadius: 7, background: C.accent }} />
    <div style={{ width: 56, height: 3, background: C.accent }} />
    <div
      style={{
        background: "#fff",
        border: `3px solid ${C.accent}`,
        color: C.ink,
        borderRadius: 999,
        padding: "16px 34px",
        fontSize: 36,
        fontWeight: 600,
        whiteSpace: "nowrap",
        boxShadow: "0 20px 40px -24px rgba(19,18,16,.4)",
      }}
    >
      {label}
    </div>
  </div>
);

const Chip: React.FC<{ children: React.ReactNode; strong?: boolean }> = ({ children, strong }) => (
  <div
    style={{
      padding: "18px 38px",
      borderRadius: 999,
      fontSize: 38,
      fontWeight: 600,
      background: strong ? C.ink : "#fff",
      color: strong ? "#fff" : C.ink,
      boxShadow: "0 0 0 1px rgba(19,18,16,.1)",
    }}
  >
    {children}
  </div>
);

/* ---------- slide 1 — cover ---------- */

export const Gallery01: React.FC = () => (
  <AbsoluteFill style={{ background: C.paper, fontFamily, color: C.ink, alignItems: "center", justifyContent: "center", flexDirection: "column" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
      <Mark size={170} />
      <div style={{ fontWeight: 700, fontSize: 220, letterSpacing: "-0.05em", lineHeight: 1 }}>VTT</div>
    </div>
    <div style={{ fontSize: 76, fontWeight: 700, letterSpacing: "-0.03em", marginTop: 46, textAlign: "center" }}>
      Voice-to-text for macOS with a <span style={{ color: C.accent }}>fully on-device</span> option
    </div>
    <div style={{ marginTop: 90 }}>
      <Bar text="Hello, guys. Happy to see you." />
    </div>
    <div style={{ display: "flex", gap: 26, marginTop: 96 }}>
      <Chip strong>On-device option</Chip>
      <Chip>26 languages</Chip>
      <Chip>Any app, at your cursor</Chip>
      <Chip>Free · no account</Chip>
      <Chip>Open source</Chip>
    </div>
  </AbsoluteFill>
);

/* ---------- slide 2 — you talk, it types ---------- */

const EditorMock: React.FC = () => (
  <div
    style={{
      width: 1680,
      borderRadius: 28,
      background: "#fff",
      boxShadow: "0 60px 120px -50px rgba(19,18,16,.45), 0 0 0 1px rgba(19,18,16,.08)",
      padding: "0 0 60px",
      fontFamily,
    }}
  >
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "26px 34px", borderBottom: "1px solid rgba(19,18,16,.08)" }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <span key={c} style={{ width: 20, height: 20, borderRadius: 10, background: c }} />
      ))}
      <span style={{ marginLeft: 18, fontSize: 30, fontWeight: 600, color: C.muted }}>Slack — #team-standup</span>
    </div>
    <div style={{ padding: "50px 70px 0" }}>
      {[520, 1240, 980].map((w, i) => (
        <div key={i} style={{ width: w, height: 26, borderRadius: 13, background: "rgba(19,18,16,.08)", marginBottom: 30 }} />
      ))}
      <div style={{ fontSize: 50, fontWeight: 500, lineHeight: 1.4, marginTop: 26 }}>
        Shipping the fix today —{" "}
        <span style={{ background: "rgba(242,58,29,.14)", borderRadius: 10, padding: "2px 8px" }}>
          tests are green, review is up.
        </span>
        <span style={{ display: "inline-block", width: 6, height: 54, background: C.accent, borderRadius: 3, marginLeft: 10, verticalAlign: "-8px" }} />
      </div>
    </div>
  </div>
);

export const Gallery02: React.FC = () => (
  <Slide
    kicker="The whole product in one motion"
    title={
      <>
        You talk. It types — <span style={{ color: C.accent }}>at your cursor</span>, in any app.
      </>
    }
    sub="Hit a hotkey, speak, done. No dictation window, no copy-paste, no switching apps."
  >
    <div style={{ position: "relative", marginTop: 10 }}>
      <EditorMock />
      <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: -120 }}>
        <Bar text="…tests are green, review is up." width={1380} />
      </div>
      <div style={{ position: "absolute", right: -110, top: 110 }}>
        <Callout label="text lands where your cursor is" side="left" />
      </div>
      <div style={{ position: "absolute", left: -270, bottom: -70 }}>
        <Callout label="never steals focus" side="right" />
      </div>
    </div>
  </Slide>
);

/* ---------- slide 3 — privacy ---------- */

export const Gallery03: React.FC = () => (
  <Slide
    kicker="Privacy"
    title={
      <>
        Audio can <span style={{ color: C.accent }}>stay on your Mac</span>. Entirely.
      </>
    }
    sub="Apple's on-device speech engines run locally — pick one and nothing is ever sent anywhere."
  >
    <div style={{ position: "relative", marginTop: 14 }}>
      <Shot src="gallery/feature-01.png" width={1180} />
      <div style={{ position: "absolute", left: -60, top: "42%", transform: "translate(-100%, -50%)" }}>
        <Callout label="on-device engines, built in" side="right" />
      </div>
      <div style={{ position: "absolute", right: -60, top: "56%", transform: "translate(100%, -50%)" }}>
        <Callout label="permissions, transparent" side="left" />
      </div>
    </div>
  </Slide>
);

/* ---------- slide 4 — engines / BYOK ---------- */

const ProviderCard: React.FC<{ logo?: string; name: string; tag: string; note: string; onDevice?: boolean }> = ({
  logo,
  name,
  tag,
  note,
  onDevice,
}) => (
  <div
    style={{
      width: 520,
      borderRadius: 32,
      background: onDevice ? C.ink : "#fff",
      color: onDevice ? "#fff" : C.ink,
      boxShadow: "0 40px 90px -45px rgba(19,18,16,.5), 0 0 0 1px rgba(19,18,16,.08)",
      padding: "54px 50px",
      display: "flex",
      flexDirection: "column",
      gap: 22,
      fontFamily,
    }}
  >
    <div style={{ height: 84, display: "flex", alignItems: "center" }}>
      {logo ? (
        <Img src={staticFile(logo)} style={{ height: 72, width: "auto", maxWidth: 380, objectFit: "contain" }} />
      ) : (
        <Mark size={84} />
      )}
    </div>
    <div style={{ fontSize: 52, fontWeight: 700, letterSpacing: "-0.03em" }}>{name}</div>
    <div
      style={{
        alignSelf: "flex-start",
        fontSize: 28,
        fontWeight: 700,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        color: onDevice ? C.ink : "#fff",
        background: onDevice ? "#fff" : C.accent,
        borderRadius: 999,
        padding: "10px 24px",
      }}
    >
      {tag}
    </div>
    <div style={{ fontSize: 34, fontWeight: 500, color: onDevice ? "rgba(255,255,255,.7)" : C.muted, lineHeight: 1.4 }}>{note}</div>
  </div>
);

export const Gallery04: React.FC = () => (
  <Slide
    kicker="Engines"
    title={
      <>
        Your engines. <span style={{ color: C.accent }}>Your key.</span>
      </>
    }
    sub="Cloud engines are bring-your-own-key — you pay the provider directly. Or skip the cloud entirely."
    center
  >
    <div style={{ display: "flex", gap: 44 }}>
      <ProviderCard name="Apple" tag="on-device" note="Runs locally. Audio never leaves your Mac." onDevice />
      <ProviderCard logo="gallery/deepgram.png" name="Deepgram" tag="cloud · your key" note="Live streaming, instant results." />
      <ProviderCard logo="gallery/openai.png" name="OpenAI" tag="cloud · your key" note="State-of-the-art transcription." />
      <ProviderCard logo="gallery/elevenlabs.png" name="ElevenLabs" tag="cloud · your key" note="Top-tier accuracy." />
    </div>
  </Slide>
);

/* ---------- slide 5 — per-language routing ---------- */

export const Gallery05: React.FC = () => (
  <Slide
    kicker="Routing"
    title={
      <>
        Every language gets <span style={{ color: C.accent }}>its own engine</span>
      </>
    }
    sub="Keep English on-device, send other languages to the engine that handles them best."
  >
    <div style={{ position: "relative", marginTop: 14 }}>
      <Shot src="gallery/feature-05.png" width={1180} />
      <div style={{ position: "absolute", right: -60, top: "62%", transform: "translate(100%, -50%)" }}>
        <Callout label="English → on-device" side="left" />
      </div>
      <div style={{ position: "absolute", right: -60, top: "72%", transform: "translate(100%, -50%)" }}>
        <Callout label="Russian → OpenAI" side="left" />
      </div>
      <div style={{ position: "absolute", right: -60, top: "82%", transform: "translate(100%, -50%)" }}>
        <Callout label="Ukrainian → Deepgram" side="left" />
      </div>
    </div>
  </Slide>
);

/* ---------- slide 6 — languages ---------- */

const LANGS = [
  "English", "Spanish", "French", "German", "Italian", "Portuguese", "Dutch", "Russian", "Ukrainian",
  "Polish", "Turkish", "Swedish", "Danish", "Norwegian", "Finnish", "Czech", "Romanian", "Greek",
  "Arabic", "Hebrew", "Hindi", "Chinese", "Japanese", "Korean", "Indonesian", "Vietnamese",
];

export const Gallery06: React.FC = () => (
  <Slide
    kicker="Languages"
    title={
      <>
        26 languages, <span style={{ color: C.accent }}>auto-detected</span>
      </>
    }
    sub="VTT follows your keyboard layout — switch input source and the right engine follows."
    center
  >
    <div style={{ display: "flex", flexWrap: "wrap", gap: 22, maxWidth: 2100, justifyContent: "center" }}>
      {LANGS.map((l) => (
        <Chip key={l} strong={l === "English" || l === "Russian" || l === "Ukrainian"}>
          {l}
        </Chip>
      ))}
    </div>
    <div style={{ marginTop: 80 }}>
      <Bar text="Привіт! Hello! Hola!" lang="UA" width={1200} caret={false} />
    </div>
  </Slide>
);

/* ---------- slide 7 — history ---------- */

export const Gallery07: React.FC = () => (
  <Slide
    kicker="History"
    title={
      <>
        Every dictation, <span style={{ color: C.accent }}>one click away</span>
      </>
    }
    sub={
      <>
        Your last 50 transcripts — copy or re-paste any of them. (Yes, half are in Russian. Multilingual is the point.)
      </>
    }
  >
    <div style={{ position: "relative", marginTop: 14 }}>
      <Shot src="gallery/feature-09.png" width={1180} />
      <div style={{ position: "absolute", right: -60, top: "38%", transform: "translate(100%, -50%)" }}>
        <Callout label="copy, re-paste, reuse" side="left" />
      </div>
    </div>
  </Slide>
);

/* ---------- slide 8 — closer ---------- */

export const Gallery08: React.FC = () => (
  <AbsoluteFill style={{ background: C.ink, fontFamily, color: C.paper, alignItems: "center", justifyContent: "center", flexDirection: "column" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
      <Mark size={150} />
      <div style={{ fontWeight: 700, fontSize: 190, letterSpacing: "-0.05em", lineHeight: 1, color: "#fff" }}>VTT</div>
    </div>
    <div style={{ fontSize: 70, fontWeight: 700, letterSpacing: "-0.03em", marginTop: 50, color: "#fff" }}>
      Stop typing. <span style={{ color: C.accent }}>Start talking.</span>
    </div>
    <div style={{ display: "flex", gap: 26, marginTop: 80 }}>
      {["Free at launch", "No account", "Native Mac app", "Open source"].map((t) => (
        <div
          key={t}
          style={{
            padding: "18px 38px",
            borderRadius: 999,
            fontSize: 38,
            fontWeight: 600,
            background: "rgba(255,255,255,.08)",
            color: "#fff",
            boxShadow: "0 0 0 1px rgba(255,255,255,.18)",
          }}
        >
          {t}
        </div>
      ))}
    </div>
    <div style={{ fontSize: 34, fontWeight: 500, letterSpacing: "0.12em", textTransform: "uppercase", color: "rgba(255,255,255,.55)", marginTop: 90 }}>
      vtt.the-ihor.com&nbsp;&nbsp;·&nbsp;&nbsp;github.com/the-ihor/vtt
    </div>
  </AbsoluteFill>
);

export const GALLERY = [Gallery01, Gallery02, Gallery03, Gallery04, Gallery05, Gallery06, Gallery07, Gallery08];
export const GALLERY_SIZE = PAGE;
