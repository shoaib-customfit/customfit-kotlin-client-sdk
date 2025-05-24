import 'dart:convert';

/// Immutable configuration class with builder pattern
class CFConfig {
  /// Client key for authenticating with the CustomFit services
  final String clientKey;

  // Event tracker configuration
  /// Maximum number of events to queue before forcing a flush
  final int eventsQueueSize;

  /// Maximum time in seconds events should be kept in queue before flushing
  final int eventsFlushTimeSeconds;

  /// Interval in milliseconds for the event flush timer
  final int eventsFlushIntervalMs;

  // Retry configuration
  /// Maximum number of retry attempts for failed network requests
  final int maxRetryAttempts;

  /// Initial delay in milliseconds before the first retry attempt
  final int retryInitialDelayMs;

  /// Maximum delay in milliseconds between retry attempts
  final int retryMaxDelayMs;

  /// Multiplier for calculating exponential backoff between retries
  final double retryBackoffMultiplier;

  // Summary manager configuration
  /// Maximum number of summaries to queue before forcing a flush
  final int summariesQueueSize;

  /// Maximum time in seconds summaries should be kept in queue before flushing
  final int summariesFlushTimeSeconds;

  /// Interval in milliseconds for the summary flush timer
  final int summariesFlushIntervalMs;

  // SDK settings check configuration
  /// Interval in milliseconds for checking SDK settings
  final int sdkSettingsCheckIntervalMs;

  // Network configuration
  /// Connection timeout in milliseconds
  final int networkConnectionTimeoutMs;

  /// Read timeout in milliseconds
  final int networkReadTimeoutMs;

  // Logging configuration
  /// Whether logging is enabled
  final bool loggingEnabled;

  /// Whether debug logging is enabled
  final bool debugLoggingEnabled;

  /// Log level
  final String logLevel;

  // Offline mode
  /// Whether the SDK is in offline mode
  final bool offlineMode;

  // Background operation settings
  /// Whether to disable background polling
  final bool disableBackgroundPolling;

  /// Interval in milliseconds for background polling
  final int backgroundPollingIntervalMs;

  /// Whether to reduce polling frequency when battery is low
  final bool useReducedPollingWhenBatteryLow;

  /// Interval in milliseconds for reduced polling
  final int reducedPollingIntervalMs;

  /// Maximum number of events to store offline
  final int maxStoredEvents;

  // Environment attributes
  /// Whether to automatically collect environment attributes
  final bool autoEnvAttributesEnabled;

  // Local Storage Configuration
  /// Whether to enable local storage/caching
  final bool localStorageEnabled;

  /// Cache TTL in seconds for configuration data
  final int configCacheTtlSeconds;

  /// Cache TTL in seconds for event data
  final int eventCacheTtlSeconds;

  /// Cache TTL in seconds for summary data
  final int summaryCacheTtlSeconds;

  /// Maximum size of local cache in MB
  final int maxCacheSizeMb;

  /// Whether to persist cache across app restarts
  final bool persistCacheAcrossRestarts;

  /// Whether to use stale cache while revalidating
  final bool useStaleWhileRevalidate;

  /// Get dimension ID from client key
  String? get dimensionId => _extractDimensionIdFromToken(clientKey);

