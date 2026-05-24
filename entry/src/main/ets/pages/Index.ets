import { EEGRiskViewModel, EEGMetrics, getEEGRiskViewModel } from '../viewmodel/EEGRiskViewModel';
import { RiskLevel } from '../constants/AppConstants';
import { getStatusText, getGlowColor } from '../utils/RiskLevelUtils';
import {
  COLOR_BACKGROUND, COLOR_TITLE, COLOR_STATUS_TEXT, COLOR_RISK_ORANGE,
  COLOR_RISK_GREEN, COLOR_TIME_LABEL, COLOR_BUTTON_DISABLED, COLOR_TEXT_DISABLED,
  WAVEFORM_UPDATE_INTERVAL_MS, WAVEFORM_MAX_POINTS,
  ANIM_START_DELAY_MS
} from '../constants/AppConstants';
import { GlowingOrb } from '../components/GlowingOrb';
import { SafetyConfirmation } from '../components/SafetyConfirmation';
import { EEGWaveformChart } from '../components/EEGWaveformChart';
import { getLocationService } from '../services/LocationService';
import { getEmergencySMSService } from '../services/EmergencySMSService';
import { initEmergencyContactStore } from '../services/EmergencyContactStore';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';

const log = new Logger('Index');

const DEBUG_FORCE_EEG_STATE: RiskLevel | null = RiskLevel.RED;

@Entry
@ComponentV2
struct Index {
  @Local private viewModel: EEGRiskViewModel = getEEGRiskViewModel();
  @Local private riskLevel: RiskLevel = DEBUG_FORCE_EEG_STATE ?? RiskLevel.GREEN;
  @Local private seizureProbability: number = 0;
  @Local private modelLoaded: boolean = false;
  @Local private previewMode: boolean = false;
  @Local private waveformData: number[] = [];
  @Local private animStarted: boolean = false;
  private waveformTimer: number | null = null;
  private metricsTimer: number | null = null;

  aboutToAppear(): void {
    // Initialize services that need Context
    const context = getContext(this) as common.UIAbilityContext;
    initEmergencyContactStore(context);
    getLocationService().setContext(context);
    getEmergencySMSService().setContext(context);

    // Proactively request location permission
    getLocationService().getCurrentLocation();

    this.riskLevel = this.viewModel.getRiskLevel();
    this.viewModel.onRiskLevelChanged((level: RiskLevel) => {
      this.riskLevel = level;
    });
    this.applyDebugStateOverride();

    // Initialize AI model, then start EEG monitoring
    const resMgr = context.resourceManager;
    this.viewModel.initModel(resMgr).then((success: boolean) => {
      if (success) {
        log.info('AI model loaded — starting monitoring');
      } else {
        log.error('AI model failed — monitoring with fallback');
      }
      this.viewModel.startMonitoring();
    });

    this.waveformTimer = setInterval(() => {
      this.waveformData = this.viewModel.getWaveformData(WAVEFORM_MAX_POINTS);
    }, WAVEFORM_UPDATE_INTERVAL_MS);

    // Poll AI metrics for reactive UI updates
    this.metricsTimer = setInterval(() => {
      const metrics: EEGMetrics = this.viewModel.getMetrics();
      this.seizureProbability = metrics.seizureProbability;
      this.modelLoaded = metrics.modelLoaded;
      this.previewMode = metrics.previewMode;
    }, 500);

    setTimeout(() => {
      this.animStarted = true;
    }, ANIM_START_DELAY_MS);
  }

  aboutToDisappear(): void {
    this.viewModel.onRiskLevelChanged(() => {});
    this.viewModel.stopMonitoring();
    if (this.waveformTimer !== null) {
      clearInterval(this.waveformTimer);
      this.waveformTimer = null;
    }
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
    Scroll() {
    Column() {
      // App title + AI status + contacts button
      Row() {
        Text('auras')
          .fontSize(16)
          .fontColor(COLOR_TITLE)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(2)

        Column() {}.layoutWeight(1)

        // AI model status indicator
        Row({ space: 4 }) {
          Circle({ width: 6, height: 6 })
            .fill(this.modelLoaded ? (this.previewMode ? COLOR_RISK_ORANGE : COLOR_RISK_GREEN) : COLOR_TIME_LABEL)
          Text(this.modelLoaded ? (this.previewMode ? 'AI Preview' : 'AI Active') : 'AI Loading...')
            .fontSize(10)
            .fontColor(this.modelLoaded ? (this.previewMode ? COLOR_RISK_ORANGE : COLOR_RISK_GREEN) : COLOR_TIME_LABEL)
        }

        Text('☰')
          .fontSize(20)
          .fontColor(COLOR_TITLE)
          .margin({ left: 12 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/EmergencyContactsPage' });
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .margin({ top: 48 })

      // Glowing orb area
      GlowingOrb({ riskLevel: this.riskLevel, animStarted: this.animStarted })
        .margin({ top: 40 })

      // Status text
      Text(getStatusText(this.riskLevel))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_STATUS_TEXT)
        .margin({ top: 28 })

      // Seizure probability indicator
      if (this.modelLoaded) {
        Column({ space: 6 }) {
          Text(`${(this.seizureProbability * 100).toFixed(1)}%`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(getGlowColor(this.riskLevel))

          Text('Seizure Probability')
            .fontSize(12)
            .fontColor(COLOR_TITLE)
        }
        .margin({ top: 12 })
      }

      if (this.riskLevel === RiskLevel.RED) {
        SafetyConfirmation({
          timerActive: this.viewModel.safetyTimerActive,
          timerRemaining: this.viewModel.safetyTimerRemaining,
          smsSent: this.viewModel.smsSent,
          onSafeConfirmed: () => {
            this.viewModel.confirmSafety();
          }
        })
      }

      if (this.riskLevel !== RiskLevel.GREEN) {
        Button('Notify Caregivers')
          .type(ButtonType.Capsule)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .width('60%')
          .height(40)
          .backgroundColor(this.viewModel.smsSent ? COLOR_BUTTON_DISABLED : COLOR_RISK_ORANGE)
          .fontColor(this.viewModel.smsSent ? COLOR_TEXT_DISABLED : COLOR_STATUS_TEXT)
          .enabled(!this.viewModel.smsSent)
          .margin({ top: 12 })
          .onClick(() => {
            this.viewModel.sendCaregiverSmsOnDemand();
          })
      }

      // Spacer
      Column() {}
        .layoutWeight(1)

      // EEG waveform
      if ( this.riskLevel !== RiskLevel.RED )
      EEGWaveformChart({ riskLevel: this.riskLevel, waveformData: this.waveformData })
        .margin({ bottom: 32 })
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .backgroundColor(COLOR_BACKGROUND)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Fade)
  }
}