import { loadFont } from "@remotion/google-fonts/SpaceGrotesk";

// Same display font as the website.
export const { fontFamily } = loadFont();

// Brand palette — mirrors docs/index.html :root tokens.
export const C = {
  paper: "#e9e6dd",
  paper2: "#e2ded3",
  card: "#f1eee7",
  card2: "#e4e0d5",
  ink: "#131210",
  inkSoft: "#3b3831",
  muted: "#6f6b60",
  faint: "#928d80",
  accent: "#f23a1d",
  accentInk: "#ffffff",
  line: "rgba(19,18,16,.16)",
} as const;

export const FPS = 30;
// Track: 123.7 BPM → one beat = 0.485s ≈ 14.55 frames @30fps.
export const BEAT = 0.485;
/** Seconds → frame (snapped). */
export const f = (sec: number) => Math.round(sec * FPS);
