import { U, uiFont } from "./uiTheme";
import { AppleIcon, ClockIcon, DeepgramIcon, ElevenIcon, GearIcon, OpenAIIcon, SparkleIcon } from "./icons";

type Item = { key: string; label: string; icon: React.FC<{ size?: number }> };

const TOP: Item[] = [
  { key: "General", label: "General", icon: GearIcon },
  { key: "History", label: "History", icon: ClockIcon },
  { key: "Subscription", label: "Subscription", icon: SparkleIcon },
];
const ON_DEVICE: Item[] = [
  { key: "Apple Legacy", label: "Apple Legacy", icon: AppleIcon },
  { key: "Apple Speech", label: "Apple Speech", icon: AppleIcon },
];
const NETWORK: Item[] = [
  { key: "Deepgram", label: "Deepgram", icon: DeepgramIcon },
  { key: "ElevenLabs", label: "ElevenLabs", icon: ElevenIcon },
  { key: "OpenAI", label: "OpenAI", icon: OpenAIIcon },
];

const SectionLabel: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontSize: 19, fontWeight: 600, color: U.sub, letterSpacing: ".02em", margin: "26px 0 8px 14px" }}>
    {children}
  </div>
);

const SidebarRow: React.FC<{ item: Item; active: boolean }> = ({ item, active }) => {
  const Icon = item.icon;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 15,
        padding: "13px 16px",
        borderRadius: 12,
        background: active ? U.blue : "transparent",
        color: active ? "#fff" : U.text,
        fontSize: 27,
        fontWeight: 500,
      }}
    >
      <Icon size={28} />
      {item.label}
    </div>
  );
};

export const MacWindow: React.FC<{ active: string; children: React.ReactNode }> = ({ active, children }) => (
  <div
    style={{
      width: 1480,
      height: 940,
      borderRadius: 26,
      background: U.win,
      boxShadow: "0 60px 140px -50px rgba(19,18,16,.6)",
      overflow: "hidden",
      display: "flex",
      fontFamily: uiFont,
      color: U.text,
    }}
  >
    {/* Sidebar */}
    <div style={{ width: 340, background: U.sidebar, padding: "0 16px 18px", borderRight: "1px solid rgba(0,0,0,.06)" }}>
      <div style={{ display: "flex", gap: 11, padding: "22px 8px 26px" }}>
        <span style={{ width: 17, height: 17, borderRadius: "50%", background: U.tlRed }} />
        <span style={{ width: 17, height: 17, borderRadius: "50%", background: U.tlYellow }} />
        <span style={{ width: 17, height: 17, borderRadius: "50%", background: U.tlGreen }} />
      </div>
      {TOP.map((it) => (
        <SidebarRow key={it.key} item={it} active={it.key === active} />
      ))}
      <SectionLabel>On-Device Providers</SectionLabel>
      {ON_DEVICE.map((it) => (
        <SidebarRow key={it.key} item={it} active={it.key === active} />
      ))}
      <SectionLabel>Network Providers</SectionLabel>
      {NETWORK.map((it) => (
        <SidebarRow key={it.key} item={it} active={it.key === active} />
      ))}
    </div>
    {/* Content */}
    <div style={{ flex: 1, padding: "44px 46px", overflow: "hidden" }}>{children}</div>
  </div>
);

export const GroupTitle: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontFamily: uiFont, fontSize: 30, fontWeight: 700, color: U.text, margin: "0 0 14px 4px" }}>
    {children}
  </div>
);

export const Group: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div
    style={{
      background: U.group,
      border: `1px solid ${U.groupBorder}`,
      borderRadius: 16,
      overflow: "hidden",
      marginBottom: 34,
      ...style,
    }}
  >
    {children}
  </div>
);

const Chevrons: React.FC = () => (
  <svg width={26} height={26} viewBox="0 0 24 24" fill="none" stroke={U.chevron} strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
    <path d="M8.5 10.5L12 7l3.5 3.5M8.5 13.5L12 17l3.5-3.5" />
  </svg>
);

/** A settings row: label on the left, a value pill (with picker chevrons) on the right. */
export const Row: React.FC<{
  label: string;
  value?: React.ReactNode;
  last?: boolean;
  /** highlight the value pill (e.g. the one we're "changing") */
  hot?: boolean;
}> = ({ label, value, last, hot }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "26px 26px",
      borderBottom: last ? "none" : `1px solid ${U.rowSep}`,
      fontFamily: uiFont,
    }}
  >
    <span style={{ fontSize: 30, fontWeight: 500, color: U.text }}>{label}</span>
    {value !== undefined ? (
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 14,
          fontSize: 29,
          fontWeight: 500,
          color: U.text,
          background: hot ? "#fff" : "transparent",
          boxShadow: hot ? `0 0 0 3px ${U.blue}` : "none",
          borderRadius: 12,
          padding: hot ? "8px 14px" : "0",
          transition: "all .2s",
        }}
      >
        {value}
        <Chevrons />
      </div>
    ) : null}
  </div>
);
