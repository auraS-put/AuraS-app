import { notificationManager } from '@kit.NotificationKit';
import {
  NOTIFICATION_COOLDOWN_MS,
  NOTIFICATION_ID_MODERATE,
  NOTIFICATION_ID_HIGH
} from '../constants/AppConstants';
import { Logger } from '../utils/Logger';

const log = new Logger('NotificationService');



export class NotificationService {
  private channelReady: boolean = false;
  private lastNotifyTimestamp: number = 0;

  constructor() {
    log.info('Initialized');
  }

  private async ensureChannel(): Promise<void> {
    if (this.channelReady) {
      return;
    }

    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      this.channelReady = true;
      log.info('Notification slot created');
    } catch (err) {
      log.error('Failed to create notification slot:', JSON.stringify(err));
    }
  }

  private isCooldownActive(): boolean {
    const now = Date.now();
    if (now - this.lastNotifyTimestamp < NOTIFICATION_COOLDOWN_MS) {
      return true;
    }
    this.lastNotifyTimestamp = now;
    return false;
  }

  public async notifyModerate(): Promise<void> {
    await this.ensureChannel();
    
    if (this.isCooldownActive()) {
      return;
    }

    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID_MODERATE,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: 'AuraS - Increased risk',
          text: 'Moderate risk of seizure detected. Monitor your condition.',
          additionalText: ''
        }
      },
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
    };

    try {
      await notificationManager.publish(request);
      log.info('Moderate notification published');
    } catch (err) {
      log.error('Failed to publish moderate notification:', JSON.stringify(err));
    }
  }

  public async notifyHigh(): Promise<void> {
    if (this.isCooldownActive()) {
      return;
    }

    await this.ensureChannel();

    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID_HIGH,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: 'AuraS - WARNING! High risk',
          text: 'High risk of seizure detected! Confirm your safety.',
          additionalText: ''
        }
      },
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
    };

    try {
      await notificationManager.publish(request);
      log.info('High notification published');
    } catch (err) {
      log.error('Failed to publish high notification:', JSON.stringify(err));
    }
  }

  public async cancelAll(): Promise<void> {
    try {
      await notificationManager.cancelAll();
      log.info('All notifications cancelled');
    } catch (err) {
      log.error('Failed to cancel notifications:', JSON.stringify(err));
    }
  }

  public resetCooldown(): void {
    this.lastNotifyTimestamp = 0;
  }
}

let notificationServiceInstance: NotificationService | null = null;

export function getNotificationService(): NotificationService {
  if (!notificationServiceInstance) {
    notificationServiceInstance = new NotificationService();
  }
  return notificationServiceInstance;
}
