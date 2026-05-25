import {
  COLOR_STATUS_TEXT, COLOR_TITLE, COLOR_RISK_RED,
  COLOR_SAFE_BUTTON
} from '../constants/AppConstants';
import {
  COLOR_CARD_BACKGROUND, INPUT_HEIGHT, INPUT_GAP,
  CARD_BORDER_RADIUS, FONT_SIZE_BODY_SMALL,
  FONT_SIZE_LABEL, BUTTON_HEIGHT
} from '../constants/UIConstants';

@ComponentV2
export struct ContactFormInput {
  @Param inputName: string = '';
  @Param inputPhone: string = '';
  @Param errorMessage: string = '';
  @Event onNameChange: (value: string) => void = () => {};
  @Event onPhoneChange: (value: string) => void = () => {};
  @Event onSubmit: () => void = () => {};

  build() {
    Column() {
      TextInput({ placeholder: 'Name', text: this.inputName })
        .onChange((value: string) => { this.onNameChange(value); })
        .fontSize(FONT_SIZE_BODY_SMALL)
        .fontColor(COLOR_STATUS_TEXT)
        .placeholderColor(COLOR_TITLE)
        .backgroundColor(COLOR_CARD_BACKGROUND)
        .borderRadius(CARD_BORDER_RADIUS)
        .height(INPUT_HEIGHT)
        .width('100%')

      TextInput({ placeholder: 'Phone number (e.g. +48123456789)', text: this.inputPhone })
        .onChange((value: string) => { this.onPhoneChange(value); })
        .type(InputType.PhoneNumber)
        .fontSize(FONT_SIZE_BODY_SMALL)
        .fontColor(COLOR_STATUS_TEXT)
        .placeholderColor(COLOR_TITLE)
        .backgroundColor(COLOR_CARD_BACKGROUND)
        .borderRadius(CARD_BORDER_RADIUS)
        .height(INPUT_HEIGHT)
        .width('100%')
        .margin({ top: INPUT_GAP })

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(FONT_SIZE_LABEL)
          .fontColor(COLOR_RISK_RED)
          .margin({ top: 4 })
      }

      Button('Add Contact')
        .type(ButtonType.Capsule)
        .fontSize(FONT_SIZE_BODY_SMALL)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(COLOR_SAFE_BUTTON)
        .fontColor(COLOR_STATUS_TEXT)
        .width('100%')
        .height(BUTTON_HEIGHT)
        .margin({ top: 12 })
        .onClick(() => {
          this.onSubmit();
        })
    }
  }
}
