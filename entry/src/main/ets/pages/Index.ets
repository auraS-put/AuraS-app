import { EEGRiskViewModel, getEEGRiskViewModel, RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { getStatusText, riskLevelToSimulationMode } from '../utils/RiskLevelUtils';
import {
  COLOR_BACKGROUND, COLOR_TITLE, COLOR_STATUS_TEXT,
  WAVEFORM_UPDATE_INTERVAL_MS, WAVEFORM_MAX_POINTS,
  ANIM_START_DELAY_MS
} from '../constants/AppConstants';
import { GlowingOrb } from '../components/GlowingOrb';
import { SafetyConfirmation } from '../components/SafetyConfirmation';
import { EEGWaveformChart } from '../components/EEGWaveformChart';

const DEBUG_FORCE_EEG_STATE: RiskLevel | null = RiskLevel.RED;

@Entry
@ComponentV2
struct Index {
  @Local private viewModel: EEGRiskViewModel = getEEGRiskViewModel();
  @Local private riskLevel: RiskLevel = DEBUG_FORCE_EEG_STATE ?? RiskLevel.RED;
  @Local private waveformData: number[] = [];
  @Local private animStarted: boolean = false;
  private waveformTimer: number | null = null;

  aboutToAppear(): void {
    this.riskLevel = this.viewModel.getRiskLevel();
    this.viewModel.onRiskLevelChanged((level: RiskLevel) => {
      this.riskLevel = level;
    });
    this.applyDebugStateOverride();
    this.viewModel.startMonitoring();
    this.waveformTimer = setInterval(() => {
      this.waveformData = this.viewModel.getWaveformData(WAVEFORM_MAX_POINTS);
    }, WAVEFORM_UPDATE_INTERVAL_MS);
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
      // App title
      Text('auras')
        .fontSize(16)
        .fontColor(COLOR_TITLE)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 48 })
        .letterSpacing(2)

      // Glowing orb area
      GlowingOrb({ riskLevel: this.riskLevel, animStarted: this.animStarted })
        .margin({ top: 40 })

      // Status text
      Text(getStatusText(this.riskLevel))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_STATUS_TEXT)
        .margin({ top: 28 })

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