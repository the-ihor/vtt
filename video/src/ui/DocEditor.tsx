import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../theme";
import { U, uiFont } from "./uiTheme";

/** A TextEdit-like window with words streaming in — used for the FLOW / app beats. */
export const DocEditor: React.FC<{ title?: string; text: string; typeSpeed?: number }> = ({
  title = "Untitled — Edited",
  text,
  typeSpeed = 0.9,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 18, stiffness: 90, mass: 0.8 } });
  const scale = interpolate(enter, [0, 1], [0.96, 1]);
  const op = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });

  const shown = Math.max(0, Math.min(text.length, Math.floor((frame - 6) / typeSpeed)));
  const visible = text.slice(0, shown);
  const caret = Math.floor(frame / 8) % 2 === 0;

  return (
    <AbsoluteFill style={{ background: C.paper, alignItems: "center", justifyContent: "center" }}>
      <div
        style={{
          width: 1300,
          height: 820,
          borderRadius: 22,
          background: U.win,
          boxShadow: "0 60px 140px -50px rgba(19,18,16,.6)",
          overflow: "hidden",
          transform: `scale(${scale})`,
          opacity: op,
          fontFamily: uiFont,
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ position: "relative", height: 64, borderBottom: "1px solid rgba(0,0,0,.08)", display: "flex", alignItems: "center" }}>
          <div style={{ display: "flex", gap: 11, paddingLeft: 22 }}>
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlRed }} />
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlYellow }} />
            <span style={{ width: 16, height: 16, borderRadius: "50%", background: U.tlGreen }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, textAlign: "center", fontSize: 24, fontWeight: 600, color: U.sub }}>
            {title}
          </div>
        </div>
        <div style={{ flex: 1, padding: "44px 54px", fontSize: 42, lineHeight: 1.5, color: U.text, fontWeight: 400 }}>
          {visible}
          <span style={{ opacity: caret ? 0.85 : 0, fontWeight: 300 }}>|</span>
        </div>
      </div>
    </AbsoluteFill>
  );
};
