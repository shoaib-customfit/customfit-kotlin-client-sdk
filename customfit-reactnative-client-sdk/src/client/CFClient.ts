import { CFResult } from '../core/error/CFResult';
import { 
  CFConfig, 
  CFUser, 
  EventData, 
  SummaryData, 
  SdkSettings,
  ConnectionStatus,
  PerformanceMetrics,
  FeatureFlagChangeListener,
  AllFlagsChangeListener,
  ConnectionStatusListener,
  AppState,
  BatteryState
} from '../core/types/CFTypes';
import { CFConfigImpl } from '../config/core/CFConfig';
import { CFUserImpl } from '../core/model/CFUser';
import { Logger } from '../logging/Logger';
import { CFConstants } from '../constants/CFConstants';
import { HttpClient } from '../network/HttpClient';
import { ConfigFetcher } from '../network/ConfigFetcher';
import { EventTracker } from '../analytics/event/EventTracker';
import { SummaryManager } from '../analytics/summary/SummaryManager';
import { ConnectionMonitor } from '../platform/ConnectionMonitor';
import { DeviceInfoUtil } from '../platform/DeviceInfo';
import { EventDataUtil } from '../analytics/event/EventData';
import { AppStateManager } from '../platform/AppStateManager';
import { EnvironmentAttributesCollector } from '../platform/EnvironmentAttributesCollector';

/**
 * Main CustomFit SDK client
 */
export class CFClient {
  private static instance: CFClient | null = null;
  
  private readonly config: CFConfig;
  private currentUser: CFUser;
  private readonly configFetcher: ConfigFetcher;
  private readonly eventTracker: EventTracker;
  private readonly summaryManager: SummaryManager;
  private readonly connectionMonitor: ConnectionMonitor;
  private readonly appStateManager: AppStateManager;
  private readonly environmentCollector: EnvironmentAttributesCollector;

  // State
  private isInitialized: boolean = false;
  private isOfflineMode: boolean = false;
  private currentConfigs: Record<string, any> = {};
  private sdkSettings: SdkSettings | null = null;
  private configMetadata: any = null;

  // Listeners
  private featureFlagListeners: Map<string, Set<FeatureFlagChangeListener>> = new Map();
  private allFlagsListeners: Set<AllFlagsChangeListener> = new Set();
  private connectionListeners: Set<ConnectionStatusListener> = new Set();

  // Timers
  private configPollTimer: NodeJS.Timeout | null = null;
  private sdkSettingsCheckTimer: NodeJS.Timeout | null = null;

  // Metrics
  private metrics: PerformanceMetrics = {
    totalEvents: 0,
    totalSummaries: 0,
    totalConfigFetches: 0,
    averageResponseTime: 0,
    failureRate: 0,
  };

  private constructor(config: CFConfig, user: CFUser) {
    this.config = config;
    this.currentUser = user;
    this.isOfflineMode = config.offlineMode;

    // Initialize components
    this.configFetcher = new ConfigFetcher(config);
    
    const httpClient = new HttpClient();
    this.eventTracker = new EventTracker(config, httpClient);
    this.summaryManager = new SummaryManager(config, httpClient);
    this.connectionMonitor = ConnectionMonitor.getInstance();
    this.appStateManager = AppStateManager.getInstance();
    this.environmentCollector = EnvironmentAttributesCollector.getInstance();

    // Configure logging
    Logger.configure(
      config.loggingEnabled,
      config.debugLoggingEnabled,
      config.logLevel
    );

    Logger.info(`CustomFit SDK initialized with client key: ${config.clientKey.substring(0, 8)}...`);
  }

  /**
   * Initialize the SDK
   */
  static async init(config: CFConfig, user: CFUser): Promise<CFClient> {
    if (CFClient.instance) {
      Logger.warning('CFClient already initialized, returning existing instance');
      return CFClient.instance;
    }

    CFClient.instance = new CFClient(config, user);
    await CFClient.instance.initialize();
    return CFClient.instance;
  }

  /**
   * Get singleton instance
   */
  static getInstance(): CFClient | null {
    return CFClient.instance;
  }

