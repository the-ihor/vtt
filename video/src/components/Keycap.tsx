import { interpolate, useCurrentFrame } from "remotion";
import { C, fontFamily } from "../theme";

const Key: React.FC<{ label: string; wide?: boolean; press: number }> = ({ label, wide, press }) => (
  <div
    style={{
      fontFamily,
      fontWeight: 600,
      fontSize: 54,
      lineHeight: 1,
      padding: wide ? "24px 96px" : "24px 36px",
      borderRadius: 18,
      border: `3px solid ${C.ink}`,
      color: press > 0.5 ? C.accentInk : C.ink,
      background: press > 0.5 ? C.accent : C.card,
      boxShadow: `0 ${interpolate(press, [0, 1], [11, 2])}px 0 rgba(19,18,16,.32)`,
      transform: `translateY(${interpolate(press, [0, 1], [0, 9])}px)`,
    }}
  >
    {label}
  </div>
);

/**
 * The ⌃Space trigger, shown visibly pressing down and *staying* down — because
 * you hold the key to talk. This is what teaches the gesture a raw screen-recording
 * can't show.
 */
export const Keycap: React.FC = () => {
  const frame = useCurrentFrame();
  const press = interpolate(frame, [9, 14], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
      <Key label="⌃" press={press} />
      <Key label="Space" wide press={press} />
    </div>
  );
};
