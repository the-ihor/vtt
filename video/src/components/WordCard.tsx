import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, fontFamily } from "../theme";

type Props = {
  word: string;
  accent?: boolean;
  /** dark background, light text (used for the privacy beat) */
  ink?: boolean;
  sub?: string;
  size?: number;
};

/**
 * Full-bleed kinetic word that punches in on the beat: clip-path reveal from
 * below + a slight scale overshoot. No exit animation — sequences cut hard on
 * the beat, which is the whole point of the rhythm.
 */
export const WordCard: React.FC<Props> = ({ word, accent, ink, sub, size = 210 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({ frame, fps, config: { damping: 13, stiffness: 130, mass: 0.7 } });
  const y = interpolate(enter, [0, 1], [130, 0]);
  const scale = interpolate(enter, [0, 1], [1.12, 1]);
  const op = interpolate(frame, [0, 3], [0, 1], { extrapolateRight: "clamp" });

  const fg = accent ? C.accent : ink ? C.paper : C.ink;

  return (
    <AbsoluteFill
      style={{
        background: ink ? C.ink : C.paper,
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
        gap: 26,
      }}
    >
      <div style={{ overflow: "hidden", padding: "0.14em 0.06em" }}>
        <div
          style={{
            fontFamily,
            fontWeight: 700,
            letterSpacing: "-0.045em",
            fontSize: size,
            lineHeight: 0.86,
            color: fg,
            whiteSpace: "nowrap",
            transform: `translateY(${y}px) scale(${scale})`,
            opacity: op,
          }}
        >
          {word}
        </div>
      </div>
      {sub ? (
        <div
          style={{
            fontFamily,
            fontSize: 30,
            fontWeight: 500,
            letterSpacing: "0.04em",
            color: ink ? "rgba(233,230,221,.6)" : C.muted,
            opacity: interpolate(frame, [4, 14], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          }}
        >
          {sub}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
