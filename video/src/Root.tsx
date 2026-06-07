import { Composition } from "remotion";
import { HeroVideo } from "./HeroVideo";
import { FPS, f } from "./theme";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="HeroVideo"
      component={HeroVideo}
      durationInFrames={f(43.0)}
      fps={FPS}
      width={1920}
      height={1080}
    />
  );
};
