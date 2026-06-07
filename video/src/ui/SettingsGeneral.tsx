import { GroupTitle, Group, Row } from "./SettingsWindow";
import { U, uiFont } from "./uiTheme";
import { KeyboardIcon } from "./icons";

type Props = {
  provider?: string;
  language?: string;
  perLang?: { english: string; russian: string; ukrainian: string };
  hot?: "russian" | "language" | null;
  /** small floating keyboard badge shown by the Language row */
  keyboardBadge?: string;
};

/** The General settings page — Speech provider, Language, Provider-per-language. */
export const SettingsGeneral: React.FC<Props> = ({
  provider = "Apple — SpeechAnalyzer (macOS 26)",
  language = "Default language (current keyboard language)",
  perLang = { english: "Default (Apple Speech)", russian: "OpenAI", ukrainian: "Deepgram" },
  hot = null,
  keyboardBadge,
}) => (
  <div style={{ fontFamily: uiFont, position: "relative" }}>
    <GroupTitle>Speech</GroupTitle>
    <Group>
      <Row label="Provider" value={provider} last />
    </Group>

    <GroupTitle>Language</GroupTitle>
    <Group>
      <Row label="Language" value={language} last hot={hot === "language"} />
    </Group>
    {keyboardBadge ? (
      <div
        style={{
          position: "absolute",
          top: -4,
          right: 0,
          display: "flex",
          alignItems: "center",
          gap: 12,
          background: U.text,
          color: "#fff",
          fontSize: 30,
          fontWeight: 700,
          padding: "12px 24px",
          borderRadius: 14,
          boxShadow: "0 16px 36px -16px rgba(0,0,0,.5)",
        }}
      >
        <KeyboardIcon size={32} /> {keyboardBadge}
      </div>
    ) : null}

    <GroupTitle>Provider per language</GroupTitle>
    <Group>
      <Row label="English" value={perLang.english} />
      <Row label="Russian" value={perLang.russian} hot={hot === "russian"} />
      <Row label="Ukrainian" value={perLang.ukrainian} last />
    </Group>
  </div>
);
