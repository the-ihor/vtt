import { Composition, Still } from "remotion";
import { HeroVideo } from "./HeroVideo";
import { LogoGif } from "./LogoGif";
import { SubscriptionArt } from "./SubscriptionArt";
import { APPSTORE_SHOTS, APPSTORE_SHOTS_UA, SHOT_SIZE } from "./appstore/AppStoreShots";
import { GALLERY, GALLERY_SIZE } from "./gallery/GallerySlides";
import { FPS, f } from "./theme";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="HeroVideo"
        component={HeroVideo}
        durationInFrames={f(43.0)}
        fps={FPS}
        width={1920}
        height={1080}
      />
      <Composition
        id="LogoGif"
        component={LogoGif}
        durationInFrames={f(3.0)}
        fps={FPS}
        width={240}
        height={240}
      />
      <Still
        id="SubscriptionArt"
        component={SubscriptionArt}
        width={1024}
        height={1024}
      />
      {APPSTORE_SHOTS.map((Comp, i) => (
        <Still
          key={`as-${i}`}
          id={`AppStore0${i + 1}`}
          component={Comp}
          width={SHOT_SIZE.width}
          height={SHOT_SIZE.height}
        />
      ))}
      {APPSTORE_SHOTS_UA.map((Comp, i) => (
        <Still
          key={`asua-${i}`}
          id={`AppStoreUA0${i + 1}`}
          component={Comp}
          width={SHOT_SIZE.width}
          height={SHOT_SIZE.height}
        />
      ))}
      {GALLERY.map((Comp, i) => (
        <Still
          key={i}
          id={`Gallery0${i + 1}`}
          component={Comp}
          width={GALLERY_SIZE.width}
          height={GALLERY_SIZE.height}
        />
      ))}
    </>
  );
};
