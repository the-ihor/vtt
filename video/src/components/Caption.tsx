import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, fontFamily } from "../theme";

/**
 * Caption sitting slightly ABOVE centre — eyes lift more easily than they drop,
 * and it stays in the same focal zone as the action instead of forcing a glance
 * to the bottom of the frame.
 */
export const Caption: React.FC<{ children: React.ReactNode; accent?: boolean }> = ({ children, accent }) => {
  const frame = useCurrentFrame();
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });
  const y = interpolate(frame, [0, 12], [16, 0], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "flex-start", paddingTop: 388 }}>
      <div
        style={{
          transform: `translateY(${y}px)`,
          opacity: op,
          background: "rgba(233,230,221,.94)",
          color: accent ? C.accent : C.ink,
          fontFamily,
          fontSize: 40,
          fontWeight: 700,
          letterSpacing: "-0.02em",
          padding: "16px 34px",
          borderRadius: 16,
          boxShadow: "0 26px 60px -30px rgba(19,18,16,.55)",
        }}
      >
        {children}
      </div>
    </AbsoluteFill>
  );
};
