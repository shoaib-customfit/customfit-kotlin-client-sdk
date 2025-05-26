import { CFResult } from '../core/error/CFResult';
import { 
  CFConfig, 
  CFUser, 
  EventData, 
  SdkSettings,
  ConnectionStatus,
  PerformanceMetrics,
  FeatureFlagChangeListener,
  AllFlagsChangeListener,
  ConnectionStatusListener,
  AppState,
  BatteryState,
  EvaluationContext,
  DeviceContext,
  ApplicationInfo,
  ContextType
} from '../core/types/CFTypes';
import { CFConfigImpl } from '../config/core/CFConfig';
import { MutableCFConfig } from '../config/core/MutableCFConfig';
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
import { 
  SessionManager, 
  SessionData, 
  SessionConfig, 
  SessionRotationListener, 
  RotationReason, 
  DEFAULT_SESSION_CONFIG 
} from '../core/session/SessionManager';

/**
 * Main CustomFit SDK client
 */
export class CFClient {
  // Singleton implementation
  private static _instance: CFClient | null = null;
  private static _isInitializing: boolean = false;
  private static _initializationPromise: Promise<CFClient> | null = null;
  
  private readonly config: CFConfig;
  private readonly mutableConfig: MutableCFConfig;
  private currentUser: CFUser;
  private readonly configFetcher: ConfigFetcher;
  private readonly eventTracker: EventTracker;
  private readonly summaryManager: SummaryManager;
  private readonly connectionMonitor: ConnectionMonitor;
  private readonly appStateManager: AppStateManager;
  private readonly environmentCollector: EnvironmentAttributesCollector;

  /// Session manager for handling session lifecycle
  private sessionManager: SessionManager | null = null;
  private sessionId: string = '';

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

  // Background polling timers
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
    this.mutableConfig = new MutableCFConfig(config);
    this.currentUser = user;
    this.isOfflineMode = config.offlineMode;

    // Initialize components
    this.configFetcher = new ConfigFetcher(config);
    
    const httpClient = new HttpClient();
    this.summaryManager = new SummaryManager(this.sessionId, httpClient, user, config);
    this.eventTracker = new EventTracker(config, httpClient, this.currentUser, this.summaryManager);
    this.connectionMonitor = ConnectionMonitor.getInstance();
    this.appStateManager = AppStateManager.getInstance();
    this.environmentCollector = EnvironmentAttributesCollector.getInstance();

    // Configure logging
    Logger.configure(
      config.loggingEnabled,
      config.debugLoggingEnabled,
      config.logLevel
    );

    // Setup config change listeners to propagate changes to components
    this.setupConfigChangeListeners();

