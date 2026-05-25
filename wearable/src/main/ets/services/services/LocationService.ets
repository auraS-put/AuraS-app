import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';

const log = new Logger('LocationService');

const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION'
];

export interface LocationResult {
  latitude: number;
  longitude: number;
  accuracy: number;
}

export class LocationService {
  private lastKnownLocation: LocationResult | null = null;
  private permissionGranted: boolean = false;
  private context: common.UIAbilityContext | null = null;

  constructor() {
    log.info('Initialized');
  }

  public setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  private async ensurePermission(): Promise<boolean> {
    if (this.permissionGranted) {
      return true;
    }

    if (!this.context) {
      log.warn('Context not set, cannot request permissions');
      return false;
    }

    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(this.context, LOCATION_PERMISSIONS);
      this.permissionGranted = result.authResults.every(r => r === 0);

      if (!this.permissionGranted) {
        log.warn('Location permission denied by user');
      }
      return this.permissionGranted;
    } catch (err) {
      log.error('Failed to request location permission:', JSON.stringify(err));
      return false;
    }
  }

  public async getCurrentLocation(): Promise<LocationResult | null> {
    if (canIUse('SystemCapability.Location.Location.Core')) {
      const hasPermission = await this.ensurePermission();
      if (!hasPermission) {
        return this.lastKnownLocation;
      }

      try {
        
        const location = await geoLocationManager.getCurrentLocation();

        this.lastKnownLocation = {
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy
        };

        log.info(`Location acquired: ${this.lastKnownLocation.latitude}, ${this.lastKnownLocation.longitude} (±${Math.round(this.lastKnownLocation.accuracy)}m)`);
        return this.lastKnownLocation;
      } catch (err) {
        log.error('Failed to get current location:', JSON.stringify(err));
        return this.lastKnownLocation;
      }
    } else {
      log.warn('Location not supported on this device');
      return this.lastKnownLocation;
    }
  }

  public getLastKnownLocation(): LocationResult | null {
    return this.lastKnownLocation;
  }

  public buildMapsUrl(location: LocationResult): string {
    return `https://maps.google.com/?q=${location.latitude},${location.longitude}`;
  }
}

let locationServiceInstance: LocationService | null = null;

export function getLocationService(): LocationService {
  if (!locationServiceInstance) {
    locationServiceInstance = new LocationService();
  }
  return locationServiceInstance;
}
