import { AbsoluteFill } from "remotion";
import { C, fontFamily } from "./theme";

// Background for the VTT.dmg installer window — 660×400 pt logical size
// (render at --scale 2 for the @2x variant; both are combined into a retina
// TIFF by scripts/make-dmg-background.sh). The app icon sits at (165,200),
// the Applications alias at (495,200), icon size 128 — the arrow bridges them.

export const DMG_SIZE = { width: 660, height: 400 } as const;

const Mark: React.FC<{ size?: number }> = ({ size = 30 }) => {
  const s = size / 1024;
  const bars = [
    { x: 236, y: 392, h: 240 },
    { x: 388, y: 202, h: 620 },
    { x: 540, y: 320, h: 384 },
    { x: 692, y: 250, h: 524 },
  ];
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      {bars.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: b.x * s,
            top: b.y * s,
            width: 96 * s,
            height: b.h * s,
            borderRadius: 48 * s,
            background: C.accent,
          }}
        />
      ))}
    </div>
  );
};

export const DmgBackground: React.FC = () => (
  <AbsoluteFill style={{ background: C.paper, fontFamily, color: C.ink }}>
    {/* brand, top-left */}
    <div
      style={{
        position: "absolute",
        top: 28,
        left: 32,
        display: "flex",
        alignItems: "center",
        gap: 10,
      }}
    >
      <Mark size={26} />
      <span style={{ fontWeight: 700, fontSize: 22, letterSpacing: "-0.04em" }}>VTT</span>
      <span style={{ fontWeight: 500, fontSize: 13, color: C.muted, marginLeft: 6 }}>
        Voice to Text for Mac
      </span>
    </div>

    {/* arrow between the two icon slots (icons land at x=165 and x=495, y=200) */}
    <svg
      width={170}
      height={56}
      viewBox="0 0 170 56"
      style={{ position: "absolute", left: 245, top: 172 }}
    >
      <path
        d="M8 28 H134"
        stroke={C.accent}
        strokeWidth={7}
        strokeLinecap="round"
      />
      <path
        d="M122 10 L150 28 L122 46"
        fill="none"
        stroke={C.accent}
        strokeWidth={7}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>

    {/* caption */}
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: 304,
        textAlign: "center",
        fontSize: 15,
        fontWeight: 600,
        color: C.inkSoft,
      }}
    >
      Drag VTT into Applications
    </div>
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: 330,
        textAlign: "center",
        fontSize: 12,
        fontWeight: 500,
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: C.faint,
      }}
    >
      then press ⌃Space anywhere and start talking
    </div>
  </AbsoluteFill>
);
