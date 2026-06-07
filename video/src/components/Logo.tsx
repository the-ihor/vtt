import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, fontFamily } from "../theme";

const Equalizer: React.FC = () => {
  const frame = useCurrentFrame();
  const bars = [0, 1, 2, 3, 4];
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 9, height: 130 }}>
      {bars.map((i) => {
        const h = 55 + 60 * Math.abs(Math.sin(frame / 6 + i * 0.7));
        return <div key={i} style={{ width: 20, height: h, background: C.accent, borderRadius: 8 }} />;
      })}
    </div>
  );
};

/** End lockup: animated waveform mark + VTT + tagline + url. */
export const Logo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 16, stiffness: 90, mass: 0.8 } });
  const scale = interpolate(enter, [0, 1], [0.92, 1]);
  const op = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const taglineOp = interpolate(frame, [12, 26], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const urlOp = interpolate(frame, [24, 38], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 36, opacity: op }}>
      <div style={{ display: "flex", alignItems: "center", gap: 28, transform: `scale(${scale})` }}>
        <Equalizer />
        <div style={{ fontFamily, fontWeight: 700, fontSize: 170, letterSpacing: "-0.05em", color: C.ink, lineHeight: 1 }}>VTT</div>
      </div>
      <div style={{ fontFamily, fontWeight: 700, fontSize: 58, letterSpacing: "-0.03em", color: C.ink, opacity: taglineOp }}>
        Stop typing. <span style={{ color: C.accent }}>Start talking.</span>
      </div>
      <div style={{ fontFamily, fontSize: 26, fontWeight: 500, letterSpacing: "0.12em", textTransform: "uppercase", color: C.muted, opacity: urlOp }}>
        vtt.the-ihor.com&nbsp;&nbsp;·&nbsp;&nbsp;free&nbsp;&nbsp;·&nbsp;&nbsp;macOS
      </div>
    </AbsoluteFill>
  );
};
