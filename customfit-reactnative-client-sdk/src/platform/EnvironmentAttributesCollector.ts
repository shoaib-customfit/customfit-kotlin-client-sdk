import { DeviceInfoUtil } from './DeviceInfo';
import { AppStateManager } from './AppStateManager';
import { ConnectionMonitor } from './ConnectionMonitor';
import { Logger } from '../logging/Logger';
import { CFConstants } from '../constants/CFConstants';

/**
 * Collects comprehensive environment attributes for analytics and configuration
 */
export class EnvironmentAttributesCollector {
  private static instance: EnvironmentAttributesCollector | null = null;
  private appStateManager: AppStateManager;
  private connectionMonitor: ConnectionMonitor;
  private cachedAttributes: Record<string, any> | null = null;
  private lastCollectionTime: number = 0;
  private readonly cacheTTL: number = 300000; // 5 minutes

  private constructor() {
    this.appStateManager = AppStateManager.getInstance();
    this.connectionMonitor = ConnectionMonitor.getInstance();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): EnvironmentAttributesCollector {
    if (!EnvironmentAttributesCollector.instance) {
      EnvironmentAttributesCollector.instance = new EnvironmentAttributesCollector();
    }
    return EnvironmentAttributesCollector.instance;
  }

  /**
   * Collect all environment attributes
   */
  async getAllAttributes(forceRefresh: boolean = false): Promise<Record<string, any>> {
    const now = Date.now();
    
    // Return cached attributes if still valid and not forcing refresh
    if (!forceRefresh && this.cachedAttributes && (now - this.lastCollectionTime) < this.cacheTTL) {
      Logger.debug('EnvironmentAttributesCollector: Returning cached attributes');
      return { ...this.cachedAttributes };
    }

    try {
      Logger.debug('EnvironmentAttributesCollector: Collecting fresh environment attributes');
      
      const attributes: Record<string, any> = {};

      // Device information
      const deviceInfo = await DeviceInfoUtil.getDeviceInfo();
      Object.assign(attributes, {
        // Device attributes
        deviceId: deviceInfo.deviceId,
        deviceModel: deviceInfo.model,
        deviceBrand: deviceInfo.brand,
        osName: deviceInfo.platform,
        osVersion: deviceInfo.osVersion,
        
        // App information
        appVersion: deviceInfo.appVersion,
        appBuild: deviceInfo.buildNumber,
        appName: 'React Native App', // Would come from app.json in real app
        bundleId: 'com.example.app', // Would come from app.json in real app
        
        // Screen information
        screenWidth: deviceInfo.screenWidth,
        screenHeight: deviceInfo.screenHeight,
        isTablet: deviceInfo.isTablet,
        
        // Locale information
        language: deviceInfo.locale,
        countryCode: this.extractCountryCode(deviceInfo.locale),
        timeZone: deviceInfo.timezone,
        
        // SDK information
        sdkPlatform: 'react-native',
        sdkName: CFConstants.General.SDK_NAME,
        sdkVersion: CFConstants.General.DEFAULT_SDK_VERSION,
        sdkType: deviceInfo.sdkType,
      });

      // Battery information
      const batteryState = this.appStateManager.getCurrentBatteryState();
      Object.assign(attributes, {
        batteryLevel: Math.round(batteryState.level * 100), // As percentage
        isCharging: batteryState.isCharging,
        isBatteryLow: batteryState.isLow,
      });

      // App state information
      const appState = this.appStateManager.getCurrentAppState();
      Object.assign(attributes, {
        appState: appState,
        isAppInForeground: appState === 'active',
      });

      // Network information
      const connectionInfo = await this.connectionMonitor.getConnectionInfo();
      Object.assign(attributes, {
        networkType: connectionInfo.type,
        isConnected: connectionInfo.status === 'connected',
        isInternetReachable: connectionInfo.isInternetReachable,
        isWifiEnabled: connectionInfo.isWifiEnabled,
      });

      // Installation information (simulated for React Native)
      Object.assign(attributes, {
        appInstallTime: this.getAppInstallTime(),
        appUpdateTime: this.getAppUpdateTime(),
        isFirstRun: this.isFirstRun(),
      });

      // Runtime information
      Object.assign(attributes, {
        timestamp: now,
        timezoneOffset: new Date().getTimezoneOffset(),
        sessionStartTime: this.getSessionStartTime(),
      });

      // Cache the attributes
      this.cachedAttributes = { ...attributes };
      this.lastCollectionTime = now;

      Logger.debug(`EnvironmentAttributesCollector: Collected ${Object.keys(attributes).length} attributes`);
      return attributes;
    } catch (error) {
      Logger.error(`EnvironmentAttributesCollector: Failed to collect attributes: ${error}`);
      
      // Return cached attributes if available, otherwise minimal attributes
      if (this.cachedAttributes) {
        return { ...this.cachedAttributes };
      }
      
      return this.getMinimalAttributes();
    }
  }

