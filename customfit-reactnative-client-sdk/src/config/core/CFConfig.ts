import { CFConfig, CFConfigBuilder } from '../../core/types/CFTypes';
import { CFConstants } from '../../constants/CFConstants';

/**
 * Configuration implementation for the CustomFit React Native SDK
 */
export class CFConfigImpl implements CFConfig {
  readonly clientKey: string;
  readonly dimensionId?: string;
  
  // Event tracker configuration
  readonly eventsQueueSize: number;
  readonly eventsFlushTimeSeconds: number;
  readonly eventsFlushIntervalMs: number;
  readonly maxStoredEvents: number;
  
  // Retry configuration
  readonly maxRetryAttempts: number;
  readonly retryInitialDelayMs: number;
  readonly retryMaxDelayMs: number;
  readonly retryBackoffMultiplier: number;
  
  // Summary manager configuration
  readonly summariesQueueSize: number;
  readonly summariesFlushTimeSeconds: number;
  readonly summariesFlushIntervalMs: number;
  
  // SDK settings check configuration
  readonly sdkSettingsCheckIntervalMs: number;
  
  // Network configuration
  readonly networkConnectionTimeoutMs: number;
  readonly networkReadTimeoutMs: number;
  
  // Logging configuration
  readonly loggingEnabled: boolean;
  readonly debugLoggingEnabled: boolean;
  readonly logLevel: string;
  
  // Offline mode
  readonly offlineMode: boolean;
  
  // Background operation settings
  readonly disableBackgroundPolling: boolean;
  readonly backgroundPollingIntervalMs: number;
  readonly useReducedPollingWhenBatteryLow: boolean;
  readonly reducedPollingIntervalMs: number;
  
  // Auto environment attributes
  readonly autoEnvAttributesEnabled: boolean;

  constructor(
    clientKey: string,
    eventsQueueSize: number = CFConstants.EventDefaults.QUEUE_SIZE,
    eventsFlushTimeSeconds: number = CFConstants.EventDefaults.FLUSH_TIME_SECONDS,
    eventsFlushIntervalMs: number = CFConstants.EventDefaults.FLUSH_INTERVAL_MS,
    maxStoredEvents: number = CFConstants.EventDefaults.MAX_STORED_EVENTS,
    maxRetryAttempts: number = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS,
    retryInitialDelayMs: number = CFConstants.RetryConfig.INITIAL_DELAY_MS,
    retryMaxDelayMs: number = CFConstants.RetryConfig.MAX_DELAY_MS,
    retryBackoffMultiplier: number = CFConstants.RetryConfig.BACKOFF_MULTIPLIER,
    summariesQueueSize: number = CFConstants.SummaryDefaults.QUEUE_SIZE,
    summariesFlushTimeSeconds: number = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS,
    summariesFlushIntervalMs: number = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS,
    sdkSettingsCheckIntervalMs: number = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS,
    networkConnectionTimeoutMs: number = CFConstants.Network.CONNECTION_TIMEOUT_MS,
    networkReadTimeoutMs: number = CFConstants.Network.READ_TIMEOUT_MS,
    loggingEnabled: boolean = true,
    debugLoggingEnabled: boolean = false,
    logLevel: string = CFConstants.Logging.DEFAULT_LOG_LEVEL,
    offlineMode: boolean = false,
    disableBackgroundPolling: boolean = false,
    backgroundPollingIntervalMs: number = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS,
    useReducedPollingWhenBatteryLow: boolean = true,
    reducedPollingIntervalMs: number = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS,
    autoEnvAttributesEnabled: boolean = true
  ) {
    this.clientKey = clientKey;
    this.dimensionId = this.extractDimensionIdFromToken(clientKey);
    
    this.eventsQueueSize = eventsQueueSize;
    this.eventsFlushTimeSeconds = eventsFlushTimeSeconds;
    this.eventsFlushIntervalMs = eventsFlushIntervalMs;
    this.maxStoredEvents = maxStoredEvents;
    
    this.maxRetryAttempts = maxRetryAttempts;
    this.retryInitialDelayMs = retryInitialDelayMs;
    this.retryMaxDelayMs = retryMaxDelayMs;
    this.retryBackoffMultiplier = retryBackoffMultiplier;
    
    this.summariesQueueSize = summariesQueueSize;
    this.summariesFlushTimeSeconds = summariesFlushTimeSeconds;
    this.summariesFlushIntervalMs = summariesFlushIntervalMs;
    
    this.sdkSettingsCheckIntervalMs = sdkSettingsCheckIntervalMs;
    
    this.networkConnectionTimeoutMs = networkConnectionTimeoutMs;
    this.networkReadTimeoutMs = networkReadTimeoutMs;
    
    this.loggingEnabled = loggingEnabled;
    this.debugLoggingEnabled = debugLoggingEnabled;
    this.logLevel = logLevel;
    
    this.offlineMode = offlineMode;
    
    this.disableBackgroundPolling = disableBackgroundPolling;
    this.backgroundPollingIntervalMs = backgroundPollingIntervalMs;
    this.useReducedPollingWhenBatteryLow = useReducedPollingWhenBatteryLow;
    this.reducedPollingIntervalMs = reducedPollingIntervalMs;
    
    this.autoEnvAttributesEnabled = autoEnvAttributesEnabled;
  }

