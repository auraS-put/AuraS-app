import { RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { getGlowColor, formatTimeLabel } from '../utils/RiskLevelUtils';
import { COLOR_TIME_LABEL } from '../constants/AppConstants';

@ComponentV2
export struct EEGWaveformChart {
  @Param riskLevel: RiskLevel = RiskLevel.GREEN;
  @Param waveformData: number[] = [];

  private waveformSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private waveformCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.waveformSettings);

  @Monitor('waveformData')
  onWaveformDataChanged(): void {
    this.drawWaveform();
  }

  private drawWaveform(): void {
    const ctx = this.waveformCtx;
    const data = this.waveformData;
    const w = ctx.width;
    const h = ctx.height;

    ctx.clearRect(0, 0, w, h);

    if (data.length < 2) {
      return;
    }

    const maxAbs = Math.max(1, ...data.map((v: number) => Math.abs(v)));
    const midY = h * 0.5;
    const scaleY = (h * 0.4) / maxAbs;
    const stepX = w / (data.length - 1);

    ctx.beginPath();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = getGlowColor(this.riskLevel);
    ctx.globalAlpha = 0.8;

    for (let i = 0; i < data.length; i++) {
      const x = i * stepX;
      const y = midY - data[i] * scaleY;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();
    ctx.globalAlpha = 1.0;
  }

  build() {
    Column() {
      Canvas(this.waveformCtx)
        .width('100%')
        .height(100)
        .onReady(() => {
          this.drawWaveform();
        })
        .onAreaChange(() => {
          this.drawWaveform();
        })

      Row() {
        Text(formatTimeLabel(8))
          .fontSize(10)
          .fontColor(COLOR_TIME_LABEL)
        Column() {}.layoutWeight(1)
        Text(formatTimeLabel(5))
          .fontSize(10)
          .fontColor(COLOR_TIME_LABEL)
        Column() {}.layoutWeight(1)
        Text(formatTimeLabel(3))
          .fontSize(10)
          .fontColor(COLOR_TIME_LABEL)
        Column() {}.layoutWeight(1)
        Text(formatTimeLabel(1))
          .fontSize(10)
          .fontColor(COLOR_TIME_LABEL)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}
