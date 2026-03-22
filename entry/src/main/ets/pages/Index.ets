import { EEGRiskViewModel, getEEGRiskViewModel, RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { EEGSimulationMode } from '../services/MockEEGService';

// Debug override for quick UI testing from this file.
// Set to RiskLevel.GREEN / RiskLevel.ORANGE / RiskLevel.RED, or null to disable override.
const DEBUG_FORCE_EEG_STATE: RiskLevel | null = RiskLevel.GREEN;

@Entry
@ComponentV2
struct Index {
  @Local private viewModel: EEGRiskViewModel = getEEGRiskViewModel();
  @Local private riskLevel: RiskLevel = RiskLevel.GREEN;
  @Local private isSafeConfirmed: boolean = false;

  aboutToAppear(): void {
    this.riskLevel = this.viewModel.getRiskLevel();
    this.viewModel.onRiskLevelChanged((level: RiskLevel) => {
      this.riskLevel = level;
      if (level !== RiskLevel.RED) {
        this.isSafeConfirmed = false;
      }
    });
    this.applyDebugStateOverride();
    this.viewModel.startMonitoring();
  }

  aboutToDisappear(): void {
    this.viewModel.onRiskLevelChanged(() => {
    });
    this.viewModel.stopMonitoring();
  }

  private applyDebugStateOverride(): void {
    if (DEBUG_FORCE_EEG_STATE === null) {
      return;
    }

    let forcedMode: EEGSimulationMode = EEGSimulationMode.NORMAL;
    switch (DEBUG_FORCE_EEG_STATE) {
      case RiskLevel.GREEN:
        forcedMode = EEGSimulationMode.NORMAL;
        break;
      case RiskLevel.ORANGE:
        forcedMode = EEGSimulationMode.MODERATE;
        break;
      case RiskLevel.RED:
        forcedMode = EEGSimulationMode.SEIZURE;
        break;
      default:
        forcedMode = EEGSimulationMode.NORMAL;
    }

    this.viewModel.setSimulationMode(forcedMode);
    this.viewModel.clearBuffers();
  }

  private ringMainColor(): string {
    switch (this.riskLevel) {
      case RiskLevel.GREEN:
        return '#6EC49A';
      case RiskLevel.ORANGE:
        return '#E8BC7A';
      case RiskLevel.RED:
        return '#E2A6A6';
      default:
        return '#6EC49A';
    }
  }

  private statusHeadline(): string {
    switch (this.riskLevel) {
      case RiskLevel.GREEN:
        return 'Calm';
      case RiskLevel.ORANGE:
        return 'Watchful';
      case RiskLevel.RED:
        return 'Attention';
      default:
        return 'Calm';
    }
  }

  private statusCaption(): string {
    switch (this.riskLevel) {
      case RiskLevel.GREEN:
        return 'Stable neural rhythm with low variance.';
      case RiskLevel.ORANGE:
        return 'Mild irregular activity; continue close observation.';
      case RiskLevel.RED:
        return 'Persistent high-risk signature; safety confirmation protocol active.';
      default:
        return 'Stable neural rhythm with low variance.';
    }
  }

  private specialistInfo(): string {
    const metrics = this.viewModel.getMetrics();
    const currentAmplitude = Math.round(Math.abs(metrics.currentAmplitude) * 10) / 10;
    const anomalyCount = metrics.anomalyCount;

    switch (this.riskLevel) {
      case RiskLevel.GREEN:
        return `Amplitude ${currentAmplitude} uV, no destabilizing pattern in current window.`;
      case RiskLevel.ORANGE:
        return `Amplitude ${currentAmplitude} uV, ${anomalyCount} irregular events detected; enhanced observation advised.`;
      case RiskLevel.RED:
        return `Amplitude ${currentAmplitude} uV, sustained high-risk markers detected; patient safety protocol is active.`;
      default:
        return `Amplitude ${currentAmplitude} uV, monitoring in progress.`;
    }
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.Top }) {
        Row() {}
          .width(620)
          .height(620)
          .borderRadius(310)
          .backgroundColor(this.ringMainColor())
          .opacity(0.025)
          .margin({ top: -500 })

        Row() {}
          .width(560)
          .height(560)
          .borderRadius(280)
          .backgroundColor(this.ringMainColor())
          .opacity(0.04)
          .margin({ top: -470 })

        Row() {}
          .width(500)
          .height(500)
          .borderRadius(250)
          .backgroundColor(this.ringMainColor())
          .opacity(0.06)
          .margin({ top: -440 })

        Row() {}
          .width(450)
          .height(450)
          .borderRadius(225)
          .border({ width: 3, color: this.ringMainColor() })
          .opacity(0.2)
          .margin({ top: -415 })

        Row() {}
          .width(410)
          .height(410)
          .borderRadius(205)
          .border({ width: 8, color: this.ringMainColor() })
          .opacity(0.35)
          .margin({ top: -395 })
      }
      .width('100%')
      .height(225)
      .margin({ top: -8 })

      Column({ space: 8 }) {
        Text(this.statusHeadline())
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text(this.statusCaption())
          .fontSize(13)
          .fontColor('#5F6B7A')
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      .width('88%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 6 })

      Column({ space: 6 }) {
        Text('Additional information')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7A8494')

        Text(this.specialistInfo())
          .fontSize(12)
          .fontColor('#4B5563')
          .textAlign(TextAlign.Center)
          .maxLines(3)
      }
      .width('88%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor('#F8FAFC')
      .borderRadius(16)
      .margin({ top: 14 })

      if (this.riskLevel === RiskLevel.RED) {
        Button("I'm Safe")
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .width('84%')
          .height(50)
          .backgroundColor('#1A8A7E')
          .fontColor('#FFFFFF')
          .margin({ top: 18 })
          .onClick(() => {
            this.isSafeConfirmed = true;
          });
      }

      if (this.riskLevel === RiskLevel.RED && this.isSafeConfirmed) {
        Text('Safety confirmation recorded')
          .fontSize(13)
          .fontColor('#1A8A7E')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .padding({ top: 0, left: 16, right: 16, bottom: 24 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center);
  }
}