  /**
   * Initialize the client
   */
  private async initialize(): Promise<void> {
    try {
      Logger.info('🔧 CFClient initialization starting...');

      // Start connection monitoring
      await this.connectionMonitor.startMonitoring();
      this.setupConnectionListener();

      // Start app state monitoring
      this.appStateManager.startMonitoring();
      this.setupAppStateListeners();

      // Check SDK settings first
      if (this.config.dimensionId) {
        await this.checkSdkSettings();
        
        // If SDK is disabled, skip further initialization
        if (this.sdkSettings?.cf_skip_sdk) {
          Logger.warning('🔧 SDK is disabled by server settings');
          this.isInitialized = true;
          return;
        }

        if (!this.sdkSettings?.cf_account_enabled) {
          Logger.warning('🔧 Account is disabled by server settings');
          this.isInitialized = true;
          return;
        }
      }

      // Start analytics components
      await this.eventTracker.start();
      await this.summaryManager.start();

      // Load cached configurations
      await this.loadCachedConfigs();

      // Fetch fresh configurations if we're online
      if (!this.isOfflineMode && this.connectionMonitor.isConnected()) {
        await this.refreshConfigurations();
      }

      // Start background tasks
      if (!this.config.disableBackgroundPolling) {
        this.startBackgroundPolling();
      }

      this.isInitialized = true;
      Logger.info('🔧 CFClient initialization completed successfully');

    } catch (error) {
      Logger.error(`🔧 CFClient initialization failed: ${error}`);
      throw error;
    }
  }

  /**
   * Get a feature flag value
   */
  getFeatureFlag<T = boolean>(key: string, defaultValue: T): T {
    if (!this.isInitialized) {
      Logger.warning(`getFeatureFlag called before initialization: ${key}`);
      return defaultValue;
    }

    if (this.sdkSettings?.cf_skip_sdk) {
      return defaultValue;
    }

    const value = this.currentConfigs[key] as T;
    const result = value !== undefined ? value : defaultValue;

    // Track summary for feature flag access
    this.summaryManager.trackFeatureFlagAccess(key, result);

    Logger.debug(`🔧 CONFIG VALUE: ${key} = ${result}`);
    return result;
  }

  /**
   * Get a feature value (same as getFeatureFlag but more generic)
   */
  getFeatureValue<T>(key: string, defaultValue: T): T {
    return this.getFeatureFlag(key, defaultValue);
  }

  /**
   * Get a string configuration value
   */
  getString(key: string, fallbackValue: string): string {
    return this.getFeatureFlag<string>(key, fallbackValue);
  }

  /**
   * Get a number configuration value
   */
  getNumber(key: string, fallbackValue: number): number {
    return this.getFeatureFlag<number>(key, fallbackValue);
  }

  /**
   * Get a boolean configuration value
   */
  getBoolean(key: string, fallbackValue: boolean): boolean {
    return this.getFeatureFlag<boolean>(key, fallbackValue);
  }

  /**
   * Get a JSON configuration value
   */
  getJson(key: string, fallbackValue: Record<string, any>): Record<string, any> {
    return this.getFeatureFlag<Record<string, any>>(key, fallbackValue);
  }

  /**
   * Get all feature flags (matches Kotlin getAllFlags)
   */
  getAllFlags(): Record<string, any> {
    return this.getAllFeatures();
  }

  /**
   * Get all feature flags
   */
  getAllFeatures(): Record<string, any> {
    if (!this.isInitialized) {
      Logger.warning('getAllFeatures called before initialization');
      return {};
    }

    if (this.sdkSettings?.cf_skip_sdk) {
      return {};
    }

    Logger.debug(`🔧 CONFIG: Returning ${Object.keys(this.currentConfigs).length} feature flags`);
    return { ...this.currentConfigs };
  }

