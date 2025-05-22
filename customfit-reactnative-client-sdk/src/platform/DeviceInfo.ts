import { Platform, Dimensions } from 'react-native';
import { Logger } from '../logging/Logger';

/**
 * Device information interface
 */
export interface DeviceInformation {
  deviceId: string;
  platform: string;
  osVersion: string;
  appVersion: string;
  buildNumber: string;
  model: string;
  brand: string;
  screenWidth: number;
  screenHeight: number;
  isTablet: boolean;
  locale: string;
  timezone: string;
  sdkType: string;
  sdkVersion: string;
}

/**
 * Device information utility
 */
export class DeviceInfoUtil {
  private static deviceInfo: DeviceInformation | null = null;

  /**
   * Get device information (cached after first call)
   */
  static async getDeviceInfo(): Promise<DeviceInformation> {
    if (DeviceInfoUtil.deviceInfo) {
      return DeviceInfoUtil.deviceInfo;
    }

    try {
      const { width, height } = Dimensions.get('window');
      
      const deviceInfo: DeviceInformation = {
        deviceId: await DeviceInfoUtil.getDeviceId(),
        platform: Platform.OS,
        osVersion: Platform.Version.toString(),
        appVersion: await DeviceInfoUtil.getAppVersion(),
        buildNumber: await DeviceInfoUtil.getBuildNumber(),
        model: await DeviceInfoUtil.getModel(),
        brand: await DeviceInfoUtil.getBrand(),
        screenWidth: width,
        screenHeight: height,
        isTablet: await DeviceInfoUtil.isTablet(),
        locale: await DeviceInfoUtil.getLocale(),
        timezone: await DeviceInfoUtil.getTimezone(),
        sdkType: 'react-native',
        sdkVersion: '1.0.0',
      };

      DeviceInfoUtil.deviceInfo = deviceInfo;
      Logger.info(`Device info collected: ${deviceInfo.platform} ${deviceInfo.osVersion}, ${deviceInfo.model}`);
      
      return deviceInfo;
    } catch (error) {
      Logger.error(`Failed to collect device info: ${error}`);
      
      // Return fallback device info
      const fallbackInfo: DeviceInformation = {
        deviceId: 'unknown',
        platform: Platform.OS,
        osVersion: Platform.Version.toString(),
        appVersion: 'unknown',
        buildNumber: 'unknown',
        model: 'unknown',
        brand: 'unknown',
        screenWidth: 0,
        screenHeight: 0,
        isTablet: false,
        locale: 'en-US',
        timezone: 'UTC',
        sdkType: 'react-native',
        sdkVersion: '1.0.0',
      };
      
      DeviceInfoUtil.deviceInfo = fallbackInfo;
      return fallbackInfo;
    }
  }

  /**
   * Get unique device ID
   */
  static async getDeviceId(): Promise<string> {
    try {
      // Generate a pseudo-unique ID based on platform and timestamp
      const timestamp = Date.now().toString();
      const random = Math.random().toString(36).substr(2, 9);
      return `${Platform.OS}-${timestamp}-${random}`;
    } catch (error) {
      Logger.warning(`Failed to get device ID: ${error}`);
      return `fallback-${Date.now()}`;
    }
  }

  /**
   * Get app version
   */
  static async getAppVersion(): Promise<string> {
    try {
      // In a real app, this would come from app.json or similar
      return '1.0.0';
    } catch (error) {
      Logger.warning(`Failed to get app version: ${error}`);
      return 'unknown';
    }
  }

  /**
   * Get build number
   */
  static async getBuildNumber(): Promise<string> {
    try {
      // In a real app, this would come from app.json or similar
      return '1';
    } catch (error) {
      Logger.warning(`Failed to get build number: ${error}`);
      return 'unknown';
    }
  }

  /**
   * Get device model
   */
  static async getModel(): Promise<string> {
    try {
      // Platform-specific model detection would go here
      return Platform.OS === 'ios' ? 'iOS Device' : 'Android Device';
    } catch (error) {
      Logger.warning(`Failed to get device model: ${error}`);
      return 'unknown';
    }
  }

  /**
   * Get device brand
   */
  static async getBrand(): Promise<string> {
    try {
      return Platform.OS === 'ios' ? 'Apple' : 'Android';
    } catch (error) {
      Logger.warning(`Failed to get device brand: ${error}`);
      return 'unknown';
    }
  }

  /**
   * Check if device is a tablet
   */
  static async isTablet(): Promise<boolean> {
    try {
      const { width, height } = Dimensions.get('window');
      // Simple heuristic: if smallest dimension > 600, consider it a tablet
      return Math.min(width, height) > 600;
    } catch (error) {
      Logger.warning(`Failed to check if tablet: ${error}`);
      return false;
    }
  }

  /**
   * Get device locale
   */
  static async getLocale(): Promise<string> {
    try {
      // In a real app, this would use react-native-localize or similar
      return 'en-US';
    } catch (error) {
      Logger.warning(`Failed to get locale: ${error}`);
      return 'en-US';
    }
  }

  /**
   * Get device timezone
   */
  static async getTimezone(): Promise<string> {
    try {
      // Use JavaScript's built-in timezone detection
      return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    } catch (error) {
      Logger.warning(`Failed to get timezone: ${error}`);
      return 'UTC';
    }
  }

  /**
   * Get device properties for API calls
   */
  static async getDeviceProperties(): Promise<Record<string, any>> {
    const deviceInfo = await DeviceInfoUtil.getDeviceInfo();
    
    return {
      device_id: deviceInfo.deviceId,
      os_name: deviceInfo.platform,
      os_version: deviceInfo.osVersion,
      app_version: deviceInfo.appVersion,
      app_build: deviceInfo.buildNumber,
      device_model: deviceInfo.model,
      device_brand: deviceInfo.brand,
      screen_width: deviceInfo.screenWidth,
      screen_height: deviceInfo.screenHeight,
      is_tablet: deviceInfo.isTablet,
      locale: deviceInfo.locale,
      timezone: deviceInfo.timezone,
      sdk_type: deviceInfo.sdkType,
      sdk_version: deviceInfo.sdkVersion,
    };
  }

  /**
   * Clear cached device info (useful for testing)
   */
  static clearCache(): void {
    DeviceInfoUtil.deviceInfo = null;
    Logger.debug('Device info cache cleared');
  }

  /**
   * Refresh device info (forces re-collection)
   */
  static async refreshDeviceInfo(): Promise<DeviceInformation> {
    DeviceInfoUtil.clearCache();
    return await DeviceInfoUtil.getDeviceInfo();
  }
} 