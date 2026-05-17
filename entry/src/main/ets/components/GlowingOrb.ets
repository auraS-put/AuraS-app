import { RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { getGlowColor } from '../utils/RiskLevelUtils';
import {
  ORB_RINGS, OrbRingConfig, ORB_ANIM_DURATION,
  ORB_CENTER_SIZE, ORB_CENTER_OPACITY, COLOR_ORB_CENTER
} from '../constants/AppConstants';

@ComponentV2
export struct GlowingOrb {
  @Param riskLevel: RiskLevel = RiskLevel.GREEN;
  @Param animStarted: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(ORB_RINGS, (ring: OrbRingConfig) => {
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
        .width(ORB_CENTER_SIZE)
        .height(ORB_CENTER_SIZE)
        .borderRadius(ORB_CENTER_SIZE / 2)
        .backgroundColor(COLOR_ORB_CENTER)
        .opacity(ORB_CENTER_OPACITY)
    }
    .width(300)
    .height(300)
  }
}
