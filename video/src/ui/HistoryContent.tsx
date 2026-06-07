import { interpolate, useCurrentFrame } from "remotion";
import { U, uiFont } from "./uiTheme";

const ENTRIES = [
  { text: "Let's ship the landing page changes and push to production this afternoon.", time: "7 Jun at 17:55" },
  { text: "Remind me to follow up with the design feedback tomorrow morning.", time: "7 Jun at 17:54" },
  { text: "The new dictation flow feels instant — no lag at all.", time: "7 Jun at 17:53" },
  { text: "Add a section about offline mode to the docs.", time: "7 Jun at 17:51" },
];

const CopyButton: React.FC<{ pressed?: boolean }> = ({ pressed }) => (
  <div
    style={{
      fontSize: 26,
      fontWeight: 600,
      color: pressed ? "#fff" : U.text,
      background: pressed ? U.blue : U.chip,
      padding: "12px 26px",
      borderRadius: 12,
    }}
  >
    {pressed ? "Copied" : "Copy"}
  </div>
);

/** History tab content — past transcripts, each with a Copy button. Gently scrolls. */
export const HistoryContent: React.FC = () => {
  const frame = useCurrentFrame();
  const scroll = interpolate(frame, [10, 110], [0, -120], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  // "press copy" on the second card around mid-scene
  const pressIdx = frame > 70 ? 1 : -1;
  return (
    <div style={{ fontFamily: uiFont, transform: `translateY(${scroll}px)`, display: "flex", flexDirection: "column", gap: 26 }}>
      {ENTRIES.map((e, i) => (
        <div key={i} style={{ background: U.group, border: `1px solid ${U.groupBorder}`, borderRadius: 16, padding: "30px 32px" }}>
          <div style={{ fontSize: 31, lineHeight: 1.4, color: U.text, fontWeight: 400 }}>{e.text}</div>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 24 }}>
            <span style={{ fontSize: 24, color: U.sub }}>{e.time}</span>
            <CopyButton pressed={i === pressIdx} />
          </div>
        </div>
      ))}
    </div>
  );
};