  /// Private constructor - use builder pattern instead
  CFConfig._({
    required this.clientKey,
    this.eventsQueueSize = 100, // Consistent with Swift/Kotlin
    this.eventsFlushTimeSeconds = 60, // Consistent with Swift/Kotlin
    this.eventsFlushIntervalMs = 1000, // Consistent with Swift/Kotlin (1 second)
    this.maxRetryAttempts = 3, // Consistent with Swift/Kotlin
    this.retryInitialDelayMs = 1000, // Consistent with Swift/Kotlin
    this.retryMaxDelayMs = 30000, // Consistent with Swift/Kotlin
    this.retryBackoffMultiplier = 2.0, // Consistent with Swift/Kotlin
    this.summariesQueueSize = 100, // Consistent with Swift/Kotlin
    this.summariesFlushTimeSeconds = 60, // Consistent with Swift/Kotlin
    this.summariesFlushIntervalMs = 60000, // Consistent with Swift/Kotlin (60 seconds)
    this.sdkSettingsCheckIntervalMs = 300000, // Consistent with Swift/Kotlin (5 minutes)
    this.networkConnectionTimeoutMs = 10000, // Consistent with Swift/Kotlin
    this.networkReadTimeoutMs = 10000, // Consistent with Swift/Kotlin (changed from 30000)
    this.loggingEnabled = true,
    this.debugLoggingEnabled = false,
    this.logLevel = 'DEBUG', // Consistent with Swift/Kotlin
    this.offlineMode = false,
    this.disableBackgroundPolling = false,
    this.backgroundPollingIntervalMs = 3600000, // Consistent with Swift/Kotlin (1 hour)
    this.useReducedPollingWhenBatteryLow = true,
    this.reducedPollingIntervalMs = 7200000, // Consistent with Swift/Kotlin (2 hours)
    this.maxStoredEvents = 100, // Consistent with Swift/Kotlin
    this.autoEnvAttributesEnabled = false,
    // Local Storage Configuration
    this.localStorageEnabled = true,
    this.configCacheTtlSeconds = 86400, // 24 hours
    this.eventCacheTtlSeconds = 3600, // 1 hour
    this.summaryCacheTtlSeconds = 3600, // 1 hour
    this.maxCacheSizeMb = 50, // 50 MB
    this.persistCacheAcrossRestarts = true,
    this.useStaleWhileRevalidate = true,
  });

  /// Extract dimension ID from token
  String? _extractDimensionIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonMap = jsonDecode(decoded) as Map<String, dynamic>;

      return jsonMap['dimension_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Create a copy of this config with updated values
  CFConfig copyWith({
    String? clientKey,
    int? eventsQueueSize,
    int? eventsFlushTimeSeconds,
    int? eventsFlushIntervalMs,
    int? maxRetryAttempts,
    int? retryInitialDelayMs,
    int? retryMaxDelayMs,
    double? retryBackoffMultiplier,
    int? summariesQueueSize,
    int? summariesFlushTimeSeconds,
    int? summariesFlushIntervalMs,
    int? sdkSettingsCheckIntervalMs,
    int? networkConnectionTimeoutMs,
    int? networkReadTimeoutMs,
    bool? loggingEnabled,
    bool? debugLoggingEnabled,
    String? logLevel,
    bool? offlineMode,
    bool? disableBackgroundPolling,
    int? backgroundPollingIntervalMs,
    bool? useReducedPollingWhenBatteryLow,
    int? reducedPollingIntervalMs,
    int? maxStoredEvents,
    bool? autoEnvAttributesEnabled,
    bool? localStorageEnabled,
    int? configCacheTtlSeconds,
    int? eventCacheTtlSeconds,
    int? summaryCacheTtlSeconds,
    int? maxCacheSizeMb,
    bool? persistCacheAcrossRestarts,
    bool? useStaleWhileRevalidate,
  }) {
    return CFConfig._(
      clientKey: clientKey ?? this.clientKey,
      eventsQueueSize: eventsQueueSize ?? this.eventsQueueSize,
      eventsFlushTimeSeconds: eventsFlushTimeSeconds ?? this.eventsFlushTimeSeconds,
      eventsFlushIntervalMs: eventsFlushIntervalMs ?? this.eventsFlushIntervalMs,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryInitialDelayMs: retryInitialDelayMs ?? this.retryInitialDelayMs,
      retryMaxDelayMs: retryMaxDelayMs ?? this.retryMaxDelayMs,
      retryBackoffMultiplier: retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      summariesQueueSize: summariesQueueSize ?? this.summariesQueueSize,
      summariesFlushTimeSeconds: summariesFlushTimeSeconds ?? this.summariesFlushTimeSeconds,
      summariesFlushIntervalMs: summariesFlushIntervalMs ?? this.summariesFlushIntervalMs,
      sdkSettingsCheckIntervalMs: sdkSettingsCheckIntervalMs ?? this.sdkSettingsCheckIntervalMs,
      networkConnectionTimeoutMs: networkConnectionTimeoutMs ?? this.networkConnectionTimeoutMs,
      networkReadTimeoutMs: networkReadTimeoutMs ?? this.networkReadTimeoutMs,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      debugLoggingEnabled: debugLoggingEnabled ?? this.debugLoggingEnabled,
      logLevel: logLevel ?? this.logLevel,
      offlineMode: offlineMode ?? this.offlineMode,
      disableBackgroundPolling: disableBackgroundPolling ?? this.disableBackgroundPolling,
      backgroundPollingIntervalMs: backgroundPollingIntervalMs ?? this.backgroundPollingIntervalMs,
      useReducedPollingWhenBatteryLow: useReducedPollingWhenBatteryLow ?? this.useReducedPollingWhenBatteryLow,
      reducedPollingIntervalMs: reducedPollingIntervalMs ?? this.reducedPollingIntervalMs,
      maxStoredEvents: maxStoredEvents ?? this.maxStoredEvents,
      autoEnvAttributesEnabled: autoEnvAttributesEnabled ?? this.autoEnvAttributesEnabled,
      localStorageEnabled: localStorageEnabled ?? this.localStorageEnabled,
      configCacheTtlSeconds: configCacheTtlSeconds ?? this.configCacheTtlSeconds,
      eventCacheTtlSeconds: eventCacheTtlSeconds ?? this.eventCacheTtlSeconds,
      summaryCacheTtlSeconds: summaryCacheTtlSeconds ?? this.summaryCacheTtlSeconds,
      maxCacheSizeMb: maxCacheSizeMb ?? this.maxCacheSizeMb,
      persistCacheAcrossRestarts: persistCacheAcrossRestarts ?? this.persistCacheAcrossRestarts,
      useStaleWhileRevalidate: useStaleWhileRevalidate ?? this.useStaleWhileRevalidate,
    );
  }

  /// Static factory method from client key only
  static CFConfig fromClientKey(String clientKey) => Builder(clientKey).build();

  /// Builder implementation for fluent API
  static Builder builder(String clientKey) => Builder(clientKey);
}

/// Builder class for CFConfig
class Builder {
  final String clientKey;
  int eventsQueueSize = 100;
  int eventsFlushTimeSeconds = 60;
  int eventsFlushIntervalMs = 1000;
  int maxRetryAttempts = 3;
  int retryInitialDelayMs = 1000;
  int retryMaxDelayMs = 30000;
  double retryBackoffMultiplier = 2.0;
  int summariesQueueSize = 100;
  int summariesFlushTimeSeconds = 60;
  int summariesFlushIntervalMs = 60000;
  int sdkSettingsCheckIntervalMs = 300000;
  int networkConnectionTimeoutMs = 10000;
  int networkReadTimeoutMs = 10000;
  bool loggingEnabled = true;
  bool debugLoggingEnabled = false;
  String logLevel = 'DEBUG';
  bool offlineMode = false;
  bool disableBackgroundPolling = false;
  int backgroundPollingIntervalMs = 3600000;
  bool useReducedPollingWhenBatteryLow = true;
  int reducedPollingIntervalMs = 7200000;
  int maxStoredEvents = 100;
  bool autoEnvAttributesEnabled = false;
  // Local Storage Configuration
  bool localStorageEnabled = true;
  int configCacheTtlSeconds = 86400;
  int eventCacheTtlSeconds = 3600;
  int summaryCacheTtlSeconds = 3600;
  int maxCacheSizeMb = 50;
  bool persistCacheAcrossRestarts = true;
  bool useStaleWhileRevalidate = true;

