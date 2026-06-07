import { useCurrentFrame } from "remotion";
import { C } from "../theme";

/** A live "listening" waveform — the visual cue that VTT is hearing you. */
export const Listening: React.FC = () => {
  const frame = useCurrentFrame();
  const bars = Array.from({ length: 9 }, (_, i) => i);
  return (
    <div style={{ display: "flex", gap: 11, alignItems: "center", height: 100 }}>
      {bars.map((i) => {
        const h = 22 + 64 * Math.abs(Math.sin(frame / 4 + i * 0.55));
        return <div key={i} style={{ width: 15, height: h, background: C.ink, borderRadius: 8 }} />;
      })}
    </div>
  );
};
