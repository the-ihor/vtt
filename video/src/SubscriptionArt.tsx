import { AbsoluteFill } from "remotion";
import { C, fontFamily } from "./theme";

// 1024×1024 App Store subscription image for the "Unlimited Dictation" plan.
// The logo-mark bars sit at the centre of a waveform that runs off both edges
// — dictation without a limit. Rendered as a Still (id: SubscriptionArt).

// Logo-mark bars from docs/assets/logo-mark.svg (1024 grid), recentred.
const MARK = [
  { x: 236, h: 240 },
  { x: 388, h: 620 },
  { x: 540, h: 384 },
  { x: 692, h: 524 },
];
const BAR_W = 96;
const STEP = 152; // mark bar pitch
const CY = 470;
// Shift the mark so the 4-bar group is horizontally centred on the canvas.
const MARK_OFFSET = (1024 - (692 + BAR_W - 236)) / 2 - 236;

// Pseudo-random but deterministic heights for the surrounding wave.
const sideHeight = (i: number) => {
  const s = Math.sin(i * 2.7) * 0.5 + Math.sin(i * 1.3 + 1) * 0.5;
  return 90 + Math.abs(s) * 240;
};

export const SubscriptionArt: React.FC = () => {
  const bars: { x: number; h: number; accent: boolean }[] = MARK.map((b) => ({
    x: b.x + MARK_OFFSET,
    h: b.h,
    accent: true,
  }));
  // Extend the wave past both edges at the same pitch as the mark.
  for (let i = 1; i <= 5; i++) {
    bars.push({ x: bars[0].x - i * STEP, h: sideHeight(i), accent: false });
    bars.push({
      x: MARK[3].x + MARK_OFFSET + i * STEP,
      h: sideHeight(i + 7),
      accent: false,
    });
  }

  return (
    <AbsoluteFill style={{ backgroundColor: C.ink }}>
      {bars.map((b, i) => {
        // Side bars fade the further they sit from the mark — the wave
        // continues beyond the frame rather than ending.
        const center = Math.abs(b.x + BAR_W / 2 - 512);
        const fade = b.accent ? 1 : Math.max(0.12, 0.5 - center / 1300);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: b.x,
              top: CY - b.h / 2,
              width: BAR_W,
              height: b.h,
              borderRadius: BAR_W / 2,
              backgroundColor: b.accent ? C.accent : C.paper,
              opacity: fade,
            }}
          />
        );
      })}

      {/* plan name */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 812,
          textAlign: "center",
          fontFamily,
          fontWeight: 700,
          fontSize: 76,
          letterSpacing: -1,
          color: C.paper,
          lineHeight: 1,
        }}
      >
        Unlimited Dictation
      </div>
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 910,
          textAlign: "center",
          fontFamily,
          fontWeight: 500,
          fontSize: 34,
          letterSpacing: 6,
          textTransform: "uppercase",
          color: C.faint,
          lineHeight: 1,
        }}
      >
        VTT Pro
      </div>
    </AbsoluteFill>
  );
};
