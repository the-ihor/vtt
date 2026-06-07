import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, fontFamily } from "../theme";

/** Cold open: blank doc + blinking caret + the "typing can't keep up" tease. */
export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const blink = Math.floor(frame / 8) % 2 === 0 ? 1 : 0.15;
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 30 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 4, opacity: op }}>
        <span style={{ fontFamily, fontSize: 56, color: C.ink, fontWeight: 500 }}>I&nbsp;</span>
        <span style={{ width: 5, height: 58, background: C.accent, opacity: blink, borderRadius: 2 }} />
      </div>
      <div style={{ fontFamily, fontSize: 26, letterSpacing: "0.16em", textTransform: "uppercase", color: C.faint, opacity: op }}>
        typing can&rsquo;t keep up
      </div>
    </AbsoluteFill>
  );
};