  /// Constructor
  Builder(this.clientKey) {
    if (clientKey.isEmpty) {
      throw ArgumentError("Client key cannot be empty");
    }
  }

  /// Set events queue size
  Builder setEventsQueueSize(int size) {
    if (size <= 0) {
      throw ArgumentError('Events queue size must be greater than 0');
    }
    eventsQueueSize = size;
    return this;
  }

  /// Set events flush time seconds
  Builder setEventsFlushTimeSeconds(int seconds) {
    if (seconds <= 0) {
      throw ArgumentError('Events flush time seconds must be greater than 0');
    }
    eventsFlushTimeSeconds = seconds;
    return this;
  }

  /// Set events flush interval in milliseconds
  Builder setEventsFlushIntervalMs(int ms) {
    eventsFlushIntervalMs = ms;
    return this;
  }

  /// Set max retry attempts
  Builder setMaxRetryAttempts(int attempts) {
    if (attempts < 0) {
      throw ArgumentError('Max retry attempts cannot be negative');
    }
    maxRetryAttempts = attempts;
    return this;
  }

  /// Set retry initial delay in milliseconds
  Builder setRetryInitialDelayMs(int ms) {
    retryInitialDelayMs = ms;
    return this;
  }

  /// Set retry max delay in milliseconds
  Builder setRetryMaxDelayMs(int ms) {
    retryMaxDelayMs = ms;
    return this;
  }

