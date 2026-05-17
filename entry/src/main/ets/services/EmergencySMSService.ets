import { common, Want } from '@kit.AbilityKit';
import { EMERGENCY_SMS_PREFIX } from '../constants/AppConstants';
import { getEmergencyContactStore } from './EmergencyContactStore';
import { getLocationService, LocationResult } from './LocationService';
import { Logger } from '../utils/Logger';

const log = new Logger('EmergencySMSService');

export class EmergencySMSService {
  private context: common.UIAbilityContext | null = null;

  constructor() {
    log.info('Initialized');
  }

  public setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  public async sendEmergencySMS(): Promise<void> {
    if (!this.context) {
      log.error('Context not set, cannot send SMS');
      return;
    }

    const contacts = await getEmergencyContactStore().getAll();
    if (contacts.length === 0) {
      log.warn('No emergency contacts configured');
      return;
    }

    const locationService = getLocationService();
    const location = await locationService.getCurrentLocation();
    const message = this.buildMessage(location);
    const recipients = contacts.map(c => c.phone).join(';');

    await this.openSMSComposer(recipients, message);
  }

  private buildMessage(location: LocationResult | null): string {
    const locationService = getLocationService();
    let text = `${EMERGENCY_SMS_PREFIX} High seizure risk detected. Safety was not confirmed within the timeout period.`;

    if (location) {
      const mapsUrl = locationService.buildMapsUrl(location);
      text += `\nLocation: ${mapsUrl}`;
    } else {
      text += '\nLocation: unavailable';
    }

    return text;
  }

  private async openSMSComposer(recipients: string, message: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.sendData',
      uri: `smsto:${recipients}`,
      parameters: {
        sms_body: message
      }
    };

    try {
      await this.context!.startAbility(want);
      log.info('SMS composer opened for:', recipients);
    } catch (err) {
      log.error('Failed to open SMS composer:', JSON.stringify(err));
    }
  }
}

let emergencySMSServiceInstance: EmergencySMSService | null = null;

export function getEmergencySMSService(): EmergencySMSService {
  if (!emergencySMSServiceInstance) {
    emergencySMSServiceInstance = new EmergencySMSService();
  }
  return emergencySMSServiceInstance;
}
