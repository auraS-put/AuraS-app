import { RiskLevel, OrbRingConfig, ORB_ANIM_DURATION, COLOR_ORB_CENTER } from '../constants/AppConstants';
import { getGlowColor } from '../utils/RiskLevelUtils';
import {
  WATCH_ORB_RINGS, WATCH_ORB_CONTAINER_SIZE,
  WATCH_ORB_CENTER_SIZE, WATCH_ORB_CENTER_OPACITY
} from '../constants/WatchConstants';

@ComponentV2
export struct WatchGlowingOrb {
  @Param riskLevel: RiskLevel = RiskLevel.GREEN;
  @Param animStarted: boolean = false;
  @Event onOrbTapped: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(WATCH_ORB_RINGS, (ring: OrbRingConfig) => {
        Row() {}
          .width(ring.size)
          .height(ring.size)
          .borderRadius(ring.size / 2)
          .backgroundColor(getGlowColor(this.riskLevel))
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .opacity(this.animStarted ? ring.opacityAnimated : ring.opacityInitial)
          .scale({ x: this.animStarted ? ring.scale : 1.0, y: this.animStarted ? ring.scale : 1.0 })
          .animation({
            duration: ORB_ANIM_DURATION,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate,
            delay: ring.delay
          })
      }, (ring: OrbRingConfig) => ring.size.toString())

      Row() {}
        .width(WATCH_ORB_CENTER_SIZE)
        .height(WATCH_ORB_CENTER_SIZE)
        .borderRadius(WATCH_ORB_CENTER_SIZE / 2)
        .backgroundColor(COLOR_ORB_CENTER)
        .opacity(WATCH_ORB_CENTER_OPACITY)
    }
    .width(WATCH_ORB_CONTAINER_SIZE)
    .height(WATCH_ORB_CONTAINER_SIZE)
    .onClick(() => {
      this.onOrbTapped();
    })
  }
}
