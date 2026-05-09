import { EEGRiskViewModel, EEGMetrics, getEEGRiskViewModel, RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { getStatusText, riskLevelToSimulationMode } from '../utils/RiskLevelUtils';
import { getGlowColor } from '../utils/RiskLevelUtils';
import {
  COLOR_BACKGROUND, COLOR_TITLE, COLOR_STATUS_TEXT,
  WAVEFORM_UPDATE_INTERVAL_MS, WAVEFORM_MAX_POINTS,
  ANIM_START_DELAY_MS
} from '../constants/AppConstants';
import { GlowingOrb } from '../components/GlowingOrb';
import { SafetyConfirmation } from '../components/SafetyConfirmation';
import { EEGWaveformChart } from '../components/EEGWaveformChart';

const DEBUG_FORCE_EEG_STATE: RiskLevel | null = null;

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
    this.riskLevel = this.viewModel.getRiskLevel();
    this.viewModel.onRiskLevelChanged((level: RiskLevel) => {
      this.riskLevel = level;
    });
    this.applyDebugStateOverride();

    // Initialize AI model, then start EEG monitoring
    const resMgr = getContext(this).resourceManager;
    this.viewModel.initModel(resMgr).then((success: boolean) => {
      if (success) {
        console.info('[Index] AI model loaded — starting monitoring');
      } else {
        console.error('[Index] AI model failed — monitoring with fallback');
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
    this.viewModel.setSimulationMode(riskLevelToSimulationMode(DEBUG_FORCE_EEG_STATE));
    this.viewModel.clearBuffers();
  }

  build() {
    Column() {
      // App title + AI status
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
            .fill(this.modelLoaded ? (this.previewMode ? '#E8A844' : '#44E88C') : '#555577')
          Text(this.modelLoaded ? (this.previewMode ? 'AI Preview' : 'AI Active') : 'AI Loading...')
            .fontSize(10)
            .fontColor(this.modelLoaded ? (this.previewMode ? '#E8A844' : '#44E88C') : '#555577')
        }
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
        SafetyConfirmation()
      }

      // Spacer
      Column() {}
        .layoutWeight(1)

      // EEG waveform
      EEGWaveformChart({ riskLevel: this.riskLevel, waveformData: this.waveformData })
        .margin({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}