    // Initialize session ID with a default value
    this.sessionId = `cf_session_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;

    Logger.info(`CustomFit SDK initialized with client key: ${config.clientKey.substring(0, 8)}...`);
  }

  /**
   * Initialize or get the singleton instance of CFClient
   * This method ensures only one instance exists and handles concurrent initialization attempts
   */
  static async initialize(config: CFConfig, user: CFUser): Promise<CFClient> {
    // Fast path: if already initialized, return existing instance
    if (CFClient._instance) {
      Logger.info('CFClient singleton already exists, returning existing instance');
      return CFClient._instance;
    }

    // If initialization is in progress, wait for it to complete
    if (CFClient._isInitializing && CFClient._initializationPromise) {
      Logger.info('CFClient initialization already in progress, waiting for completion');
      return CFClient._initializationPromise;
    }

    Logger.info('Creating new CFClient singleton instance');
    CFClient._isInitializing = true;

    try {
      CFClient._initializationPromise = (async () => {
        const newInstance = new CFClient(config, user);
        await newInstance.initializeInternal();
        CFClient._instance = newInstance;
        CFClient._isInitializing = false;
        Logger.info('CFClient singleton created successfully');
        return newInstance;
      })();

      return await CFClient._initializationPromise;
    } catch (error) {
      CFClient._isInitializing = false;
      CFClient._initializationPromise = null;
      Logger.error(`Failed to create CFClient singleton: ${error}`);
      throw error;
    }
  }

  /**
   * Get the current singleton instance without initializing
   * @returns Current CFClient instance or null if not initialized
   */
  static getInstance(): CFClient | null {
    return CFClient._instance;
  }

  /**
   * Check if the singleton is initialized
   * @returns true if singleton exists, false otherwise
   */
  static isInitialized(): boolean {
    return CFClient._instance !== null;
  }

  /**
   * Check if initialization is currently in progress
   * @returns true if initialization is in progress, false otherwise
   */
  static isInitializing(): boolean {
    return CFClient._isInitializing;
  }

  /**
   * Shutdown the singleton and clear the instance
   * This allows for clean reinitialization
   */
  static async shutdownSingleton(): Promise<void> {
    if (CFClient._instance) {
      Logger.info('Shutting down CFClient singleton');
      await CFClient._instance.shutdown();
    }
    
    CFClient._instance = null;
    CFClient._isInitializing = false;
    CFClient._initializationPromise = null;
    Logger.info('CFClient singleton shutdown complete');
  }

  /**
   * Force reinitialize the singleton with new configuration
   * This will shutdown the existing instance and create a new one
   */
  static async reinitialize(config: CFConfig, user: CFUser): Promise<CFClient> {
    Logger.info('Reinitializing CFClient singleton');
    await CFClient.shutdownSingleton();
    return CFClient.initialize(config, user);
  }

  /**
   * Create a detached instance that bypasses the singleton pattern
   * Use this for special cases where you need multiple instances
   */
  static async createDetached(config: CFConfig, user: CFUser): Promise<CFClient> {
    Logger.info('Creating detached CFClient instance (bypassing singleton)');
    const detachedInstance = new CFClient(config, user);
    await detachedInstance.initializeInternal();
    return detachedInstance;
  }

  /**
   * @deprecated Use CFClient.initialize() instead
   */
  static async init(config: CFConfig, user: CFUser): Promise<CFClient> {
    Logger.warning('CFClient.init() is deprecated, use CFClient.initialize() instead');
    return CFClient.initialize(config, user);
  }

  /**
   * Initialize the client (renamed from initialize to avoid confusion)
   */
  private async initializeInternal(): Promise<void> {
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
      // SummaryManager starts automatically in constructor

      // Initialize SessionManager with configuration
      await this.initializeSessionManager();

      // Auto-collect environment attributes if enabled
      if (this.config.autoEnvAttributesEnabled) {
        this.enableAutoEnvironmentAttributes();
      }

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

    // Track config access summary for all config accesses
    if (value !== undefined) {
      Logger.debug(`📊 CONFIG ACCESS: Tracking summary for key: ${key}, value: ${result}`);
      Logger.debug(`📊 CONFIG ACCESS: configMetadata structure: ${JSON.stringify(this.configMetadata)}`);
      
      // Create config data structure matching Flutter/Kotlin pattern
      const configData = {
        key: key,
        id: key,
        config_id: key,
        experience_id: key,
        variation_id: key,
        version: '1.0.0',
      };
      
      this.summaryManager.pushSummary(configData).catch(error => {
        Logger.warning(`Failed to track config summary for ${key}: ${error}`);
      });
    }

    Logger.debug(`🔧 CONFIG VALUE: ${key} = ${result}`);
    return result;
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
   * Get all feature flags
   */
  getAllFlags(): Record<string, any> {
    if (!this.isInitialized) {
      Logger.warning('getAllFlags called before initialization');
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
    await this.summaryManager.flushSummaries();

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
   * Add user property (matches Kotlin naming)
   */
  addUserProperty(key: string, value: any): void {
    this.currentUser = this.currentUser.withProperty(key, value);
    Logger.debug(`🔧 User property added: ${key} = ${value}`);
  }

  /**
   * Add string property
   */
  addStringProperty(key: string, value: string): void {
    this.addUserProperty(key, value);
  }

  /**
   * Add number property
   */
  addNumberProperty(key: string, value: number): void {
    this.addUserProperty(key, value);
  }

  /**
   * Add boolean property
   */
  addBooleanProperty(key: string, value: boolean): void {
    this.addUserProperty(key, value);
  }

  /**
   * Add date property
   */
  addDateProperty(key: string, value: Date): void {
    this.addUserProperty(key, value);
  }

  /**
   * Add geo point property
   */
  addGeoPointProperty(key: string, lat: number, lon: number): void {
    this.addUserProperty(key, { lat, lon });
  }

  /**
   * Add JSON property
   */
  addJsonProperty(key: string, value: Record<string, any>): void {
    this.addUserProperty(key, value);
  }

  /**
   * Add multiple user properties (matches Kotlin naming)
   */
  addUserProperties(properties: Record<string, any>): void {
    this.currentUser = this.currentUser.withProperties(properties);
    Logger.debug(`🔧 User properties added: ${Object.keys(properties).join(', ')}`);
  }

  /**
   * Get user properties (matches Kotlin naming)
   */
  getUserProperties(): Record<string, any> {
    return this.currentUser.properties || {};
  }





  /**
   * Update user
   */
  setUser(user: CFUser): void {
    this.currentUser = user;
    this.eventTracker.setUser(user);
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

    return await this.summaryManager.flushSummaries();
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
  private getMutableConfig(): CFConfig {
    return this.config;
  }

  /**
   * Setup configuration change listeners to propagate changes to components
   */
  private setupConfigChangeListeners(): void {
    this.mutableConfig.addListener((newConfig) => {
      try {
        // Update logging configuration
        Logger.configure(newConfig.loggingEnabled, newConfig.debugLoggingEnabled, newConfig.logLevel);
        
        // Update SummaryManager flush interval if changed
        if (newConfig.summariesFlushIntervalMs !== this.config.summariesFlushIntervalMs) {
          this.summaryManager.updateFlushInterval(newConfig.summariesFlushIntervalMs);
        }
        
        // Update EventTracker flush interval if changed
        if (newConfig.eventsFlushIntervalMs !== this.config.eventsFlushIntervalMs) {
          this.eventTracker.updateFlushInterval(newConfig.eventsFlushIntervalMs);
        }
        
        Logger.debug('🔧 Configuration updated and propagated to components');
      } catch (e) {
        Logger.error(`Failed to propagate config changes: ${e}`);
      }
    });
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
    this.addUserProperty('launch_count', currentLaunchCount + 1);
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
    this.summaryManager.shutdown();
    this.connectionMonitor.stopMonitoring();
    this.appStateManager.stopMonitoring();

    // Shutdown SessionManager
    SessionManager.shutdown();
    this.sessionManager = null;

    // Clear all listeners
    this.featureFlagListeners.clear();
    this.allFlagsListeners.clear();
    this.connectionListeners.clear();

    this.isInitialized = false;
    CFClient._instance = null;

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
  private async getEnvironmentAttributes(): Promise<Record<string, any>> {
    return await this.environmentCollector.getAllAttributes();
  }

  /**
   * Enable automatic environment attributes collection (matches Kotlin)
   */
  private enableAutoEnvAttributes(): void {
    this.enableAutoEnvironmentAttributes();
  }

  /**
   * Disable automatic environment attributes collection (matches Kotlin)
   */
  private disableAutoEnvAttributes(): void {
    Logger.info('🔧 Auto environment attributes disabled');
    // Implementation would stop including environment attributes
  }

  /**
   * Enable automatic environment attributes collection
   */
  enableAutoEnvironmentAttributes(): void {
    if (!this.config.autoEnvAttributesEnabled) {
      Logger.warning('🔧 Auto environment attributes are disabled in config');
      return;
    }
    
    Logger.info('🔧 Auto environment attributes enabled, collecting device and application info');
    
    // Collect and set device context automatically
    const deviceContext = this.collectDeviceContext(this.currentUser.device);
    if (deviceContext) {
      this.currentUser = this.currentUser.withDeviceContext(deviceContext);
      Logger.debug('Auto-collected device context: ' + (deviceContext.manufacturer || 'unknown') + ' ' + (deviceContext.model || 'unknown'));
    }

    // Collect and set application info automatically
    const appInfo = this.collectApplicationInfo(this.currentUser.application);
    if (appInfo) {
      this.currentUser = this.currentUser.withApplicationInfo(appInfo);
      Logger.debug('Auto-collected application info: ' + (appInfo.appName || 'unknown') + ' v' + (appInfo.versionName || 'unknown'));
    }
  }

  /**
   * Collect device context information automatically
   */
  private collectDeviceContext(existingContext?: DeviceContext): DeviceContext | null {
    try {
      // TODO: Implement actual device info collection using React Native APIs
      // For now, return basic React Native information
      return {
        manufacturer: existingContext?.manufacturer || 'Unknown',
        model: existingContext?.model || 'Unknown',
        osName: existingContext?.osName || 'React Native',
        osVersion: existingContext?.osVersion || 'Unknown',
        sdkVersion: '1.0.0',
        locale: existingContext?.locale,
        timezone: existingContext?.timezone,
        customAttributes: existingContext?.customAttributes || {},
      };
    } catch (error) {
      Logger.error('Failed to collect device context: ' + error);
      return null;
    }
  }

  /**
   * Collect application info automatically
   */
  private collectApplicationInfo(existingInfo?: ApplicationInfo): ApplicationInfo | null {
    try {
      // TODO: Implement actual app info collection using React Native APIs
      // For now, return basic information
      return {
        appName: existingInfo?.appName || 'React Native App',
        packageName: existingInfo?.packageName || 'com.example.app',
        versionName: existingInfo?.versionName || '1.0.0',
        versionCode: existingInfo?.versionCode || 1,
        buildNumber: existingInfo?.buildNumber || '1',
        launchCount: (existingInfo?.launchCount || 0) + 1,
        customAttributes: existingInfo?.customAttributes || {},
      };
    } catch (error) {
      Logger.error('Failed to collect application info: ' + error);
      return null;
    }
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



  // Private methods

  private async checkSdkSettings(): Promise<void> {
    if (!this.config.dimensionId) {
      return;
    }

    try {
      const previousSettings = this.sdkSettings;
      const result = await this.configFetcher.checkSdkSettings(this.config.dimensionId);
      
      if (result.isSuccess) {
        this.sdkSettings = result.data || null;
        Logger.debug(`🔧 SDK settings checked: ${JSON.stringify(this.sdkSettings)}`);
        
        // Only refresh configurations if SDK settings indicate a change
        if (this.hasConfigurationChanged(previousSettings, this.sdkSettings)) {
          Logger.info('🔧 SDK settings indicate config changes detected, refreshing configurations...');
          await this.refreshConfigurations();
        } else {
          Logger.debug('🔧 No configuration changes detected from SDK settings');
        }
      } else {
        Logger.warning(`🔧 Failed to check SDK settings: ${result.error?.message}`);
      }
    } catch (error) {
      Logger.error(`🔧 Exception checking SDK settings: ${error}`);
    }
  }

  /**
   * Check if configuration has changed based on SDK settings
   */
  private hasConfigurationChanged(previousSettings: any, currentSettings: any): boolean {
    // If this is the first check, always refresh
    if (!previousSettings && currentSettings) {
      Logger.debug('🔧 First SDK settings check, triggering config refresh');
      return true;
    }

    // If settings are missing, don't refresh
    if (!currentSettings) {
      Logger.debug('🔧 No current SDK settings, skipping config refresh');
      return false;
    }

    // Compare relevant fields that would indicate config changes
    if (previousSettings) {
      // Check if any relevant fields have changed
      const fieldsToCheck = ['lastModified', 'version', 'configVersion', 'hash', 'timestamp'];
      
      for (const field of fieldsToCheck) {
        if (previousSettings[field] !== currentSettings[field]) {
          Logger.info(`🔧 Configuration change detected in field '${field}': ${previousSettings[field]} -> ${currentSettings[field]}`);
          return true;
        }
      }
      
      // Check if the entire object structure has changed
      const prevJson = JSON.stringify(previousSettings);
      const currJson = JSON.stringify(currentSettings);
      
      if (prevJson !== currJson) {
        Logger.info('🔧 Configuration change detected in SDK settings structure');
        return true;
      }
      
      Logger.debug('🔧 No changes detected in SDK settings');
      return false;
    }

    // If we can't compare, be conservative and refresh
    Logger.debug('🔧 Cannot compare SDK settings, defaulting to refresh');
    return true;
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
        this.currentUser.toUserMap(),
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
        return CFResult.error(result.error!);
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
    // Get battery-aware polling interval for SDK settings only
    const sdkSettingsInterval = this.appStateManager.getPollingInterval(
      this.config.sdkSettingsCheckIntervalMs,
      this.config.reducedPollingIntervalMs,
      this.config.useReducedPollingWhenBatteryLow
    );

    // Only use SDK settings check timer - config refresh is now triggered by change detection
    this.sdkSettingsCheckTimer = setInterval(async () => {
      if (!this.isOfflineMode && this.connectionMonitor.isConnected()) {
        await this.checkSdkSettings();
      }
    }, sdkSettingsInterval);

    Logger.debug(`🔧 Background polling started (SDK settings check: ${sdkSettingsInterval}ms, config refresh: triggered by changes)`);
  }

  private stopBackgroundPolling(): void {
    if (this.sdkSettingsCheckTimer) {
      clearInterval(this.sdkSettingsCheckTimer);
      this.sdkSettingsCheckTimer = null;
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
        Logger.info(`🔧 App state changed from: ${previousState} to: ${newState}`);
        
        if (newState === AppState.BACKGROUND && this.config.disableBackgroundPolling) {
          // Pause polling when app goes to background if configured
          Logger.info('🔧 App entered background - pausing operations due to disableBackgroundPolling=true');
          this.stopBackgroundPolling();
          // Notify SessionManager about background transition
          this.sessionManager?.onAppBackground();
        } else if (newState === AppState.ACTIVE && previousState === AppState.BACKGROUND) {
          // Resume polling when app comes to foreground
          Logger.info('🔧 App entered foreground - resuming operations');
          if (!this.config.disableBackgroundPolling) {
            this.startBackgroundPolling();
          }
          // Refresh configurations immediately when coming to foreground
          this.refreshConfigurations();
          // Notify SessionManager about foreground transition
          this.sessionManager?.onAppForeground();
          // Update session activity
          this.sessionManager?.updateActivity();
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

  /**
   * Initialize SessionManager with configuration
   */
  private async initializeSessionManager(): Promise<void> {
    // Create session configuration based on CFConfig defaults
    const sessionConfig: SessionConfig = {
      maxSessionDurationMs: 60 * 60 * 1000, // 1 hour default
      minSessionDurationMs: 5 * 60 * 1000,  // 5 minutes minimum
      backgroundThresholdMs: 15 * 60 * 1000, // 15 minutes background threshold
      rotateOnAppRestart: true,
      rotateOnAuthChange: true,
      sessionIdPrefix: 'cf_session',
      enableTimeBasedRotation: true,
    };

    try {
      const result = await SessionManager.initialize(sessionConfig);
      
      if (result.isSuccess) {
        this.sessionManager = result.data!;
        if (this.sessionManager) {
          // Get the current session ID
          this.sessionId = this.sessionManager.getCurrentSessionId();

          // Set up session rotation listener
          const listener = new CFClientSessionListener(this);
          this.sessionManager.addListener(listener);

          Logger.info('🔄 SessionManager initialized with session: ' + this.sessionId);
        }
      } else {
        Logger.error('Failed to initialize SessionManager: ' + (result.error?.message || 'unknown error'));
      }
    } catch (error) {
      Logger.error('SessionManager initialization error: ' + error);
    }
  }

  /**
   * Update session ID in all managers that use it
   */
  public updateSessionIdInManagers(sessionId: string): void {
    // TODO: EventTracker and SummaryManager don't have updateSessionId methods
    // These would need to be enhanced to support dynamic session ID updates
    // For now, we'll just log the session change

    this.sessionId = sessionId;
    Logger.debug('Updated session ID in managers: ' + sessionId);
  }

  /**
   * Track session rotation as an analytics event
   */
  public trackSessionRotationEvent(oldSessionId: string | null, newSessionId: string, reason: RotationReason): void {
    const properties: Record<string, any> = {
      old_session_id: oldSessionId || 'none',
      new_session_id: newSessionId,
      rotation_reason: reason,
      timestamp: Date.now(),
    };

    this.trackEvent('cf_session_rotated', properties);
  }

  // MARK: - Session Management Public API

  /**
   * Get the current session ID
   */
  getCurrentSessionId(): string {
    return this.sessionManager?.getCurrentSessionId() || this.sessionId;
  }

  /**
   * Get current session data with metadata
   */
  getCurrentSessionData(): SessionData | null {
    return this.sessionManager?.getCurrentSession() || null;
  }

  /**
   * Force session rotation with a manual trigger
   * Returns the new session ID after rotation
   */
  async forceSessionRotation(): Promise<string | null> {
    return await this.sessionManager?.forceRotation() || null;
  }

  /**
   * Update session activity (should be called on user interactions)
   * This helps maintain session continuity by updating the last active timestamp
   */
  async updateSessionActivity(): Promise<void> {
    await this.sessionManager?.updateActivity();
  }

  /**
   * Handle user authentication changes
   * This will trigger session rotation if configured to do so
   */
  async onUserAuthenticationChange(userId?: string): Promise<void> {
    await this.sessionManager?.onAuthenticationChange(userId);
  }

  /**
   * Get session statistics for debugging and monitoring
   */
  getSessionStatistics(): Record<string, any> {
    return this.sessionManager?.getSessionStats() || {
      hasActiveSession: false,
      sessionId: this.sessionId,
      sessionManagerInitialized: false,
    };
  }

  /**
   * Add a session rotation listener to be notified of session changes
   */
  addSessionRotationListener(listener: SessionRotationListener): void {
    this.sessionManager?.addListener(listener);
  }

  /**
   * Remove a session rotation listener
   */
  removeSessionRotationListener(listener: SessionRotationListener): void {
    this.sessionManager?.removeListener(listener);
  }

  // MARK: - Context Management Public API

  /**
   * Add an evaluation context to the user
   */
  addContext(context: EvaluationContext): void {
    try {
      this.currentUser = this.currentUser.withContext(context);
      Logger.debug('Added evaluation context: ' + context.type + ':' + context.key);
    } catch (error) {
      Logger.error('Failed to add context: ' + error);
    }
  }

  /**
   * Remove an evaluation context from the user
   */
  removeContext(type: ContextType, key: string): void {
    try {
      this.currentUser = this.currentUser.removeContext(type, key);
      Logger.debug('Removed evaluation context: ' + type + ':' + key);
    } catch (error) {
      Logger.error('Failed to remove context: ' + error);
    }
  }

  /**
   * Get all evaluation contexts for the user
   */
  getContexts(): EvaluationContext[] {
    try {
      return this.currentUser.contexts || [];
    } catch (error) {
      Logger.error('Failed to get contexts: ' + error);
      return [];
    }
  }

  // MARK: - Runtime Configuration Updates

  /**
   * Update the SDK settings check interval at runtime
   * @param intervalMs New interval in milliseconds
   */
  updateSdkSettingsCheckInterval(intervalMs: number): void {
    try {
      this.mutableConfig.updateSdkSettingsCheckInterval(intervalMs);
      Logger.info(`🔧 Updated SDK settings check interval to ${intervalMs}ms`);
    } catch (e) {
      Logger.error(`Failed to update SDK settings check interval: ${e}`);
    }
  }

  /**
   * Update the events flush interval at runtime
   * @param intervalMs New interval in milliseconds
   */
  updateEventsFlushInterval(intervalMs: number): void {
    try {
      this.mutableConfig.updateEventsFlushInterval(intervalMs);
      Logger.info(`🔧 Updated events flush interval to ${intervalMs}ms`);
    } catch (e) {
      Logger.error(`Failed to update events flush interval: ${e}`);
    }
  }

  /**
   * Update the summaries flush interval at runtime
   * @param intervalMs New interval in milliseconds
   */
  updateSummariesFlushInterval(intervalMs: number): void {
    try {
      this.mutableConfig.updateSummariesFlushInterval(intervalMs);
      Logger.info(`🔧 Updated summaries flush interval to ${intervalMs}ms`);
    } catch (e) {
      Logger.error(`Failed to update summaries flush interval: ${e}`);
    }
  }

  /**
   * Update the network connection timeout at runtime
   * @param timeoutMs New timeout in milliseconds
   */
  updateNetworkConnectionTimeout(timeoutMs: number): void {
    try {
      this.mutableConfig.updateNetworkConnectionTimeout(timeoutMs);
      Logger.info(`🔧 Updated network connection timeout to ${timeoutMs}ms`);
    } catch (e) {
      Logger.error(`Failed to update network connection timeout: ${e}`);
    }
  }

  /**
   * Update the network read timeout at runtime
   * @param timeoutMs New timeout in milliseconds
   */
  updateNetworkReadTimeout(timeoutMs: number): void {
    try {
      this.mutableConfig.updateNetworkReadTimeout(timeoutMs);
      Logger.info(`🔧 Updated network read timeout to ${timeoutMs}ms`);
    } catch (e) {
      Logger.error(`Failed to update network read timeout: ${e}`);
    }
  }

  /**
   * Enable or disable debug logging at runtime
   * @param enabled Whether debug logging should be enabled
   */
  setDebugLoggingEnabled(enabled: boolean): void {
    try {
      this.mutableConfig.setDebugLoggingEnabled(enabled);
      Logger.configure(this.mutableConfig.config.loggingEnabled, enabled, this.mutableConfig.config.logLevel);
      Logger.info(`🔧 Debug logging ${enabled ? 'enabled' : 'disabled'}`);
    } catch (e) {
      Logger.error(`Failed to update debug logging setting: ${e}`);
    }
  }

  /**
   * Enable or disable logging at runtime
   * @param enabled Whether logging should be enabled
   */
  setLoggingEnabled(enabled: boolean): void {
    try {
      this.mutableConfig.setLoggingEnabled(enabled);
      Logger.configure(enabled, this.mutableConfig.config.debugLoggingEnabled, this.mutableConfig.config.logLevel);
      Logger.info(`🔧 Logging ${enabled ? 'enabled' : 'disabled'}`);
    } catch (e) {
      Logger.error(`Failed to update logging setting: ${e}`);
    }
  }

  /**
   * Reset circuit breakers to recover from connection issues
   * This is useful when switching from offline to online mode or recovering from CORS issues
   */
  resetCircuitBreakers(): void {
    try {
      // Reset main API circuit breaker
      this.configFetcher.resetCircuitBreaker();
      
      // Reset HTTP clients used by other components
      this.eventTracker.resetCircuitBreaker();
      // SummaryManager uses the same HttpClient instance
      
      Logger.info('🔧 Circuit breakers reset successfully');
    } catch (e) {
      Logger.error(`Failed to reset circuit breakers: ${e}`);
    }
  }
}

/**
 * Session rotation listener that integrates with CFClient
 */
class CFClientSessionListener implements SessionRotationListener {
  private cfClient: CFClient;

  constructor(cfClient: CFClient) {
    this.cfClient = cfClient;
  }

  onSessionRotated(oldSessionId: string | null, newSessionId: string, reason: RotationReason): void {
    Logger.info('🔄 Session rotated: ' + (oldSessionId || 'null') + ' -> ' + newSessionId + ' (' + reason + ')');

    // Update session ID in managers
    this.cfClient.updateSessionIdInManagers(newSessionId);

    // Track session rotation event
    this.cfClient.trackSessionRotationEvent(oldSessionId, newSessionId, reason);
  }

  onSessionRestored(sessionId: string): void {
    Logger.info('🔄 Session restored: ' + sessionId);

    // Update session ID in managers
    this.cfClient.updateSessionIdInManagers(sessionId);
  }

  onSessionError(error: string): void {
    Logger.error('🔄 Session error: ' + error);
  }
}