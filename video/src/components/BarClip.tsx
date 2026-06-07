import { AbsoluteFill, OffthreadVideo, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../theme";

/**
 * The floating dictation bar, lifted out of the screen-recording's bottom-centre
 * and presented as a clean pill in the middle of the frame — same treatment as
 * the website's bar image. Masked to a pill so the recording's corners are clipped.
 */
export const BarClip: React.FC<{ src: string }> = ({ src }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 18, stiffness: 90, mass: 0.8 } });
  const y = interpolate(enter, [0, 1], [44, 0]);
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "flex-start", paddingTop: 478 }}>
      <div
        style={{
          width: 1200,
          height: 140,
          borderRadius: 70,
          overflow: "hidden",
          transform: `translateY(${y}px)`,
          opacity: op,
          boxShadow: "0 42px 90px -40px rgba(19,18,16,.6)",
        }}
      >
        <OffthreadVideo src={staticFile(src)} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </div>
    </AbsoluteFill>
  );
};
