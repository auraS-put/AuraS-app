import { EmergencyContact } from '../services/EmergencyContactStore';
import { COLOR_STATUS_TEXT, COLOR_TITLE, COLOR_RISK_RED } from '../constants/AppConstants';
import {
  COLOR_CARD_BACKGROUND, CARD_BORDER_RADIUS, CARD_PADDING,
  FONT_SIZE_BODY, FONT_SIZE_CAPTION, FONT_SIZE_DELETE,
  DELETE_BUTTON_PADDING
} from '../constants/UIConstants';

@ComponentV2
export struct ContactListItem {
  @Param contact: EmergencyContact = { id: '', name: '', phone: '' };
  @Event onDelete: (id: string) => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.contact.name)
          .fontSize(FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_STATUS_TEXT)

        Text(this.contact.phone)
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(COLOR_TITLE)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('✕')
        .fontSize(FONT_SIZE_DELETE)
        .fontColor(COLOR_RISK_RED)
        .onClick(() => {
          this.onDelete(this.contact.id);
        })
        .padding(DELETE_BUTTON_PADDING)
    }
    .width('100%')
    .padding(CARD_PADDING)
    .backgroundColor(COLOR_CARD_BACKGROUND)
    .borderRadius(CARD_BORDER_RADIUS)
  }
}
