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

  /// Get dimension ID from client key
  String? get dimensionId => _extractDimensionIdFromToken(clientKey);

  /// Private constructor - use builder pattern instead
  CFConfig._({
    required this.clientKey,
    this.eventsQueueSize = 10,
    this.eventsFlushTimeSeconds = 30,
    this.eventsFlushIntervalMs = 30000,
    this.maxRetryAttempts = 3,
    this.retryInitialDelayMs = 1000,
    this.retryMaxDelayMs = 30000,
    this.retryBackoffMultiplier = 1.5,
    this.summariesQueueSize = 10,
    this.summariesFlushTimeSeconds = 30,
    this.summariesFlushIntervalMs = 30000,
    this.sdkSettingsCheckIntervalMs = 120000,
    this.networkConnectionTimeoutMs = 10000,
    this.networkReadTimeoutMs = 30000,
    this.loggingEnabled = true,
    this.debugLoggingEnabled = false,
    this.logLevel = 'info',
    this.offlineMode = false,
    this.disableBackgroundPolling = false,
    this.backgroundPollingIntervalMs = 300000,
    this.useReducedPollingWhenBatteryLow = true,
    this.reducedPollingIntervalMs = 900000,
    this.maxStoredEvents = 1000,
    this.autoEnvAttributesEnabled = false,
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

  /// Static factory method from client key only
  static CFConfig fromClientKey(String clientKey) => Builder(clientKey).build();

  /// Builder implementation for fluent API
  static Builder builder(String clientKey) => Builder(clientKey);
}

/// Builder class for CFConfig
class Builder {
  final String clientKey;
  int eventsQueueSize = 10;
  int eventsFlushTimeSeconds = 30;
  int eventsFlushIntervalMs = 30000;
  int maxRetryAttempts = 3;
  int retryInitialDelayMs = 1000;
  int retryMaxDelayMs = 30000;
  double retryBackoffMultiplier = 1.5;
  int summariesQueueSize = 10;
  int summariesFlushTimeSeconds = 30;
  int summariesFlushIntervalMs = 30000;
  int sdkSettingsCheckIntervalMs = 120000;
  int networkConnectionTimeoutMs = 10000;
  int networkReadTimeoutMs = 30000;
  bool loggingEnabled = true;
  bool debugLoggingEnabled = false;
  String logLevel = 'info';
  bool offlineMode = false;
  bool disableBackgroundPolling = false;
  int backgroundPollingIntervalMs = 300000;
  bool useReducedPollingWhenBatteryLow = true;
  int reducedPollingIntervalMs = 900000;
  int maxStoredEvents = 1000;
  bool autoEnvAttributesEnabled = false;

  /// Constructor
  Builder(this.clientKey) {
    if (clientKey.isEmpty) {
      throw ArgumentError("Client key cannot be empty");
    }
  }

  /// Set events queue size
  Builder setEventsQueueSize(int size) {
    eventsQueueSize = size;
    return this;
  }

  /// Set events flush time seconds
  Builder setEventsFlushTimeSeconds(int seconds) {
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
    );
  }
}
