import { AbsoluteFill, Audio, Sequence, staticFile } from "remotion";
import { C, f } from "./theme";
import { Grain } from "./components/Grain";
import { WordCard } from "./components/WordCard";
import { ClipSlot } from "./components/ClipSlot";
import { LowerCaption } from "./components/LowerCaption";
import { IntroScene } from "./components/IntroScene";
import { Logo } from "./components/Logo";

/**
 * 👉 Drop your screen-recordings in public/clips/ and fill in the paths below.
 * Until a path is set, that beat shows a labelled placeholder, so the whole
 * film previews and renders right now.
 */
const CLIPS: Record<string, string | undefined> = {
  dictate: undefined, //   "clips/01-dictate.mp4"   press ^Space → speak → text auto-inserts
  apps: undefined, //      "clips/02-apps.mp4"      text landing in Mail / VS Code / Messages / browser
  engines: undefined, //   "clips/03-engines.mp4"   provider list; Deepgram toggles on + free-credits chip
  languages: undefined, // "clips/04-languages.mp4" keyboard flips EN → RU → UK, output follows, no translate
  offline: undefined, //   "clips/05-offline.mp4"   Wi-Fi off → switch to Apple on-device model, still works
  flow: undefined, //      "clips/06-flow.mp4"       natural talking, ideas pouring into a doc
  history: undefined, //   "clips/07-history.mp4"    History tab scrolling, Copy buttons
};

// Beat grid (123.7 BPM, first downbeat ≈ 0.95s). All cuts land on a beat.
const T = {
  talk: f(0.95),
  press: f(1.92),
  speak: f(2.89),
  done: f(3.86),
  payoff: f(4.83),
  anyApp: f(8.71),
  appsClip: f(10.0),
  anyEngine: f(12.59),
  enginesClip: f(13.9),
  anyLang: f(16.47),
  langClip: f(17.8),
  noSignal: f(20.35),
  noProblem: f(21.3),
  offlineClip: f(22.29),
  flow: f(24.23),
  flowClip: f(26.2),
  history: f(31.99),
  historyClip: f(33.4),
  mgPrivate: f(34.9),
  mgInstant: f(35.4),
  mgNative: f(35.9),
  mgFree: f(36.4),
  logo: f(38.0),
  end: f(43.0),
};

const Scene: React.FC<{ from: number; durationInFrames: number; children: React.ReactNode }> = ({
  from,
  durationInFrames,
  children,
}) => (
  <Sequence from={from} durationInFrames={durationInFrames}>
    {children}
  </Sequence>
);

export const HeroVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: C.paper }}>
      <Audio src={staticFile("hero-music.wav")} />

      {/* ---- Intro ---- */}
      <Scene from={0} durationInFrames={T.talk}>
        <IntroScene />
      </Scene>

      {/* ---- Phrase 1 — the magic ---- */}
      <Scene from={T.talk} durationInFrames={T.press - T.talk}>
        <WordCard word="TALK." accent />
      </Scene>
      <Scene from={T.press} durationInFrames={T.speak - T.press}>
        <WordCard word="PRESS." />
      </Scene>
      <Scene from={T.speak} durationInFrames={T.done - T.speak}>
        <WordCard word="SPEAK." />
      </Scene>
      <Scene from={T.done} durationInFrames={T.payoff - T.done}>
        <WordCard word="DONE." accent />
      </Scene>
      <Scene from={T.payoff} durationInFrames={T.anyApp - T.payoff}>
        <ClipSlot src={CLIPS.dictate} label="dictation: press ^Space → speak → text inserts" dim={0.35} />
        <LowerCaption>thought → text. zero friction</LowerCaption>
      </Scene>

      {/* ---- Phrase 2 — breadth: apps + engines ---- */}
      <Scene from={T.anyApp} durationInFrames={T.appsClip - T.anyApp}>
        <WordCard word="ANY APP." size={190} />
      </Scene>
      <Scene from={T.appsClip} durationInFrames={T.anyEngine - T.appsClip}>
        <ClipSlot src={CLIPS.apps} label="text landing in Mail · VS Code · Messages · browser" dim={0.3} />
      </Scene>
      <Scene from={T.anyEngine} durationInFrames={T.enginesClip - T.anyEngine}>
        <WordCard word="ANY ENGINE." size={170} />
      </Scene>
      <Scene from={T.enginesClip} durationInFrames={T.anyLang - T.enginesClip}>
        <ClipSlot src={CLIPS.engines} label="Apple · Deepgram · OpenAI · ElevenLabs — your key" dim={0.35} />
        <LowerCaption>free tokens to start</LowerCaption>
      </Scene>

      {/* ---- Phrase 3 — language + offline ---- */}
      <Scene from={T.anyLang} durationInFrames={T.langClip - T.anyLang}>
        <WordCard word="ANY LANGUAGE." size={150} />
      </Scene>
      <Scene from={T.langClip} durationInFrames={T.noSignal - T.langClip}>
        <ClipSlot src={CLIPS.languages} label="keyboard EN → RU → UK, output follows" dim={0.35} />
        <LowerCaption>no translation. ever.</LowerCaption>
      </Scene>
      <Scene from={T.noSignal} durationInFrames={T.noProblem - T.noSignal}>
        <WordCard word="NO SIGNAL?" size={170} ink />
      </Scene>
      <Scene from={T.noProblem} durationInFrames={T.offlineClip - T.noProblem}>
        <WordCard word="NO PROBLEM." accent size={170} ink />
      </Scene>
      <Scene from={T.offlineClip} durationInFrames={T.flow - T.offlineClip}>
        <ClipSlot src={CLIPS.offline} label="offline → Apple on-device model keeps working" dim={0.4} />
        <LowerCaption>on-device · private · yours</LowerCaption>
      </Scene>

      {/* ---- Phrase 4 — the emotional core ---- */}
      <Scene from={T.flow} durationInFrames={T.flowClip - T.flow}>
        <WordCard word="FLOW." accent size={260} />
      </Scene>
      <Scene from={T.flowClip} durationInFrames={T.history - T.flowClip}>
        <ClipSlot src={CLIPS.flow} label="natural talking — ideas pour straight into the doc" dim={0.35} />
        <LowerCaption>native to the Mac. it lives where you do.</LowerCaption>
      </Scene>

      {/* ---- Phrase 5 — history + machine-gun recap ---- */}
      <Scene from={T.history} durationInFrames={T.historyClip - T.history}>
        <WordCard word="NEVER LOSE A WORD." size={120} />
      </Scene>
      <Scene from={T.historyClip} durationInFrames={T.mgPrivate - T.historyClip}>
        <ClipSlot src={CLIPS.history} label="local history — re-paste any transcript" dim={0.3} />
      </Scene>
      <Scene from={T.mgPrivate} durationInFrames={T.mgInstant - T.mgPrivate}>
        <WordCard word="PRIVATE." size={170} />
      </Scene>
      <Scene from={T.mgInstant} durationInFrames={T.mgNative - T.mgInstant}>
        <WordCard word="INSTANT." size={170} />
      </Scene>
      <Scene from={T.mgNative} durationInFrames={T.mgFree - T.mgNative}>
        <WordCard word="NATIVE." size={170} />
      </Scene>
      <Scene from={T.mgFree} durationInFrames={T.logo - T.mgFree}>
        <WordCard word="FREE." accent size={200} />
      </Scene>

      {/* ---- End lockup (rides the fade tail) ---- */}
      <Scene from={T.logo} durationInFrames={T.end - T.logo}>
        <Logo />
      </Scene>

      <Grain />
    </AbsoluteFill>
  );
};
