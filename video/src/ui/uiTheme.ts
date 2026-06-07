import { loadFont } from "@remotion/google-fonts/Inter";

// Inter stands in for SF Pro — the closest widely-available match to the macOS UI.
export const { fontFamily: uiFont } = loadFont();

// macOS light-mode settings palette (eyeballed from the app screenshots).
export const U = {
  win: "#ffffff",
  sidebar: "#f4f4f6",
  group: "#f1f1f3",
  groupBorder: "rgba(0,0,0,.05)",
  rowSep: "rgba(0,0,0,.07)",
  text: "#1d1d1f",
  sub: "#86868b",
  blue: "#0a84ff",
  green: "#2ea043",
  greenDot: "#34c759",
  tlRed: "#ff5f57",
  tlYellow: "#febc2e",
  tlGreen: "#28c840",
  chip: "#e7e7ea",
  chevron: "#9a9aa0",
} as const;
