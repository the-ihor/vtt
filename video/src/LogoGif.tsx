import {
  AbsoluteFill,
  Easing,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { C, fontFamily } from "./theme";

// Bars from docs/assets/logo-mark.svg (1024 grid), scaled to the 240 canvas.
const S = 240 / 1024;
const BARS = [
  { x: 236, h: 240, cycles: 2, phase: 0.0 },
  { x: 388, h: 620, cycles: 3, phase: 0.25 },
  { x: 540, h: 384, cycles: 2, phase: 0.55 },
  { x: 692, h: 524, cycles: 3, phase: 0.8 },
];
const W = 96 * S;
const CY = 120;

const LETTERS = ["V", "T", "T"];
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// Timeline @30fps over 90 frames: bars speak → collapse → "VTT" types in
// with a caret → dissolves → bars rise again (seamless loop).
export const LogoGif: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames: D } = useVideoConfig();
  const t = frame / D;

  // Bar amplitude: whole sine cycles per loop keeps the pulse continuous
  // across the wrap; the envelope squashes the bars away while the text shows.
  const env = interpolate(frame, [26, 38, 74, 86], [1, 0, 0, 1], {
    ...clamp,
    easing: Easing.inOut(Easing.cubic),
  });
  const barOpacity = interpolate(frame, [32, 40, 74, 82], [1, 0, 0, 1], clamp);

  const typingDone = frame >= 52;
  const caretBlink = typingDone ? (Math.floor(frame / 8) % 2 === 0 ? 1 : 0) : 1;
  const caretIn = interpolate(frame, [38, 42, 68, 76], [0, 1, 1, 0], clamp);

  return (
    <AbsoluteFill style={{ backgroundColor: C.ink }}>
      {/* waveform bars */}
      {BARS.map((b, i) => {
        const wave = Math.sin(2 * Math.PI * (b.cycles * t + b.phase));
        const h = Math.max(6, b.h * S * (0.78 + 0.3 * wave * wave) * env);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: b.x * S,
              top: CY - h / 2,
              width: W,
              height: h,
              borderRadius: W / 2,
              backgroundColor: C.accent,
              opacity: barOpacity,
            }}
          />
        );
      })}

      {/* the transcribed word */}
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "row",
        }}
      >
        {LETTERS.map((ch, i) => {
          const start = 36 + i * 5;
          const pop = interpolate(frame, [start, start + 9], [0, 1], {
            ...clamp,
            easing: Easing.out(Easing.back(1.7)),
          });
          const fadeIn = interpolate(frame, [start, start + 7], [0, 1], clamp);
          const out = interpolate(frame, [64 + i * 4, 72 + i * 4], [0, 1], {
            ...clamp,
            easing: Easing.in(Easing.cubic),
          });
          return (
            <span
              key={i}
              style={{
                fontFamily,
                fontWeight: 700,
                fontSize: 92,
                lineHeight: 1,
                color: C.paper,
                opacity: fadeIn * (1 - out),
                transform: `translateY(${(1 - pop) * 26 - out * 14}px) scale(${
                  0.8 + 0.2 * pop - 0.1 * out
                })`,
                filter: `blur(${(1 - fadeIn) * 5 + out * 6}px)`,
              }}
            >
              {ch}
            </span>
          );
        })}
        {/* dictation caret */}
        <div
          style={{
            width: 8,
            height: 64,
            marginLeft: 8,
            borderRadius: 4,
            backgroundColor: C.accent,
            opacity: caretIn * caretBlink,
          }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
