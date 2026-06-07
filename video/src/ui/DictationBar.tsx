import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../theme";
import { U, uiFont } from "./uiTheme";
import { WifiOffIcon } from "./icons";

const Waveform: React.FC = () => {
  const frame = useCurrentFrame();
  const bars = Array.from({ length: 16 }, (_, i) => i);
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 5, height: 34 }}>
      {bars.map((i) => {
        const h = 6 + 22 * Math.abs(Math.sin(frame / 3.2 + i * 0.7));
        return <div key={i} style={{ width: 4, height: h, background: "rgba(255,255,255,.55)", borderRadius: 3 }} />;
      })}
    </div>
  );
};

/**
 * VTT's floating dictation bar, recreated in HTML/CSS so it's crisp, centred and
 * fully controllable — the words type in live, like real transcription.
 */
export const DictationBar: React.FC<{ text: string; lang?: string; typeSpeed?: number; offline?: boolean }> = ({
  text,
  lang = "EN",
  typeSpeed = 1.4,
  offline = false,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 18, stiffness: 90, mass: 0.8 } });
  const y = interpolate(enter, [0, 1], [44, 0]);
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });

  const shown = Math.max(0, Math.min(text.length, Math.floor((frame - 6) / typeSpeed)));
  const visible = text.slice(0, shown);
  const caret = Math.floor(frame / 8) % 2 === 0 && shown < text.length;

  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 30 }}>
      {offline ? (
        <div
          style={{
            transform: `translateY(${y}px)`,
            opacity: op,
            display: "flex",
            alignItems: "center",
            gap: 12,
            color: U.text,
            background: "#fff",
            border: `2px solid ${U.text}`,
            borderRadius: 999,
            padding: "12px 24px",
            fontFamily: uiFont,
            fontSize: 28,
            fontWeight: 600,
          }}
        >
          <WifiOffIcon size={30} /> no wi-fi · on-device
        </div>
      ) : null}
      <div
        style={{
          transform: `translateY(${y}px)`,
          opacity: op,
          display: "flex",
          alignItems: "center",
          gap: 26,
          width: 1180,
          height: 132,
          padding: "0 40px",
          borderRadius: 66,
          background: "#0d0d0f",
          boxShadow: "0 42px 90px -40px rgba(19,18,16,.65)",
          fontFamily: uiFont,
        }}
      >
        <span style={{ width: 30, height: 30, borderRadius: 8, background: C.accent, flexShrink: 0 }} />
        <Waveform />
        <div
          style={{
            flex: 1,
            textAlign: "right",
            color: "#fff",
            fontSize: 40,
            fontWeight: 500,
            letterSpacing: "-0.01em",
            whiteSpace: "nowrap",
            overflow: "hidden",
          }}
        >
          {visible}
          {caret ? <span style={{ opacity: 0.7 }}>|</span> : null}
        </div>
        <span style={{ fontSize: 30, fontWeight: 600, color: "rgba(255,255,255,.55)", flexShrink: 0 }}>{lang}</span>
      </div>
    </AbsoluteFill>
  );
};
