import { AbsoluteFill, OffthreadVideo, staticFile } from "remotion";
import { C, fontFamily } from "../theme";

type Props = {
  /** path under public/, e.g. "clips/01-dictate.mp4". Undefined → placeholder. */
  src?: string;
  label: string;
  fit?: "cover" | "contain";
  /** 0..1 dark scrim on top, for caption legibility */
  dim?: number;
};

/**
 * A slot for one of your screen-recordings. While `src` is undefined it renders
 * a labelled placeholder, so the whole film previews/renders today. Drop the
 * file in public/clips/ and set its path in CLIPS (HeroVideo.tsx) to fill it.
 */
export const ClipSlot: React.FC<Props> = ({ src, label, fit = "cover", dim = 0 }) => {
  if (src) {
    return (
      <AbsoluteFill style={{ background: C.card2 }}>
        <OffthreadVideo
          src={staticFile(src)}
          muted
          style={{ width: "100%", height: "100%", objectFit: fit }}
        />
        {dim > 0 ? <AbsoluteFill style={{ background: `rgba(19,18,16,${dim})` }} /> : null}
      </AbsoluteFill>
    );
  }

  return (
    <AbsoluteFill
      style={{
        background: C.card2,
        border: `2px dashed ${C.faint}`,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div style={{ textAlign: "center", fontFamily, color: C.faint }}>
        <div style={{ fontSize: 18, letterSpacing: "0.18em", textTransform: "uppercase", opacity: 0.6, marginBottom: 14 }}>
          clip slot
        </div>
        <div style={{ fontSize: 34, fontWeight: 600, letterSpacing: "-0.01em", color: C.muted, maxWidth: 900 }}>
          {label}
        </div>
      </div>
    </AbsoluteFill>
  );
};