  /**
   * Extract dimension ID from JWT token
   */
  private extractDimensionIdFromToken(token: string): string | undefined {
    if (!token) {
      return undefined;
    }

    try {
      // Split the token by periods
      const parts = token.split('.');
      if (parts.length < 2) {
        return undefined;
      }

      // Base64 decode the payload part
      const payload = parts[1];
      const paddedPayload = this.padBase64String(payload);
      
      // Decode base64
      const decoded = atob(paddedPayload);
      
      // Parse JSON
      const json = JSON.parse(decoded);
      
      return json.dimension_id;
    } catch (error) {
      console.warn('Failed to extract dimension_id from token:', error);
      return undefined;
    }
  }

  /**
   * Pad base64 string to make it valid
   */
  private padBase64String(str: string): string {
    const missing = str.length % 4;
    if (missing) {
      return str + '='.repeat(4 - missing);
    }
    return str;
  }

  /**
   * Create a builder for CFConfig
   */
  static builder(clientKey: string): CFConfigBuilder {
    return new CFConfigBuilderImpl(clientKey);
  }
}

/**
 * Builder for creating CFConfig instances
 */
export class CFConfigBuilderImpl implements CFConfigBuilder {
  private clientKey: string;
  private _eventsQueueSize: number = CFConstants.EventDefaults.QUEUE_SIZE;
  private _eventsFlushTimeSeconds: number = CFConstants.EventDefaults.FLUSH_TIME_SECONDS;
  private _eventsFlushIntervalMs: number = CFConstants.EventDefaults.FLUSH_INTERVAL_MS;
  private _maxStoredEvents: number = CFConstants.EventDefaults.MAX_STORED_EVENTS;
  private _maxRetryAttempts: number = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS;
  private _retryInitialDelayMs: number = CFConstants.RetryConfig.INITIAL_DELAY_MS;
  private _retryMaxDelayMs: number = CFConstants.RetryConfig.MAX_DELAY_MS;
  private _retryBackoffMultiplier: number = CFConstants.RetryConfig.BACKOFF_MULTIPLIER;
  private _summariesQueueSize: number = CFConstants.SummaryDefaults.QUEUE_SIZE;
  private _summariesFlushTimeSeconds: number = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS;
  private _summariesFlushIntervalMs: number = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS;
  private _sdkSettingsCheckIntervalMs: number = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS;
  private _networkConnectionTimeoutMs: number = CFConstants.Network.CONNECTION_TIMEOUT_MS;
  private _networkReadTimeoutMs: number = CFConstants.Network.READ_TIMEOUT_MS;
  private _loggingEnabled: boolean = true;
  private _debugLoggingEnabled: boolean = false;
  private _logLevel: string = CFConstants.Logging.DEFAULT_LOG_LEVEL;
  private _offlineMode: boolean = false;
  private _disableBackgroundPolling: boolean = false;
  private _backgroundPollingIntervalMs: number = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS;
  private _useReducedPollingWhenBatteryLow: boolean = true;
  private _reducedPollingIntervalMs: number = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS;
  private _autoEnvAttributesEnabled: boolean = true;

  constructor(clientKey: string) {
    this.clientKey = clientKey;
  }

  eventsQueueSize(size: number): CFConfigBuilder {
    if (size <= 0) throw new Error('Events queue size must be greater than 0');
    this._eventsQueueSize = size;
    return this;
  }

  eventsFlushTimeSeconds(seconds: number): CFConfigBuilder {
    if (seconds <= 0) throw new Error('Events flush time must be greater than 0');
    this._eventsFlushTimeSeconds = seconds;
    return this;
  }

  eventsFlushIntervalMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Events flush interval must be greater than 0');
    this._eventsFlushIntervalMs = ms;
    return this;
  }

  maxStoredEvents(max: number): CFConfigBuilder {
    if (max < 0) throw new Error('Max stored events must be non-negative');
    this._maxStoredEvents = max;
    return this;
  }

  maxRetryAttempts(attempts: number): CFConfigBuilder {
    if (attempts < 0) throw new Error('Max retry attempts must be non-negative');
    this._maxRetryAttempts = attempts;
    return this;
  }

  retryInitialDelayMs(delayMs: number): CFConfigBuilder {
    if (delayMs <= 0) throw new Error('Initial delay must be greater than 0');
    this._retryInitialDelayMs = delayMs;
    return this;
  }

  retryMaxDelayMs(delayMs: number): CFConfigBuilder {
    if (delayMs <= 0) throw new Error('Max delay must be greater than 0');
    this._retryMaxDelayMs = delayMs;
    return this;
  }

  retryBackoffMultiplier(multiplier: number): CFConfigBuilder {
    if (multiplier <= 1.0) throw new Error('Backoff multiplier must be greater than 1.0');
    this._retryBackoffMultiplier = multiplier;
    return this;
  }

  summariesQueueSize(size: number): CFConfigBuilder {
    if (size <= 0) throw new Error('Summaries queue size must be greater than 0');
    this._summariesQueueSize = size;
    return this;
  }

  summariesFlushTimeSeconds(seconds: number): CFConfigBuilder {
    if (seconds <= 0) throw new Error('Summaries flush time must be greater than 0');
    this._summariesFlushTimeSeconds = seconds;
    return this;
  }

  summariesFlushIntervalMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Summaries flush interval must be greater than 0');
    this._summariesFlushIntervalMs = ms;
    return this;
  }

  sdkSettingsCheckIntervalMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('SDK settings check interval must be greater than 0');
    this._sdkSettingsCheckIntervalMs = ms;
    return this;
  }

  networkConnectionTimeoutMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Network connection timeout must be greater than 0');
    this._networkConnectionTimeoutMs = ms;
    return this;
  }

  networkReadTimeoutMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Network read timeout must be greater than 0');
    this._networkReadTimeoutMs = ms;
    return this;
  }

  loggingEnabled(enabled: boolean): CFConfigBuilder {
    this._loggingEnabled = enabled;
    return this;
  }

  debugLoggingEnabled(enabled: boolean): CFConfigBuilder {
    this._debugLoggingEnabled = enabled;
    return this;
  }

  logLevel(level: string): CFConfigBuilder {
    if (!CFConstants.Logging.VALID_LOG_LEVELS.includes(level as any)) {
      throw new Error(`Log level must be one of: ${CFConstants.Logging.VALID_LOG_LEVELS.join(', ')}`);
    }
    this._logLevel = level;
    return this;
  }

  offlineMode(offline: boolean): CFConfigBuilder {
    this._offlineMode = offline;
    return this;
  }

  disableBackgroundPolling(disable: boolean): CFConfigBuilder {
    this._disableBackgroundPolling = disable;
    return this;
  }

  backgroundPollingIntervalMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Background polling interval must be greater than 0');
    this._backgroundPollingIntervalMs = ms;
    return this;
  }

  useReducedPollingWhenBatteryLow(use: boolean): CFConfigBuilder {
    this._useReducedPollingWhenBatteryLow = use;
    return this;
  }

  reducedPollingIntervalMs(ms: number): CFConfigBuilder {
    if (ms <= 0) throw new Error('Reduced polling interval must be greater than 0');
    this._reducedPollingIntervalMs = ms;
    return this;
  }

  autoEnvAttributesEnabled(enabled: boolean): CFConfigBuilder {
    this._autoEnvAttributesEnabled = enabled;
    return this;
  }

  build(): CFConfig {
    return new CFConfigImpl(
      this.clientKey,
      this._eventsQueueSize,
      this._eventsFlushTimeSeconds,
      this._eventsFlushIntervalMs,
      this._maxStoredEvents,
      this._maxRetryAttempts,
      this._retryInitialDelayMs,
      this._retryMaxDelayMs,
      this._retryBackoffMultiplier,
      this._summariesQueueSize,
      this._summariesFlushTimeSeconds,
      this._summariesFlushIntervalMs,
      this._sdkSettingsCheckIntervalMs,
      this._networkConnectionTimeoutMs,
      this._networkReadTimeoutMs,
      this._loggingEnabled,
      this._debugLoggingEnabled,
      this._logLevel,
      this._offlineMode,
      this._disableBackgroundPolling,
      this._backgroundPollingIntervalMs,
      this._useReducedPollingWhenBatteryLow,
      this._reducedPollingIntervalMs,
      this._autoEnvAttributesEnabled
    );
  }
} 