  /// Set retry backoff multiplier
  Builder setRetryBackoffMultiplier(double multiplier) {
    retryBackoffMultiplier = multiplier;
    return this;
  }

  /// Set summaries queue size
  Builder setSummariesQueueSize(int size) {
    summariesQueueSize = size;
    return this;
  }

  /// Set summaries flush time seconds
  Builder setSummariesFlushTimeSeconds(int seconds) {
    summariesFlushTimeSeconds = seconds;
    return this;
  }

  /// Set summaries flush interval in milliseconds
  Builder setSummariesFlushIntervalMs(int ms) {
    summariesFlushIntervalMs = ms;
    return this;
  }

  /// Set SDK settings check interval in milliseconds
  Builder setSdkSettingsCheckIntervalMs(int ms) {
    sdkSettingsCheckIntervalMs = ms;
    return this;
  }

  /// Set network connection timeout in milliseconds
  Builder setNetworkConnectionTimeoutMs(int ms) {
    networkConnectionTimeoutMs = ms;
    return this;
  }

  /// Set network read timeout in milliseconds
  Builder setNetworkReadTimeoutMs(int ms) {
    networkReadTimeoutMs = ms;
    return this;
  }

  /// Set whether logging is enabled
  Builder setLoggingEnabled(bool enabled) {
    loggingEnabled = enabled;
    return this;
  }

  /// Set whether debug logging is enabled
  Builder setDebugLoggingEnabled(bool enabled) {
    debugLoggingEnabled = enabled;
    return this;
  }

  /// Set log level
  Builder setLogLevel(String level) {
    logLevel = level;
    return this;
  }

  /// Set whether offline mode is enabled
  Builder setOfflineMode(bool enabled) {
    offlineMode = enabled;
    return this;
  }

  /// Set whether background polling is disabled
  Builder setDisableBackgroundPolling(bool disabled) {
    disableBackgroundPolling = disabled;
    return this;
  }

  /// Set background polling interval in milliseconds
  Builder setBackgroundPollingIntervalMs(int ms) {
    backgroundPollingIntervalMs = ms;
    return this;
  }

  /// Set whether to use reduced polling when battery is low
  Builder setUseReducedPollingWhenBatteryLow(bool use) {
    useReducedPollingWhenBatteryLow = use;
    return this;
  }

  /// Set reduced polling interval in milliseconds
  Builder setReducedPollingIntervalMs(int ms) {
    reducedPollingIntervalMs = ms;
    return this;
  }

  /// Set max stored events
  Builder setMaxStoredEvents(int max) {
    maxStoredEvents = max;
    return this;
  }

  /// Set whether auto environment attributes are enabled
  Builder setAutoEnvAttributesEnabled(bool enabled) {
    autoEnvAttributesEnabled = enabled;
    return this;
  }

  // Local Storage Configuration Methods

  /// Set whether local storage/caching is enabled
  Builder setLocalStorageEnabled(bool enabled) {
    localStorageEnabled = enabled;
    return this;
  }

