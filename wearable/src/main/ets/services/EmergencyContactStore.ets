import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { EMERGENCY_CONTACTS_STORE_NAME } from '../constants/AppConstants';
import { Logger } from '../utils/Logger';

const log = new Logger('EmergencyContactStore');
const CONTACTS_KEY = 'contacts';

export interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
}

export class EmergencyContactStore {
  private store: preferences.Preferences | null = null;
  private context: Context;

  constructor(context: Context) {
    this.context = context;
    log.info('Initialized');
  }

  private async ensureStore(): Promise<preferences.Preferences> {
    if (!this.store) {
      try {
        this.store = await preferences.getPreferences(this.context, EMERGENCY_CONTACTS_STORE_NAME);
      } catch (err) {
        log.error('Failed to get preferences:', JSON.stringify(err));
        throw new Error('Failed to initialize preferences store');
      }
    }
    return this.store!;
  }

  public async getAll(): Promise<EmergencyContact[]> {
    try {
      const store = await this.ensureStore();
      const raw = await store.get(CONTACTS_KEY, '[]') as string;
      return JSON.parse(raw) as EmergencyContact[];
    } catch (err) {
      log.error('Failed to load contacts:', JSON.stringify(err));
      return [];
    }
  }

  public async add(name: string, phone: string): Promise<boolean> {
    const cleanPhone = phone.replace(/\s/g, '');

    if (!this.isValidPhone(cleanPhone)) {
      log.warn('Invalid phone number:', cleanPhone);
      return false;
    }

    if (!name.trim()) {
      log.warn('Empty name');
      return false;
    }

    try {
      const contacts = await this.getAll();

      const duplicate = contacts.some(c => c.phone === cleanPhone);
      if (duplicate) {
        log.warn('Contact already exists:', cleanPhone);
        return false;
      }

      const contact: EmergencyContact = {
        id: util.generateRandomUUID(),
        name: name.trim(),
        phone: cleanPhone
      };

      contacts.push(contact);
      await this.save(contacts);
      log.info('Contact added:', contact.name);
      return true;
    } catch (err) {
      log.error('Failed to add contact:', JSON.stringify(err));
      return false;
    }
  }

  public async remove(id: string): Promise<boolean> {
    try {
      const contacts = await this.getAll();
      const filtered = contacts.filter(c => c.id !== id);

      if (filtered.length === contacts.length) {
        log.warn('Contact not found:', id);
        return false;
      }

      await this.save(filtered);
      log.info('Contact removed:', id);
      return true;
    } catch (err) {
        log.error('Failed to remove contact:', JSON.stringify(err));
        return false;
    }
}

public async getCount(): Promise<number> {
    const contacts = await this.getAll();
    return contacts.length;
  }

  private async save(contacts: EmergencyContact[]): Promise<void> {
    const store = await this.ensureStore();
    try {
      
        await store.put(CONTACTS_KEY, JSON.stringify(contacts));
    } catch (err){
        
        log.error('Failed to save contact:', JSON.stringify(err));
        throw new Error('Failed to save contact');
    }
    try {
        await store.flush();
        
    } catch (err) {
        log.error('Failed to flush preferences:', JSON.stringify(err));
        throw new Error('Failed to flush preferences');
    
    }
  }

  private isValidPhone(phone: string): boolean {
    const phoneRegex = /^\+?[0-9\-]{7,15}$/;
    return phoneRegex.test(phone);
  }
}

let emergencyContactStoreInstance: EmergencyContactStore | null = null;

export function initEmergencyContactStore(context: Context): void {
  if (!emergencyContactStoreInstance) {
    emergencyContactStoreInstance = new EmergencyContactStore(context);
  }
}

export function getEmergencyContactStore(): EmergencyContactStore {
  if (!emergencyContactStoreInstance) {
    throw new Error('EmergencyContactStore not initialized. Call initEmergencyContactStore(context) first.');
  }
  return emergencyContactStoreInstance;
}