  /**
   * Get specific attribute category
   */
  async getDeviceAttributes(): Promise<Record<string, any>> {
    const allAttributes = await this.getAllAttributes();
    return this.filterAttributes(allAttributes, [
      'deviceId', 'deviceModel', 'deviceBrand', 'osName', 'osVersion',
      'screenWidth', 'screenHeight', 'isTablet'
    ]);
  }

  /**
   * Get app-specific attributes
   */
  async getAppAttributes(): Promise<Record<string, any>> {
    const allAttributes = await this.getAllAttributes();
    return this.filterAttributes(allAttributes, [
      'appVersion', 'appBuild', 'appName', 'bundleId',
      'appState', 'isAppInForeground', 'appInstallTime', 'appUpdateTime', 'isFirstRun'
    ]);
  }

  /**
   * Get network attributes
   */
  async getNetworkAttributes(): Promise<Record<string, any>> {
    const allAttributes = await this.getAllAttributes();
    return this.filterAttributes(allAttributes, [
      'networkType', 'isConnected', 'isInternetReachable', 'isWifiEnabled'
    ]);
  }

  /**
   * Get battery attributes
   */
  async getBatteryAttributes(): Promise<Record<string, any>> {
    const allAttributes = await this.getAllAttributes();
    return this.filterAttributes(allAttributes, [
      'batteryLevel', 'isCharging', 'isBatteryLow'
    ]);
  }

  /**
   * Get locale attributes
   */
  async getLocaleAttributes(): Promise<Record<string, any>> {
    const allAttributes = await this.getAllAttributes();
    return this.filterAttributes(allAttributes, [
      'language', 'countryCode', 'timeZone', 'timezoneOffset'
    ]);
  }

  /**
   * Clear cached attributes
   */
  clearCache(): void {
    this.cachedAttributes = null;
    this.lastCollectionTime = 0;
    Logger.debug('EnvironmentAttributesCollector: Cache cleared');
  }

  /**
   * Get cache information
   */
  getCacheInfo(): { isCached: boolean; age: number; ttl: number } {
    const now = Date.now();
    const age = now - this.lastCollectionTime;
    
    return {
      isCached: this.cachedAttributes !== null,
      age,
      ttl: this.cacheTTL,
    };
  }

  private filterAttributes(attributes: Record<string, any>, keys: string[]): Record<string, any> {
    const filtered: Record<string, any> = {};
    keys.forEach(key => {
      if (key in attributes) {
        filtered[key] = attributes[key];
      }
    });
    return filtered;
  }

  private extractCountryCode(locale: string): string {
    // Extract country code from locale (e.g., "en-US" -> "US")
    const parts = locale.split('-');
    return parts.length > 1 ? parts[1] : 'US';
  }

  private getAppInstallTime(): number {
    // In a real implementation, this would be stored and retrieved from persistent storage
    // For demo purposes, return a simulated install time
    return Date.now() - (7 * 24 * 60 * 60 * 1000); // 7 days ago
  }

  private getAppUpdateTime(): number {
    // In a real implementation, this would track actual app updates
    // For demo purposes, return a simulated update time
    return Date.now() - (24 * 60 * 60 * 1000); // 1 day ago
  }

  private isFirstRun(): boolean {
    // In a real implementation, this would be tracked in persistent storage
    // For demo purposes, return false
    return false;
  }

  private getSessionStartTime(): number {
    // In a real implementation, this would track when the current session started
    // For demo purposes, return a recent timestamp
    return Date.now() - (10 * 60 * 1000); // 10 minutes ago
  }

  private getMinimalAttributes(): Record<string, any> {
    return {
      sdkPlatform: 'react-native',
      sdkName: CFConstants.General.SDK_NAME,
      sdkVersion: CFConstants.General.DEFAULT_SDK_VERSION,
      timestamp: Date.now(),
      osName: 'unknown',
      appState: 'unknown',
      isConnected: false,
    };
  }
} 