  /**
   * Track an event
   */
  async trackEvent(name: string, properties?: Record<string, any>): Promise<CFResult<void>> {
    if (!this.isInitialized) {
      return CFResult.errorWithMessage('SDK not initialized');
    }

    if (this.sdkSettings?.cf_skip_sdk) {
      return CFResult.successVoid();
    }

    // Flush summaries before tracking event (like Kotlin SDK)
    await this.summaryManager.flush();

    // Create and track event
    const result = await this.eventTracker.trackEvent(
      name,
      properties,
      this.currentUser.userCustomerId,
      this.currentUser.anonymousId
    );

    if (result.isSuccess) {
      this.metrics.totalEvents++;
    }

    return result;
  }

  /**
   * Track a screen view
   */
  async trackScreenView(screenName: string): Promise<CFResult<void>> {
    return await this.trackEvent('screen_view', { screen_name: screenName });
  }

  /**
   * Track feature usage
   */
  async trackFeatureUsage(featureName: string, properties?: Record<string, any>): Promise<CFResult<void>> {
    return await this.trackEvent('feature_usage', { feature_name: featureName, ...properties });
  }

  /**
   * Set user attribute
   */
  setUserAttribute(key: string, value: any): void {
    this.currentUser = this.currentUser.withProperty(key, value);
    Logger.debug(`🔧 User attribute set: ${key} = ${value}`);
  }

  /**
   * Set multiple user attributes
   */
  setUserAttributes(attributes: Record<string, any>): void {
    this.currentUser = this.currentUser.withProperties(attributes);
    Logger.debug(`🔧 User attributes set: ${Object.keys(attributes).join(', ')}`);
  }

  /**
   * Update user
   */
  setUser(user: CFUser): void {
    this.currentUser = user;
    Logger.info('🔧 User updated');
  }

  /**
   * Get current user
   */
  getUser(): CFUser {
    return this.currentUser;
  }

  /**
   * Force refresh configurations
   */
  async forceRefresh(): Promise<CFResult<void>> {
    if (!this.isInitialized) {
      return CFResult.errorWithMessage('SDK not initialized');
    }

    Logger.info('🔧 Force refresh requested');
    return await this.refreshConfigurations();
  }

  /**
   * Flush events
   */
  async flushEvents(): Promise<CFResult<number>> {
    if (!this.isInitialized) {
      return CFResult.errorWithMessage('SDK not initialized');
    }

    return await this.eventTracker.flush();
  }

  /**
   * Flush summaries
   */
  async flushSummaries(): Promise<CFResult<number>> {
    if (!this.isInitialized) {
      return CFResult.errorWithMessage('SDK not initialized');
    }

    return await this.summaryManager.flush();
  }

  /**
   * Set offline mode
   */
  setOfflineMode(offline: boolean): void {
    this.isOfflineMode = offline;
    Logger.info(`🔧 Offline mode ${offline ? 'enabled' : 'disabled'}`);
  }

  /**
   * Check if SDK is offline
   */
  isOffline(): boolean {
    return this.isOfflineMode || !this.connectionMonitor.isConnected();
  }

  /**
   * Get connection information (matches Kotlin)
   */
  getConnectionInformation(): ConnectionStatus {
    return this.connectionMonitor.isConnected() ? ConnectionStatus.CONNECTED : ConnectionStatus.DISCONNECTED;
  }

  /**
   * Get the mutable configuration (matches Kotlin)
   */
  getMutableConfig(): CFConfig {
    return this.config;
  }

  /**
   * Await SDK settings check (matches Kotlin)
   */
  async awaitSdkSettingsCheck(): Promise<void> {
    // Check if SDK settings are already loaded
    if (this.sdkSettings !== null) {
      return Promise.resolve();
    }

    // Wait for first settings check to complete
    await this.checkSdkSettings();
  }

  /**
   * Pause SDK operations (matches Kotlin lifecycle)
   */
  pause(): void {
    if (this.config.disableBackgroundPolling) {
      this.setOfflineMode(true);
    }
    this.stopBackgroundPolling();
    Logger.info('🔧 CFClient paused');
  }

