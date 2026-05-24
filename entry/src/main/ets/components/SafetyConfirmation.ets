import { COLOR_SAFE_BUTTON, COLOR_STATUS_TEXT, COLOR_RISK_RED } from '../constants/AppConstants';

@ComponentV2
export struct SafetyConfirmation {
  @Param timerActive: boolean = false;
  @Param timerRemaining: number = 0;
  @Param smsSent: boolean = false;
  @Event onSafeConfirmed: () => void = () => {};
  @Local private isSafeConfirmed: boolean = false;

  build() {
    Column() {
      if (this.timerActive) {
        Text(`${Math.ceil(this.timerRemaining / 1000)}s`)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_RISK_RED)
          .margin({ bottom: 4 })

        Text('Confirm your safety or emergency SMS will be sent')
          .fontSize(12)
          .fontColor(COLOR_STATUS_TEXT)
          .opacity(0.7)
          .margin({ bottom: 12 })
      }

      Button("I'm Safe")
        .type(ButtonType.Capsule)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('70%')
        .height(48)
        .backgroundColor(COLOR_SAFE_BUTTON)
        .fontColor(COLOR_STATUS_TEXT)
        .margin({ top: 20 })
        .onClick(() => {
          this.isSafeConfirmed = true;
          this.onSafeConfirmed();
        })

      if (this.isSafeConfirmed) {
        Text('Safety confirmation recorded')
          .fontSize(13)
          .fontColor(COLOR_SAFE_BUTTON)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 })
      }

      if (this.smsSent) {
        Text('Emergency SMS has been triggered')
          .fontSize(13)
          .fontColor(COLOR_RISK_RED)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}
