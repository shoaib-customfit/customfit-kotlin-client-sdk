/// Constants used throughout the SDK.
class CFConstants {
  // Private constructor to prevent instantiation
  CFConstants._();

  /// General SDK constants
  static const general = _GeneralConstants();

  /// API constants
  static const api = _APIConstants();

  /// HTTP constants
  static const http = _HttpConstants();

  /// Storage constants
  static const storage = _StorageConstants();

  /// Event-related constants
  static const eventDefaults = _EventConstants();

  /// Summary-related constants
  static const summaryDefaults = _SummaryConstants();

  /// Retry-related constants
  static const retryConfig = _RetryConstants();

  /// Background polling-related constants
  static const backgroundPolling = _BackgroundPollingConstants();

  /// Network-related constants
  static const network = _NetworkConstants();

  /// Logging-related constants
  static const logging = _LoggingConstants();
}

/// General SDK constants
class _GeneralConstants {
  const _GeneralConstants();

  /// SDK version
  final String sdkVersion = '0.1.0';

  /// SDK name
  final String sdkName = 'flutter-client-sdk';

  /// Default user ID (anonymous)
  final String defaultUserId = 'anonymous';
}

/// API constants
class _APIConstants {
  const _APIConstants();

  /// Base API URL
  final String baseApiUrl = 'https://api.customfit.ai';

  /// User configs path
  final String userConfigsPath = '/v1/users/configs';

  /// Events path
  final String eventsPath = '/v1/cfe';

  /// Summaries path
  final String summariesPath = '/v1/summaries';

  /// SDK settings base URL
  final String sdkSettingsBaseUrl = 'https://sdk.customfit.ai';

  /// SDK settings path pattern
  final String sdkSettingsPathPattern = '/%s/cf-sdk-settings.json';
}

/// HTTP constants
class _HttpConstants {
  const _HttpConstants();

  /// Content-Type header name
  final String headerContentType = 'Content-Type';

  /// Content-Type value for JSON
  final String contentTypeJson = 'application/json';

  /// If-Modified-Since header name
  final String headerIfModifiedSince = 'If-Modified-Since';

  /// ETag header name
  final String headerEtag = 'ETag';

  /// Last-Modified header name
  final String headerLastModified = 'Last-Modified';
}

/// Storage constants
class _StorageConstants {
  const _StorageConstants();

  /// User preferences key
  final String userPreferencesKey = 'cf_user';

  /// Events database name
  final String eventsDatabaseName = 'cf_events.db';

  /// Config cache name
  final String configCacheName = 'cf_config.json';

  /// Session ID key
  final String sessionIdKey = 'cf_session_id';

  /// Install time key
  final String installTimeKey = 'cf_app_install_time';
}

/// Event-related constants
class _EventConstants {
  const _EventConstants();

  /// Default queue size for events
  final int QUEUE_SIZE = 100;

  /// Default flush time in seconds for events
  final int FLUSH_TIME_SECONDS = 60;

  /// Default flush interval in milliseconds for events
  final int FLUSH_INTERVAL_MS = 1000;

  /// Maximum number of events to store offline
  final int MAX_STORED_EVENTS = 100;
}

/// Summary-related constants
class _SummaryConstants {
  const _SummaryConstants();

  /// Default queue size for summaries
  final int QUEUE_SIZE = 100;

  /// Default flush time in seconds for summaries
  final int FLUSH_TIME_SECONDS = 60;

  /// Default flush interval in milliseconds for summaries
  final int FLUSH_INTERVAL_MS = 60000;
}

/// Retry-related constants
class _RetryConstants {
  const _RetryConstants();

  /// Default maximum number of retry attempts
  final int MAX_RETRY_ATTEMPTS = 3;

  /// Default initial delay in milliseconds before the first retry
  final int INITIAL_DELAY_MS = 1000;

  /// Default maximum delay in milliseconds between retries
  final int MAX_DELAY_MS = 30000;

  /// Default backoff multiplier for exponential backoff
  final double BACKOFF_MULTIPLIER = 2.0;

  /// Circuit breaker failure threshold
  final int CIRCUIT_BREAKER_FAILURE_THRESHOLD = 3;

  /// Circuit breaker reset timeout in milliseconds
  final int CIRCUIT_BREAKER_RESET_TIMEOUT_MS = 30000;
}

/// Background polling-related constants
class _BackgroundPollingConstants {
  const _BackgroundPollingConstants();

  /// Default SDK settings check interval in milliseconds
  final int SDK_SETTINGS_CHECK_INTERVAL_MS = 300000; // 5 minutes

  /// Default background polling interval in milliseconds
  final int BACKGROUND_POLLING_INTERVAL_MS = 3600000; // 1 hour

  /// Default reduced polling interval in milliseconds
  final int REDUCED_POLLING_INTERVAL_MS = 7200000; // 2 hours
}

/// Network-related constants
class _NetworkConstants {
  const _NetworkConstants();

  /// Default connection timeout in milliseconds
  final int CONNECTION_TIMEOUT_MS = 10000;

  /// Default read timeout in milliseconds
  final int READ_TIMEOUT_MS = 10000;

  /// SDK settings request timeout in milliseconds
  final int SDK_SETTINGS_TIMEOUT_MS = 5000;

  /// SDK settings check timeout in milliseconds
  final int SDK_SETTINGS_CHECK_TIMEOUT_MS = 10000;
}

/// Logging-related constants
class _LoggingConstants {
  const _LoggingConstants();

  /// Log level: ERROR
  final String LEVEL_ERROR = 'ERROR';

  /// Log level: WARN
  final String LEVEL_WARN = 'WARN';

  /// Log level: INFO
  final String LEVEL_INFO = 'INFO';

  /// Log level: DEBUG
  final String LEVEL_DEBUG = 'DEBUG';

  /// Log level: TRACE
  final String LEVEL_TRACE = 'TRACE';

  /// Log level: OFF - disables logging
  final String LEVEL_OFF = 'OFF';

  /// Default log level
  final String DEFAULT_LOG_LEVEL = 'DEBUG';
}