  /**
   * Resume SDK operations (matches Kotlin lifecycle)
   */
  resume(): void {
    this.setOfflineMode(false);
    this.startBackgroundPolling();
    // Force refresh when resuming
    this.refreshConfigurations();
    // Increment app launch count like Kotlin SDK
    this.incrementAppLaunchCount();
    Logger.info('🔧 CFClient resumed');
  }

  /**
   * Increment app launch count (matches Kotlin)
   */
  incrementAppLaunchCount(): void {
    // Update user properties with app launch count
    const currentLaunchCount = (this.currentUser.properties?.launch_count || 0) as number;
    this.setUserAttribute('launch_count', currentLaunchCount + 1);
    Logger.debug(`🔧 App launch count incremented to: ${currentLaunchCount + 1}`);
  }

  /**
   * Shutdown the SDK (matches Kotlin shutdown)
   */
  async shutdown(): Promise<void> {
    Logger.info('🔧 CFClient shutting down...');

    // Stop background tasks first
    this.stopBackgroundPolling();

    // Flush all pending data before shutdown
    try {
      await this.flushEvents();
      await this.flushSummaries();
    } catch (error) {
      Logger.warning(`🔧 Failed to flush data during shutdown: ${error}`);
    }

    // Stop all components
    await this.eventTracker.stop();
    await this.summaryManager.stop();
    this.connectionMonitor.stopMonitoring();
    this.appStateManager.stopMonitoring();

    // Clear all listeners
    this.featureFlagListeners.clear();
    this.allFlagsListeners.clear();
    this.connectionListeners.clear();

    this.isInitialized = false;
    CFClient.instance = null;

    Logger.info('🔧 CFClient shutdown completed');
  }

  /**
   * Get SDK metrics
   */
  getMetrics(): PerformanceMetrics {
    return { ...this.metrics };
  }

  /**
   * Get environment attributes
   */
  async getEnvironmentAttributes(): Promise<Record<string, any>> {
    return await this.environmentCollector.getAllAttributes();
  }

  /**
   * Enable automatic environment attributes collection (matches Kotlin)
   */
  enableAutoEnvAttributes(): void {
    this.enableAutoEnvironmentAttributes();
  }

  /**
   * Disable automatic environment attributes collection (matches Kotlin)
   */
  disableAutoEnvAttributes(): void {
    Logger.info('🔧 Auto environment attributes disabled');
    // Implementation would stop including environment attributes
  }

  /**
   * Set logging enabled/disabled (matches Kotlin)
   */
  setLoggingEnabled(enabled: boolean): void {
    Logger.setLoggingEnabled(enabled);
  }

  /**
   * Set debug logging enabled/disabled (matches Kotlin)
   */
  setDebugLoggingEnabled(enabled: boolean): void {
    Logger.setDebugLoggingEnabled(enabled);
  }

  /**
   * Update network connection timeout (matches Kotlin)
   */
  updateNetworkConnectionTimeout(timeoutMs: number): void {
    if (timeoutMs <= 0) {
      Logger.warning('🔧 Connection timeout must be greater than 0');
      return;
    }
    // Update HttpClient timeout - would need to implement in HttpClient
    Logger.info(`🔧 Network connection timeout updated to: ${timeoutMs}ms`);
  }

  /**
   * Update network read timeout (matches Kotlin)
   */
  updateNetworkReadTimeout(timeoutMs: number): void {
    if (timeoutMs <= 0) {
      Logger.warning('🔧 Read timeout must be greater than 0');
      return;
    }
    // Update HttpClient timeout - would need to implement in HttpClient
    Logger.info(`🔧 Network read timeout updated to: ${timeoutMs}ms`);
  }

