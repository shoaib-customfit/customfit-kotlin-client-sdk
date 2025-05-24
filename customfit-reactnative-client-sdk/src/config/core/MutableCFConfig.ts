import { CFConfig } from '../../core/types/CFTypes';
import { CFConfigImpl } from './CFConfig';
import { Logger } from '../../logging/Logger';

/**
 * Mutable configuration wrapper for runtime updates
 */
export class MutableCFConfig {
  private _config: CFConfig;
  private readonly _listeners: Array<(config: CFConfig) => void> = [];

  constructor(config: CFConfig) {
    this._config = config;
  }

  /**
   * Get current immutable config
   */
  get config(): CFConfig {
    return this._config;
  }

  /**
   * Add a listener for config changes
   */
  addListener(listener: (config: CFConfig) => void): void {
    this._listeners.push(listener);
  }

  /**
   * Remove a listener
   */
  removeListener(listener: (config: CFConfig) => void): void {
    const index = this._listeners.indexOf(listener);
    if (index > -1) {
      this._listeners.splice(index, 1);
    }
  }

  /**
   * Update configuration and notify listeners
   */
  private updateConfig(newConfig: CFConfig): void {
    this._config = newConfig;
    for (const listener of this._listeners) {
      try {
        listener(newConfig);
      } catch (e) {
        Logger.error(`Error notifying config listener: ${e}`);
      }
    }
  }

  /**
   * Create a new config with updated values
   */
  private copyWith(updates: Partial<CFConfig>): CFConfig {
    return new CFConfigImpl(
      updates.clientKey ?? this._config.clientKey,
      updates.eventsQueueSize ?? this._config.eventsQueueSize,
      updates.eventsFlushTimeSeconds ?? this._config.eventsFlushTimeSeconds,
      updates.eventsFlushIntervalMs ?? this._config.eventsFlushIntervalMs,
      updates.maxStoredEvents ?? this._config.maxStoredEvents,
      updates.maxRetryAttempts ?? this._config.maxRetryAttempts,
      updates.retryInitialDelayMs ?? this._config.retryInitialDelayMs,
      updates.retryMaxDelayMs ?? this._config.retryMaxDelayMs,
      updates.retryBackoffMultiplier ?? this._config.retryBackoffMultiplier,
      updates.summariesQueueSize ?? this._config.summariesQueueSize,
      updates.summariesFlushTimeSeconds ?? this._config.summariesFlushTimeSeconds,
      updates.summariesFlushIntervalMs ?? this._config.summariesFlushIntervalMs,
      updates.sdkSettingsCheckIntervalMs ?? this._config.sdkSettingsCheckIntervalMs,
      updates.networkConnectionTimeoutMs ?? this._config.networkConnectionTimeoutMs,
      updates.networkReadTimeoutMs ?? this._config.networkReadTimeoutMs,
      updates.loggingEnabled ?? this._config.loggingEnabled,
      updates.debugLoggingEnabled ?? this._config.debugLoggingEnabled,
      updates.logLevel ?? this._config.logLevel,
      updates.offlineMode ?? this._config.offlineMode,
      updates.disableBackgroundPolling ?? this._config.disableBackgroundPolling,
      updates.backgroundPollingIntervalMs ?? this._config.backgroundPollingIntervalMs,
      updates.useReducedPollingWhenBatteryLow ?? this._config.useReducedPollingWhenBatteryLow,
      updates.reducedPollingIntervalMs ?? this._config.reducedPollingIntervalMs,
      updates.autoEnvAttributesEnabled ?? this._config.autoEnvAttributesEnabled
    );
  }

  /**
   * Update SDK settings check interval
   */
  updateSdkSettingsCheckInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      throw new Error('SDK settings check interval must be greater than 0');
    }
    this.updateConfig(this.copyWith({ sdkSettingsCheckIntervalMs: intervalMs }));
  }

  /**
   * Update events flush interval
   */
  updateEventsFlushInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      throw new Error('Events flush interval must be greater than 0');
    }
    this.updateConfig(this.copyWith({ eventsFlushIntervalMs: intervalMs }));
  }

  /**
   * Update summaries flush interval
   */
  updateSummariesFlushInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      throw new Error('Summaries flush interval must be greater than 0');
    }
    this.updateConfig(this.copyWith({ summariesFlushIntervalMs: intervalMs }));
  }

  /**
   * Update network connection timeout
   */
  updateNetworkConnectionTimeout(timeoutMs: number): void {
    if (timeoutMs <= 0) {
      throw new Error('Network connection timeout must be greater than 0');
    }
    this.updateConfig(this.copyWith({ networkConnectionTimeoutMs: timeoutMs }));
  }

  /**
   * Update network read timeout
   */
  updateNetworkReadTimeout(timeoutMs: number): void {
    if (timeoutMs <= 0) {
      throw new Error('Network read timeout must be greater than 0');
    }
    this.updateConfig(this.copyWith({ networkReadTimeoutMs: timeoutMs }));
  }

  /**
   * Set debug logging enabled
   */
  setDebugLoggingEnabled(enabled: boolean): void {
    this.updateConfig(this.copyWith({ debugLoggingEnabled: enabled }));
  }

  /**
   * Set logging enabled
   */
  setLoggingEnabled(enabled: boolean): void {
    this.updateConfig(this.copyWith({ loggingEnabled: enabled }));
  }

  /**
   * Set offline mode
   */
  setOfflineMode(offline: boolean): void {
    this.updateConfig(this.copyWith({ offlineMode: offline }));
  }
} 