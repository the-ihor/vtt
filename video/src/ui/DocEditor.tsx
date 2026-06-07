import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../theme";
import { U, uiFont } from "./uiTheme";

const MiniWave: React.FC = () => {
  const frame = useCurrentFrame();
  const bars = Array.from({ length: 11 }, (_, i) => i);
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 4, height: 26 }}>
      {bars.map((i) => {
        const h = 5 + 16 * Math.abs(Math.sin(frame / 3.2 + i * 0.7));
        return <div key={i} style={{ width: 3.5, height: h, background: "rgba(255,255,255,.5)", borderRadius: 2 }} />;
      })}
    </div>
  );
};

/** The floating dictation bar, pinned to the window — makes it obvious the text
 *  is being SPOKEN, not typed. Shows the live tail of what's being dictated. */
const DictationOverlay: React.FC<{ tail: string; lang?: string }> = ({ tail, lang = "EN" }) => (
  <div
    style={{
      position: "absolute",
      left: "50%",
      bottom: -34,
      transform: "translateX(-50%)",
      display: "flex",
      alignItems: "center",
      gap: 18,
      width: 720,
      height: 90,
      padding: "0 30px",
      borderRadius: 46,
      background: "#0d0d0f",
      boxShadow: "0 30px 70px -30px rgba(19,18,16,.7)",
    }}
  >
    <span style={{ width: 22, height: 22, borderRadius: 6, background: C.accent, flexShrink: 0 }} />
    <MiniWave />
    <div style={{ flex: 1, textAlign: "right", color: "#fff", fontSize: 29, fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden" }}>
      {tail || "Listening…"}
    </div>
    <span style={{ fontSize: 24, fontWeight: 600, color: "rgba(255,255,255,.5)", flexShrink: 0 }}>{lang}</span>
  </div>
);

/** A TextEdit-like window with words streaming in — used for the FLOW / app beats. */
export const DocEditor: React.FC<{ title?: string; text: string; typeSpeed?: number; bar?: boolean; lang?: string }> = ({
  title = "Untitled — Edited",
  text,
  typeSpeed = 0.9,
  bar = false,
  lang = "EN",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 18, stiffness: 90, mass: 0.8 } });
  const scale = interpolate(enter, [0, 1], [0.96, 1]);
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });

  const shown = Math.max(0, Math.min(text.length, Math.floor((frame - 6) / typeSpeed)));
  const visible = text.slice(0, shown);
  const caret = Math.floor(frame / 8) % 2 === 0;

  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "center" }}>
      <div style={{ position: "relative", transform: `scale(${scale})`, opacity: op }}>
      <div
        style={{
          width: 1300,
          height: 820,
          borderRadius: 22,
          background: U.win,
          boxShadow: "0 60px 140px -50px rgba(19,18,16,.6)",
          overflow: "hidden",
          fontFamily: uiFont,
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ position: "relative", height: 64, borderBottom: "1px solid rgba(0,0,0,.08)", display: "flex", alignItems: "center" }}>
          <div style={{ display: "flex", gap: 11, paddingLeft: 22 }}>
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlRed }} />
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlYellow }} />
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlGreen }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, textAlign: "center", fontSize: 24, fontWeight: 600, color: U.sub }}>
            {title}
          </div>
        </div>
        <div style={{ flex: 1, padding: "44px 54px", fontSize: 42, lineHeight: 1.5, color: U.text, fontWeight: 400 }}>
          {visible}
          <span style={{ opacity: caret ? 0.85 : 0, fontWeight: 300 }}>|</span>
        </div>
      </div>
        {bar ? <DictationOverlay tail={visible.slice(-42)} lang={lang} /> : null}
      </div>
    </AbsoluteFill>
  );
};
