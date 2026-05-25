import { EEGRiskViewModel, EEGMetrics, getEEGRiskViewModel } from '../viewmodel/EEGRiskViewModel';
import { RiskLevel, COLOR_BACKGROUND, COLOR_STATUS_TEXT, COLOR_RISK_RED,
  COLOR_RISK_ORANGE, COLOR_SAFE_BUTTON, COLOR_TITLE, ANIM_START_DELAY_MS
} from '../constants/AppConstants';
import { WATCH_FONT_STATUS, WATCH_FONT_COUNTDOWN, WATCH_FONT_BUTTON,
  WATCH_FONT_TITLE, WATCH_BUTTON_HEIGHT, WATCH_BUTTON_WIDTH, WATCH_BUTTON_RADIUS
} from '../constants/WatchConstants';
import { getStatusText, getGlowColor } from '../utils/RiskLevelUtils';
import { WatchGlowingOrb } from '../components/WatchGlowingOrb';
import { getLocationService } from '../services/LocationService';
import { getEmergencySMSService } from '../services/EmergencySMSService';
import { initEmergencyContactStore } from '../services/EmergencyContactStore';
import { common } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';

function getWatchStatusText(riskLevel: RiskLevel): string {
  switch (riskLevel) {
    case RiskLevel.GREEN: return 'All Clear';
    case RiskLevel.ORANGE: return 'Watchful';
    case RiskLevel.RED: return 'Attention';
    default: return 'All Clear';
  }
}

const log = new Logger('WatchHomePage');

const DEBUG_FORCE_EEG_STATE: RiskLevel | null = RiskLevel.RED;

@Entry
@ComponentV2
struct WatchHomePage {
  @Local private viewModel: EEGRiskViewModel = getEEGRiskViewModel();
  @Local private riskLevel: RiskLevel = DEBUG_FORCE_EEG_STATE ?? RiskLevel.GREEN;
  @Local private seizureProbability: number = 0;
  @Local private animStarted: boolean = false;
  private scroller: Scroller = new Scroller();
  private metricsTimer: number | null = null;

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    initEmergencyContactStore(context);
    getLocationService().setContext(context);
    getEmergencySMSService().setContext(context);
    getLocationService().getCurrentLocation();

    this.riskLevel = this.viewModel.getRiskLevel();
    this.viewModel.onRiskLevelChanged((level: RiskLevel) => {
      this.riskLevel = level;
      // Auto-show actions on RED, reset on GREEN
      if (level === RiskLevel.RED) {
        this.scroller.scrollEdge(Edge.Bottom);
      }
    });
    this.applyDebugStateOverride();

    const resMgr = context.resourceManager;
    this.viewModel.initModel(resMgr).then(() => {
      this.viewModel.startMonitoring();
    });

    this.metricsTimer = setInterval(() => {
      const metrics: EEGMetrics = this.viewModel.getMetrics();
      this.seizureProbability = metrics.seizureProbability;
    }, 500);

    setTimeout(() => {
      this.animStarted = true;
    }, ANIM_START_DELAY_MS);
  }

  aboutToDisappear(): void {
    this.viewModel.onRiskLevelChanged(() => {});
    this.viewModel.stopMonitoring();
    if (this.metricsTimer !== null) {
      clearInterval(this.metricsTimer);
      this.metricsTimer = null;
    }
  }

  private applyDebugStateOverride(): void {
    if (DEBUG_FORCE_EEG_STATE === null) {
      return;
    }
    this.viewModel.setDebugLock(DEBUG_FORCE_EEG_STATE);
    this.viewModel.clearBuffers();
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        // ── Screen 1: Orb centered ──
        Column() {
          Text('auras')
            .fontSize(WATCH_FONT_TITLE)
            .fontColor(COLOR_TITLE)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(2)
            .margin({ top: 12 })

          Column() {}
            .layoutWeight(1)

          WatchGlowingOrb({
            riskLevel: this.riskLevel,
            animStarted: this.animStarted,
            onOrbTapped: () => {
              this.scroller.scrollEdge(Edge.Bottom);
            }
          })

          Column() {}
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)

        // ── Screen 2: Status + Actions (scroll down) ──
        Column() {
          Text(getWatchStatusText(this.riskLevel))
            .fontSize(WATCH_FONT_STATUS)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_STATUS_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 24 })

          if (this.riskLevel === RiskLevel.RED) {
            this.RedStateActions()
          }

          if (this.riskLevel !== RiskLevel.RED) {
            Button('Notify Caregivers')
              .type(ButtonType.Capsule)
              .fontSize(WATCH_FONT_BUTTON)
              .fontWeight(FontWeight.Medium)
              .width(WATCH_BUTTON_WIDTH)
              .height(WATCH_BUTTON_HEIGHT)
              .backgroundColor(COLOR_RISK_ORANGE)
              .fontColor(COLOR_STATUS_TEXT)
              .margin({ top: 12 })
              .onClick(() => {
                this.viewModel.sendCaregiverSmsOnDemand();
              })
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Fade)
  }

  @Builder
  RedStateActions() {
    // Countdown timer
    if (this.viewModel.safetyTimerActive) {
      Text(`${Math.ceil(this.viewModel.safetyTimerRemaining / 1000)}s`)
        .fontSize(WATCH_FONT_COUNTDOWN)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_RISK_RED)
        .margin({ top: 2 })
    }

    // I'm Safe button
    if (!this.viewModel.smsSent) {
      Button("I'm Safe")
        .type(ButtonType.Capsule)
        .fontSize(WATCH_FONT_BUTTON)
        .fontWeight(FontWeight.Bold)
        .width(WATCH_BUTTON_WIDTH)
        .height(WATCH_BUTTON_HEIGHT)
        .backgroundColor(COLOR_SAFE_BUTTON)
        .fontColor(COLOR_STATUS_TEXT)
        .margin({ top: 6 })
        .onClick(() => {
          this.viewModel.confirmSafety();
        })
    }

    // Notify Caregivers button
    Button('Notify Caregivers')
      .type(ButtonType.Capsule)
      .fontSize(WATCH_FONT_BUTTON)
      .fontWeight(FontWeight.Medium)
      .width(WATCH_BUTTON_WIDTH)
      .height(WATCH_BUTTON_HEIGHT)
      .backgroundColor(this.viewModel.smsSent ? '#333344' : COLOR_RISK_ORANGE)
      .fontColor(this.viewModel.smsSent ? '#666688' : COLOR_STATUS_TEXT)
      .enabled(!this.viewModel.smsSent)
      .margin({ top: 4 })
      .onClick(() => {
        this.viewModel.sendCaregiverSmsOnDemand();
      })
  }
}