  /// Set cache TTL for configuration data in seconds
  Builder setConfigCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Config cache TTL cannot be negative');
    }
    configCacheTtlSeconds = seconds;
    return this;
  }

  /// Set cache TTL for event data in seconds
  Builder setEventCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Event cache TTL cannot be negative');
    }
    eventCacheTtlSeconds = seconds;
    return this;
  }

  /// Set cache TTL for summary data in seconds
  Builder setSummaryCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Summary cache TTL cannot be negative');
    }
    summaryCacheTtlSeconds = seconds;
    return this;
  }

  /// Set maximum cache size in MB
  Builder setMaxCacheSizeMb(int sizeMb) {
    if (sizeMb <= 0) {
      throw ArgumentError('Max cache size must be greater than 0');
    }
    maxCacheSizeMb = sizeMb;
    return this;
  }

  /// Set whether to persist cache across app restarts
  Builder setPersistCacheAcrossRestarts(bool persist) {
    persistCacheAcrossRestarts = persist;
    return this;
  }

  /// Set whether to use stale cache while revalidating
  Builder setUseStaleWhileRevalidate(bool useStale) {
    useStaleWhileRevalidate = useStale;
    return this;
  }

  /// Build method creates immutable CFConfig
  CFConfig build() {
    return CFConfig._(
      clientKey: clientKey,
      eventsQueueSize: eventsQueueSize,
      eventsFlushTimeSeconds: eventsFlushTimeSeconds,
      eventsFlushIntervalMs: eventsFlushIntervalMs,
      maxRetryAttempts: maxRetryAttempts,
      retryInitialDelayMs: retryInitialDelayMs,
      retryMaxDelayMs: retryMaxDelayMs,
      retryBackoffMultiplier: retryBackoffMultiplier,
      summariesQueueSize: summariesQueueSize,
      summariesFlushTimeSeconds: summariesFlushTimeSeconds,
      summariesFlushIntervalMs: summariesFlushIntervalMs,
      sdkSettingsCheckIntervalMs: sdkSettingsCheckIntervalMs,
      networkConnectionTimeoutMs: networkConnectionTimeoutMs,
      networkReadTimeoutMs: networkReadTimeoutMs,
      loggingEnabled: loggingEnabled,
      debugLoggingEnabled: debugLoggingEnabled,
      logLevel: logLevel,
      offlineMode: offlineMode,
      disableBackgroundPolling: disableBackgroundPolling,
      backgroundPollingIntervalMs: backgroundPollingIntervalMs,
      useReducedPollingWhenBatteryLow: useReducedPollingWhenBatteryLow,
      reducedPollingIntervalMs: reducedPollingIntervalMs,
      maxStoredEvents: maxStoredEvents,
      autoEnvAttributesEnabled: autoEnvAttributesEnabled,
      localStorageEnabled: localStorageEnabled,
      configCacheTtlSeconds: configCacheTtlSeconds,
      eventCacheTtlSeconds: eventCacheTtlSeconds,
      summaryCacheTtlSeconds: summaryCacheTtlSeconds,
      maxCacheSizeMb: maxCacheSizeMb,
      persistCacheAcrossRestarts: persistCacheAcrossRestarts,
      useStaleWhileRevalidate: useStaleWhileRevalidate,
    );
  }
}

/// Mutable configuration wrapper for runtime updates
class MutableCFConfig {
  CFConfig _config;
  final List<Function(CFConfig)> _listeners = [];

  MutableCFConfig(this._config);

  /// Get current immutable config
  CFConfig get config => _config;

  /// Add a listener for config changes
  void addListener(Function(CFConfig) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function(CFConfig) listener) {
    _listeners.remove(listener);
  }

  /// Update configuration and notify listeners
  void _updateConfig(CFConfig newConfig) {
    _config = newConfig;
    for (final listener in _listeners) {
      try {
        listener(newConfig);
      } catch (e) {
        // Log error but continue notifying other listeners
        print('Error notifying config listener: $e');
      }
    }
  }

  /// Update SDK settings check interval
  void updateSdkSettingsCheckInterval(int intervalMs) {
    _updateConfig(_config.copyWith(sdkSettingsCheckIntervalMs: intervalMs));
  }

  /// Update events flush interval
  void updateEventsFlushInterval(int intervalMs) {
    _updateConfig(_config.copyWith(eventsFlushIntervalMs: intervalMs));
  }

  /// Update summaries flush interval
  void updateSummariesFlushInterval(int intervalMs) {
    _updateConfig(_config.copyWith(summariesFlushIntervalMs: intervalMs));
  }

  /// Update network connection timeout
  void updateNetworkConnectionTimeout(int timeoutMs) {
    _updateConfig(_config.copyWith(networkConnectionTimeoutMs: timeoutMs));
  }

  /// Update network read timeout
  void updateNetworkReadTimeout(int timeoutMs) {
    _updateConfig(_config.copyWith(networkReadTimeoutMs: timeoutMs));
  }

  /// Set debug logging enabled
  void setDebugLoggingEnabled(bool enabled) {
    _updateConfig(_config.copyWith(debugLoggingEnabled: enabled));
  }

  /// Set logging enabled
  void setLoggingEnabled(bool enabled) {
    _updateConfig(_config.copyWith(loggingEnabled: enabled));
  }

  /// Set offline mode
  void setOfflineMode(bool offline) {
    _updateConfig(_config.copyWith(offlineMode: offline));
  }

  /// Update local storage settings
  void updateLocalStorageEnabled(bool enabled) {
    _updateConfig(_config.copyWith(localStorageEnabled: enabled));
  }

  /// Update config cache TTL
  void updateConfigCacheTtl(int seconds) {
    _updateConfig(_config.copyWith(configCacheTtlSeconds: seconds));
  }
}
