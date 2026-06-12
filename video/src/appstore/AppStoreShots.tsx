import { AbsoluteFill, Img, staticFile } from "remotion";
import { C, fontFamily } from "../theme";

// Mac App Store screenshots — 2880×1800 (16:10). Real app captures from
// docs/assets (copied to public/appstore/), framed in the brand system the
// Product Hunt gallery uses: paper, ink, accent red, Space Grotesk.
// Copy is localized per store locale; the UI captures stay English.

export const SHOT_SIZE = { width: 2880, height: 1800 } as const;

/** Headline as plain/accent segments, so locales control accent placement. */
type Seg = string | { a: string };
type SlideCopy = { kicker: string; title: Seg[] };
type Slide = SlideCopy & { src: string; hero?: boolean };

const EN: SlideCopy[] = [
  { kicker: "Voice to text for Mac", title: ["You talk. It types — ", { a: "in any app" }, "."] },
  { kicker: "On-device & private", title: ["Audio can ", { a: "stay on your Mac" }, ". Entirely."] },
  { kicker: "Built for accents & languages", title: ["A ", { a: "different engine" }, " for every language you speak."] },
  { kicker: "Zero configuration switching", title: ["Follows your ", { a: "keyboard language" }, ", automatically."] },
  { kicker: "Works offline", title: ["Download a language once. ", { a: "Dictate without internet" }, "."] },
  { kicker: "Nothing gets lost", title: ["Every dictation, ", { a: "one Copy away" }, "."] },
];

const UK: SlideCopy[] = [
  { kicker: "Голос у текст для Mac", title: ["Ви говорите. Воно друкує — ", { a: "у будь-якому застосунку" }, "."] },
  { kicker: "На пристрої та приватно", title: ["Аудіо може ", { a: "лишатися на вашому Mac" }, ". Повністю."] },
  { kicker: "Створено для акцентів і мов", title: [{ a: "Окремий рушій" }, " для кожної мови, якою ви говорите."] },
  { kicker: "Перемикання без налаштувань", title: ["Підхоплює ", { a: "мову клавіатури" }, " — автоматично."] },
  { kicker: "Працює офлайн", title: ["Завантажте мову один раз. ", { a: "Диктуйте без інтернету" }, "."] },
  { kicker: "Ніщо не губиться", title: ["Кожне диктування — ", { a: "завжди під рукою" }, "."] },
];

// Screenshot per slide; slide 1 floats the real dictation-bar capture.
const SRC = [
  "appstore/feature-02.png",
  "appstore/feature-01.png",
  "appstore/feature-05.png",
  "appstore/feature-08.png",
  "appstore/feature-06.png",
  "appstore/feature-09.png",
];

const slides = (copy: SlideCopy[]): Slide[] =>
  copy.map((c, i) => ({ ...c, src: SRC[i], hero: i === 0 }));

const Mark: React.FC<{ size?: number }> = ({ size = 56 }) => {
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

const ShotPage: React.FC<{ slide: Slide }> = ({ slide }) => (
  <AbsoluteFill
    style={{
      background: C.paper,
      fontFamily,
      color: C.ink,
      padding: "130px 160px 120px",
      flexDirection: "column",
      alignItems: "center",
    }}
  >
    <div
      style={{
        position: "absolute",
        top: 84,
        right: 110,
        display: "flex",
        alignItems: "center",
        gap: 20,
        opacity: 0.85,
      }}
    >
      <Mark size={52} />
      <span style={{ fontWeight: 700, fontSize: 46, letterSpacing: "-0.04em" }}>VTT</span>
    </div>

    <div
      style={{
        fontSize: 34,
        fontWeight: 600,
        letterSpacing: "0.16em",
        textTransform: "uppercase",
        color: C.accent,
        marginBottom: 30,
      }}
    >
      {slide.kicker}
    </div>
    <div
      style={{
        fontSize: 118,
        fontWeight: 700,
        letterSpacing: "-0.04em",
        lineHeight: 1.04,
        textAlign: "center",
        maxWidth: 2300,
      }}
    >
      {slide.title.map((seg, i) =>
        typeof seg === "string" ? (
          seg
        ) : (
          <span key={i} style={{ color: C.accent }}>
            {seg.a}
          </span>
        )
      )}
    </div>

    <div
      style={{
        flex: 1,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
        marginTop: 50,
        width: "100%",
      }}
    >
      <div style={{ position: "relative" }}>
        <div
          style={{
            width: slide.hero ? 1820 : 1980,
            borderRadius: 28,
            overflow: "hidden",
            boxShadow: "0 60px 120px -50px rgba(19,18,16,.55), 0 0 0 1px rgba(19,18,16,.08)",
            lineHeight: 0,
            background: "#fff",
          }}
        >
          <Img src={staticFile(slide.src)} style={{ width: "100%" }} />
        </div>
        {slide.hero ? (
          // the real dictation bar capture, floated over the window
          <div
            style={{
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
              bottom: -64,
              width: 1140,
              borderRadius: 90,
              overflow: "hidden",
              boxShadow: "0 52px 110px -45px rgba(19,18,16,.6)",
              lineHeight: 0,
            }}
          >
            <Img src={staticFile("appstore/feature-07.png")} style={{ width: "100%" }} />
          </div>
        ) : null}
      </div>
    </div>
  </AbsoluteFill>
);

const page = (slide: Slide): React.FC => {
  const Comp: React.FC = () => <ShotPage slide={slide} />;
  return Comp;
};

export const APPSTORE_SHOTS = slides(EN).map(page);
export const APPSTORE_SHOTS_UA = slides(UK).map(page);
