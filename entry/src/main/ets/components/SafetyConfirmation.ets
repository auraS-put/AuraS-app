import { COLOR_SAFE_BUTTON, COLOR_STATUS_TEXT } from '../constants/AppConstants';

@ComponentV2
export struct SafetyConfirmation {
  @Local private isSafeConfirmed: boolean = false;

  build() {
    Column() {
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
        })

      if (this.isSafeConfirmed) {
        Text('Safety confirmation recorded')
          .fontSize(13)
          .fontColor(COLOR_SAFE_BUTTON)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}
