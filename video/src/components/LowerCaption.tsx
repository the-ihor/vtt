import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, fontFamily } from "../theme";

/** Lower-third pill caption that floats up over a clip. */
export const LowerCaption: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });
  const y = interpolate(frame, [0, 12], [22, 0], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "flex-end", padding: "0 0 96px" }}>
      <div
        style={{
          transform: `translateY(${y}px)`,
          opacity: op,
          background: "rgba(233,230,221,.92)",
          color: C.ink,
          fontFamily,
          fontSize: 32,
          fontWeight: 600,
          letterSpacing: "-0.01em",
          padding: "16px 30px",
          borderRadius: 999,
          boxShadow: "0 20px 50px -28px rgba(19,18,16,.6)",
        }}
      >
        {children}
      </div>
    </AbsoluteFill>
  );
};
