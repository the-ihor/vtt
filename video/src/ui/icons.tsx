// Tiny monochrome glyphs (currentColor) standing in for the sidebar SF Symbols.
type IconProps = { size?: number };

export const GearIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
    <circle cx="12" cy="12" r="3.2" />
    <path d="M12 2.5v2.4M12 19.1v2.4M21.5 12h-2.4M4.9 12H2.5M18.7 5.3l-1.7 1.7M7 17l-1.7 1.7M18.7 18.7L17 17M7 7L5.3 5.3" strokeLinecap="round" />
  </svg>
);

export const ClockIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 7.2V12l3.2 2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const SparkleIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 2.5l1.7 5.1 5.1 1.7-5.1 1.7L12 16.1l-1.7-5.1L5.2 9.3l5.1-1.7z" />
    <path d="M18.5 14.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z" />
  </svg>
);

export const AppleIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
    <path d="M16.4 12.8c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.15-2.8.85-3.5.85-.7 0-1.85-.83-3-.81-1.55.02-2.98.9-3.77 2.3-1.6 2.8-.41 6.95 1.15 9.22.76 1.1 1.67 2.35 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.13 2.76-2.24.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.64zM14.1 5.9c.63-.77 1.06-1.83.94-2.9-.91.04-2.02.61-2.68 1.37-.59.68-1.1 1.77-.96 2.81 1.02.08 2.06-.52 2.7-1.28z" />
  </svg>
);

export const DeepgramIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2}>
    <path d="M6 4.5h6a7.5 7.5 0 0 1 0 15H6" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M6 12h6.5" strokeLinecap="round" />
  </svg>
);

export const ElevenIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
    <rect x="7" y="4.5" width="3.4" height="15" rx="1.4" />
    <rect x="13.6" y="4.5" width="3.4" height="15" rx="1.4" />
  </svg>
);

export const OpenAIIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7}>
    <circle cx="12" cy="12" r="8.3" />
    <path d="M12 3.7c3.2 1.1 3.2 15.5 0 16.6M12 3.7c-3.2 1.1-3.2 15.5 0 16.6M4.3 9.2c2.8-1.9 12.6 4 15.4 5.6M19.7 9.2c-2.8-1.9-12.6 4-15.4 5.6" />
  </svg>
);

export const KeyboardIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7}>
    <rect x="2.5" y="6" width="19" height="12" rx="2.2" />
    <path d="M6 9.5h.01M9 9.5h.01M12 9.5h.01M15 9.5h.01M18 9.5h.01M7.5 14h9" strokeLinecap="round" />
  </svg>
);

export const WifiOffIcon: React.FC<IconProps> = ({ size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
    <path d="M2.5 8.5C6 5.7 9.9 4.5 13.8 5M21.5 8.5c-1-.8-2.05-1.45-3.15-1.95M5.7 12c1.6-1.25 3.4-1.98 5.25-2.18M18.3 12c-.7-.55-1.45-1-2.25-1.35M9 15.6c1.7-1.3 4-1.4 5.8-.3" strokeLinecap="round" />
    <circle cx="12" cy="19" r="1.1" fill="currentColor" stroke="none" />
    <path d="M3 3l18 18" strokeLinecap="round" />
  </svg>
);
