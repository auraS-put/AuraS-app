import { router } from '@kit.ArkUI';
import {
  getEmergencyContactStore, EmergencyContact
} from '../services/EmergencyContactStore';
import { COLOR_BACKGROUND, COLOR_STATUS_TEXT, COLOR_TITLE } from '../constants/AppConstants';
import {
  PAGE_PADDING_HORIZONTAL, PAGE_PADDING_TOP,
  FONT_SIZE_HEADING, FONT_SIZE_BODY_SMALL, FONT_SIZE_ICON,
  LIST_ITEM_SPACE
} from '../constants/UIConstants';
import { ContactFormInput } from '../components/ContactFormInput';
import { ContactListItem } from '../components/ContactListItem';
import { Logger } from '../utils/Logger';

const log = new Logger('EmergencyContactsPage');

@Entry
@ComponentV2
struct EmergencyContactsPage {
  @Local private contacts: EmergencyContact[] = [];
  @Local private inputName: string = '';
  @Local private inputPhone: string = '';
  @Local private errorMessage: string = '';

  aboutToAppear(): void {
    this.loadContacts();
  }

  private async loadContacts(): Promise<void> {
    this.contacts = await getEmergencyContactStore().getAll();
  }

  private async addContact(): Promise<void> {
    this.errorMessage = '';

    if (!this.inputName.trim()) {
      this.errorMessage = 'Please enter a name';
      return;
    }
    if (!this.inputPhone.trim()) {
      this.errorMessage = 'Please enter a phone number';
      return;
    }

    const success = await getEmergencyContactStore().add(this.inputName, this.inputPhone);
    if (success) {
      this.inputName = '';
      this.inputPhone = '';
      await this.loadContacts();
      log.info('Contact added successfully');
    } else {
      this.errorMessage = 'Invalid number or contact already exists';
    }
  }

  private async removeContact(id: string): Promise<void> {
    await getEmergencyContactStore().remove(id);
    await this.loadContacts();
    log.info('Contact removed:', id);
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(FONT_SIZE_ICON)
          .fontColor(COLOR_STATUS_TEXT)
          .onClick(() => {
            router.back();
          })
          .padding({ right: 16 })

        Text('Emergency Contacts')
          .fontSize(FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_STATUS_TEXT)
      }
      .width('100%')
      .padding({ top: PAGE_PADDING_TOP, left: PAGE_PADDING_HORIZONTAL, right: PAGE_PADDING_HORIZONTAL, bottom: 16 })

      ContactFormInput({
        inputName: this.inputName,
        inputPhone: this.inputPhone,
        errorMessage: this.errorMessage,
        onNameChange: (value: string) => { this.inputName = value; },
        onPhoneChange: (value: string) => { this.inputPhone = value; },
        onSubmit: () => { this.addContact(); }
      })
        .padding({ left: PAGE_PADDING_HORIZONTAL, right: PAGE_PADDING_HORIZONTAL })

        if (this.contacts.length === 0) {
        Text('No emergency contacts added yet')
          .fontSize(FONT_SIZE_BODY_SMALL)
          .fontColor(COLOR_TITLE)
          .margin({ top: 32 })
      } else {
        List({ space: LIST_ITEM_SPACE }) {
          ForEach(this.contacts, (contact: EmergencyContact) => {
            ListItem() {
              ContactListItem({
                contact: contact,
                onDelete: (id: string) => { this.removeContact(id); }
              })
            }
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: PAGE_PADDING_HORIZONTAL, right: PAGE_PADDING_HORIZONTAL, top: 16 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }
}