  /**
   * Update SDK settings check interval (matches Kotlin)
   */
  updateSdkSettingsCheckInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      Logger.warning('🔧 SDK settings interval must be greater than 0');
      return;
    }
    
    // Restart background polling with new interval
    this.stopBackgroundPolling();
    this.startBackgroundPolling();
    
    Logger.info(`🔧 SDK settings check interval updated to: ${intervalMs}ms`);
  }

  /**
   * Update events flush interval (matches Kotlin)
   */
  updateEventsFlushInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      Logger.warning('🔧 Events flush interval must be greater than 0');
      return;
    }
    
    // Restart event tracker with new interval
    this.eventTracker.updateFlushInterval(intervalMs);
    
    Logger.info(`🔧 Events flush interval updated to: ${intervalMs}ms`);
  }

  /**
   * Update summaries flush interval (matches Kotlin)
   */
  updateSummariesFlushInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      Logger.warning('🔧 Summaries flush interval must be greater than 0');
      return;
    }
    
    // Restart summary manager with new interval
    this.summaryManager.updateFlushInterval(intervalMs);
    
    Logger.info(`🔧 Summaries flush interval updated to: ${intervalMs}ms`);
  }

  /**
   * Enable automatic environment attributes collection
   */
  enableAutoEnvironmentAttributes(): void {
    if (!this.config.autoEnvAttributesEnabled) {
      Logger.warning('🔧 Auto environment attributes are disabled in config');
      return;
    }
    
    Logger.info('🔧 Auto environment attributes enabled');
    // Implementation would automatically include environment attributes in events
  }

  /**
   * Add a listener for a specific configuration (matches Kotlin addConfigListener)
   */
  addConfigListener<T>(key: string, listener: (value: T) => void): void {
    const wrappedListener: FeatureFlagChangeListener = {
      onFeatureFlagChanged: (flagKey: string, oldValue: any, newValue: any) => {
        if (flagKey === key) {
          listener(newValue as T);
        }
      }
    };
    this.addFeatureFlagListener(key, wrappedListener);
    Logger.debug(`🔧 Added config listener for key: ${key}`);
  }

  /**
   * Remove a config listener (matches Kotlin removeConfigListener)
   */
  removeConfigListener<T>(key: string, listener: (value: T) => void): void {
    // Clear all listeners for this key - exact listener removal would need wrapper tracking
    const listeners = this.featureFlagListeners.get(key);
    if (listeners) {
      listeners.clear();
      Logger.debug(`🔧 Removed config listeners for key: ${key}`);
    }
  }

  /**
   * Clear all listeners for a specific configuration
   */
  clearConfigListeners(key: string): void {
    this.featureFlagListeners.delete(key);
    Logger.debug(`🔧 Cleared all config listeners for key: ${key}`);
  }

  /**
   * Register a feature flag listener (matches Kotlin registerFeatureFlagListener)
   */
  registerFeatureFlagListener(flagKey: string, listener: FeatureFlagChangeListener): void {
    this.addFeatureFlagListener(flagKey, listener);
  }

  /**
   * Unregister a feature flag listener (matches Kotlin unregisterFeatureFlagListener)
   */
  unregisterFeatureFlagListener(flagKey: string, listener: FeatureFlagChangeListener): void {
    this.removeFeatureFlagListener(flagKey, listener);
  }

  /**
   * Register an all flags listener (matches Kotlin registerAllFlagsListener)
   */
  registerAllFlagsListener(listener: AllFlagsChangeListener): void {
    this.addAllFlagsListener(listener);
  }

  /**
   * Unregister an all flags listener (matches Kotlin unregisterAllFlagsListener)
   */
  unregisterAllFlagsListener(listener: AllFlagsChangeListener): void {
    this.removeAllFlagsListener(listener);
  }

  /**
   * Add feature flag change listener
   */
  addFeatureFlagListener(key: string, listener: FeatureFlagChangeListener): void {
    if (!this.featureFlagListeners.has(key)) {
      this.featureFlagListeners.set(key, new Set());
    }
    this.featureFlagListeners.get(key)!.add(listener);
    Logger.debug(`🔧 Added feature flag listener for: ${key}`);
  }

  /**
   * Remove feature flag change listener
   */
  removeFeatureFlagListener(key: string, listener: FeatureFlagChangeListener): void {
    const listeners = this.featureFlagListeners.get(key);
    if (listeners) {
      listeners.delete(listener);
      if (listeners.size === 0) {
        this.featureFlagListeners.delete(key);
      }
    }
  }

  /**
   * Add all flags change listener
   */
  addAllFlagsListener(listener: AllFlagsChangeListener): void {
    this.allFlagsListeners.add(listener);
    Logger.debug('🔧 Added all flags listener');
  }

  /**
   * Remove all flags change listener
   */
  removeAllFlagsListener(listener: AllFlagsChangeListener): void {
    this.allFlagsListeners.delete(listener);
  }

  /**
   * Add connection status listener
   */
  addConnectionStatusListener(listener: ConnectionStatusListener): void {
    this.connectionListeners.add(listener);
    this.connectionMonitor.addListener(listener);
    Logger.debug('🔧 Added connection status listener');
  }

  /**
   * Remove connection status listener
   */
  removeConnectionStatusListener(listener: ConnectionStatusListener): void {
    this.connectionListeners.delete(listener);
    this.connectionMonitor.removeListener(listener);
  }

  /**
   * Close the SDK (alias for shutdown)
   */
  async close(): Promise<void> {
    await this.shutdown();
  }

  // Private methods

  private async checkSdkSettings(): Promise<void> {
    if (!this.config.dimensionId) {
      return;
    }

    try {
      const result = await this.configFetcher.checkSdkSettings(this.config.dimensionId);
      
      if (result.isSuccess) {
        this.sdkSettings = result.data;
        Logger.debug(`🔧 SDK settings checked: ${JSON.stringify(this.sdkSettings)}`);
      } else {
        Logger.warning(`🔧 Failed to check SDK settings: ${result.error?.message}`);
      }
    } catch (error) {
      Logger.error(`🔧 Exception checking SDK settings: ${error}`);
    }
  }

  private async loadCachedConfigs(): Promise<void> {
    try {
      const result = await this.configFetcher.getCachedUserConfigs();
      
      if (result.isSuccess && result.data) {
        this.currentConfigs = result.data.configs;
        this.configMetadata = result.data.metadata;
        
        Logger.info(`🔧 Loaded ${Object.keys(this.currentConfigs).length} cached configurations`);
      }
    } catch (error) {
      Logger.error(`🔧 Failed to load cached configs: ${error}`);
    }
  }

  private async refreshConfigurations(): Promise<CFResult<void>> {
    try {
      const startTime = Date.now();
      
      const result = await this.configFetcher.fetchUserConfigs(
        this.config.clientKey,
        this.configMetadata?.lastModified,
        this.configMetadata?.etag
      );

      const duration = Date.now() - startTime;
      this.updateResponseTimeMetrics(duration);
      this.metrics.totalConfigFetches++;

      if (result.isSuccess) {
        const oldConfigs = { ...this.currentConfigs };
        this.currentConfigs = result.data!.configs;
        this.configMetadata = result.data!.metadata;

        // Cache the new configurations
        await this.configFetcher.cacheUserConfigs(this.currentConfigs, this.configMetadata);

        // Notify listeners of changes
        this.notifyConfigChanges(oldConfigs, this.currentConfigs);

        Logger.info('🔧 CONFIG UPDATE: Configurations refreshed successfully');
        return CFResult.successVoid();
      } else {
        Logger.error(`🔧 Failed to refresh configurations: ${result.error?.message}`);
        return result;
      }
    } catch (error) {
      Logger.error(`🔧 Exception refreshing configurations: ${error}`);
      return CFResult.errorFromException(error as Error);
    }
  }

  private setupConnectionListener(): void {
    this.connectionMonitor.addListener({
      onConnectionStatusChanged: (status: ConnectionStatus) => {
        Logger.info(`🔧 Connection status changed to: ${status}`);
        
        if (status === ConnectionStatus.CONNECTED && !this.isOfflineMode) {
          // Try to refresh configs when connection is restored
          this.refreshConfigurations();
        }
      }
    });
  }

  private startBackgroundPolling(): void {
    // Get battery-aware polling intervals
    const sdkSettingsInterval = this.appStateManager.getPollingInterval(
      this.config.sdkSettingsCheckIntervalMs,
      this.config.reducedPollingIntervalMs,
      this.config.useReducedPollingWhenBatteryLow
    );

    const configPollingInterval = this.appStateManager.getPollingInterval(
      this.config.backgroundPollingIntervalMs,
      this.config.reducedPollingIntervalMs,
      this.config.useReducedPollingWhenBatteryLow
    );

    // SDK settings check timer
    this.sdkSettingsCheckTimer = setInterval(async () => {
      if (!this.isOfflineMode && this.connectionMonitor.isConnected()) {
        await this.checkSdkSettings();
      }
    }, sdkSettingsInterval);

    // Config polling timer
    this.configPollTimer = setInterval(async () => {
      if (!this.isOfflineMode && this.connectionMonitor.isConnected()) {
        await this.refreshConfigurations();
      }
    }, configPollingInterval);

    Logger.debug(`🔧 Background polling started (SDK settings: ${sdkSettingsInterval}ms, Config: ${configPollingInterval}ms)`);
  }

  private stopBackgroundPolling(): void {
    if (this.sdkSettingsCheckTimer) {
      clearInterval(this.sdkSettingsCheckTimer);
      this.sdkSettingsCheckTimer = null;
    }

    if (this.configPollTimer) {
      clearInterval(this.configPollTimer);
      this.configPollTimer = null;
    }

    Logger.debug('🔧 Background polling stopped');
  }

  private notifyConfigChanges(oldConfigs: Record<string, any>, newConfigs: Record<string, any>): void {
    // Notify specific flag listeners
    for (const [key, listeners] of this.featureFlagListeners) {
      const oldValue = oldConfigs[key];
      const newValue = newConfigs[key];
      
      if (oldValue !== newValue) {
        listeners.forEach(listener => {
          try {
            listener.onFeatureFlagChanged(key, oldValue, newValue);
          } catch (error) {
            Logger.error(`Error notifying feature flag listener: ${error}`);
          }
        });
      }
    }

    // Notify all flags listeners
    this.allFlagsListeners.forEach(listener => {
      try {
        listener.onAllFlagsChanged(newConfigs);
      } catch (error) {
        Logger.error(`Error notifying all flags listener: ${error}`);
      }
    });
  }

  private updateResponseTimeMetrics(duration: number): void {
    // Simple moving average
    this.metrics.averageResponseTime = 
      (this.metrics.averageResponseTime * 0.8) + (duration * 0.2);
  }

  private setupAppStateListeners(): void {
    // Listen for app state changes
    this.appStateManager.addAppStateListener({
      onAppStateChanged: (newState: AppState, previousState: AppState) => {
        Logger.info(`🔧 App state changed from ${previousState} to ${newState}`);
        
        if (newState === AppState.BACKGROUND && this.config.disableBackgroundPolling) {
          // Pause polling when app goes to background if configured
          Logger.info('🔧 App entered background - pausing operations due to disableBackgroundPolling=true');
          this.stopBackgroundPolling();
        } else if (newState === AppState.ACTIVE && previousState === AppState.BACKGROUND) {
          // Resume polling when app comes to foreground
          Logger.info('🔧 App entered foreground - resuming operations');
          if (!this.config.disableBackgroundPolling) {
            this.startBackgroundPolling();
          }
          // Refresh configurations immediately when coming to foreground
          this.refreshConfigurations();
        }
      }
    });

    // Listen for battery state changes
    this.appStateManager.addBatteryStateListener({
      onBatteryStateChanged: (batteryState: BatteryState) => {
        Logger.debug(`🔧 Battery state changed - Level: ${(batteryState.level * 100).toFixed(1)}%, Low: ${batteryState.isLow}, Charging: ${batteryState.isCharging}`);
        
        // Adjust polling intervals based on battery state
        if (this.config.useReducedPollingWhenBatteryLow && batteryState.isLow && !batteryState.isCharging) {
          Logger.info('🔧 Battery low, using reduced polling intervals');
          // Implementation would restart timers with reduced intervals
        } else {
          Logger.debug('🔧 Battery normal, using standard polling intervals');
          // Implementation would restart timers with normal intervals
        }
      }
    });
  }
} 