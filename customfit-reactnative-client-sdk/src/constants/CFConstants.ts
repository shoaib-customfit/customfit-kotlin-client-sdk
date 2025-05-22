/**
 * Constants used throughout the React Native SDK
 * Matches the functionality of Kotlin and Swift SDKs
 */
export class CFConstants {
  /**
   * General constants
   */
  static readonly General = {
    /** SDK name */
    SDK_NAME: 'CustomFitReactNativeSDK',
    
    /** Default SDK version */
    DEFAULT_SDK_VERSION: '1.0.0',
    
    /** Logger name */
    LOGGER_NAME: 'CustomFitSDK',
  } as const;

  /**
   * API URL constants
   */
  static readonly Api = {
    /** Base URL for the CustomFit API */
    BASE_API_URL: 'https://api.customfit.ai/v1',
    
    /** Base URL for SDK settings */
    SDK_SETTINGS_BASE_URL: 'https://sdk.customfit.ai',
    
    /** Path for user configurations */
    USER_CONFIGS_PATH: '/users/configs',
    
    /** Path pattern for SDK settings JSON file */
    SDK_SETTINGS_PATH_PATTERN: '/%s/cf-sdk-settings.json',
    
    /** Path for event data */
    EVENTS_PATH: '/v1/cfe',
    
    /** Path for summary data */
    SUMMARIES_PATH: '/v1/summary',
    
    /** Path for config polling */
    CONFIG_POLL_PATH: '/v1/config',
  } as const;

  /**
   * Default configuration values for events
   */
  static readonly EventDefaults = {
    /** Default queue size for events */
    QUEUE_SIZE: 100,
    
    /** Default flush time in seconds */
    FLUSH_TIME_SECONDS: 60,
    
    /** Default flush interval in milliseconds */
    FLUSH_INTERVAL_MS: 1000,
    
    /** Maximum events to store when offline */
    MAX_STORED_EVENTS: 100,
  } as const;

  /**
   * Default configuration values for summaries
   */
  static readonly SummaryDefaults = {
    /** Default queue size for summaries */
    QUEUE_SIZE: 100,
    
    /** Default flush time in seconds */
    FLUSH_TIME_SECONDS: 60,
    
    /** Default flush interval in milliseconds */
    FLUSH_INTERVAL_MS: 60000,
  } as const;

  /**
   * HTTP constants
   */
  static readonly Http = {
    /** Content-Type header */
    HEADER_CONTENT_TYPE: 'Content-Type',
    
    /** JSON content type */
    CONTENT_TYPE_JSON: 'application/json',
    
    /** Last-Modified header */
    HEADER_LAST_MODIFIED: 'Last-Modified',
    
    /** ETag header */
    HEADER_ETAG: 'ETag',
    
    /** If-Modified-Since header */
    HEADER_IF_MODIFIED_SINCE: 'If-Modified-Since',
    
    /** If-None-Match header */
    HEADER_IF_NONE_MATCH: 'If-None-Match',
  } as const;

  /**
   * Network-related constants
   */
  static readonly Network = {
    /** Default connection timeout in milliseconds */
    CONNECTION_TIMEOUT_MS: 10000,
    
    /** Default read timeout in milliseconds */
    READ_TIMEOUT_MS: 10000,
    
    /** SDK settings request timeout in milliseconds */
    SDK_SETTINGS_TIMEOUT_MS: 15000,
    
    /** SDK settings check timeout in milliseconds */
    SDK_SETTINGS_CHECK_TIMEOUT_MS: 20000,
  } as const;

  /**
   * Retry configuration constants
   */
  static readonly RetryConfig = {
    /** Default maximum retry attempts */
    MAX_RETRY_ATTEMPTS: 3,
    
    /** Default initial delay in milliseconds */
    INITIAL_DELAY_MS: 1000,
    
    /** Default maximum delay in milliseconds */
    MAX_DELAY_MS: 30000,
    
    /** Default retry backoff multiplier */
    BACKOFF_MULTIPLIER: 2.0,
    
    /** Circuit breaker failure threshold */
    CIRCUIT_BREAKER_FAILURE_THRESHOLD: 3,
    
    /** Circuit breaker reset timeout in milliseconds */
    CIRCUIT_BREAKER_RESET_TIMEOUT_MS: 30000,
  } as const;

  /**
   * Background polling constants
   */
  static readonly BackgroundPolling = {
    /** Default SDK settings check interval in milliseconds */
    SDK_SETTINGS_CHECK_INTERVAL_MS: 300000, // 5 minutes
    
    /** Default background polling interval in milliseconds */
    BACKGROUND_POLLING_INTERVAL_MS: 3600000, // 1 hour
    
    /** Default reduced polling interval when battery is low (milliseconds) */
    REDUCED_POLLING_INTERVAL_MS: 7200000, // 2 hours
  } as const;

  /**
   * Logging constants
   */
  static readonly Logging = {
    /** Default log level */
    DEFAULT_LOG_LEVEL: 'DEBUG',
    
    /** Valid log levels */
    VALID_LOG_LEVELS: ['ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE'],
  } as const;

  /**
   * Cache constants
   */
  static readonly Cache = {
    /** Default cache TTL in milliseconds (30 days) */
    DEFAULT_TTL_MS: 30 * 24 * 60 * 60 * 1000,
    
    /** Config cache key */
    CONFIG_CACHE_KEY: 'cf_config_data',
    
    /** Metadata cache key */
    METADATA_CACHE_KEY: 'cf_config_metadata',
  } as const;

  /**
   * Storage keys for AsyncStorage
   */
  static readonly Storage = {
    /** Events storage key */
    EVENTS_KEY: 'customfit_events',
    
    /** Summaries storage key */
    SUMMARIES_KEY: 'customfit_summaries',
    
    /** Config cache key */
    CONFIG_KEY: 'customfit_config',
    
    /** Metadata cache key */
    METADATA_KEY: 'customfit_metadata',
    
    /** User data key */
    USER_KEY: 'customfit_user',
  } as const;
} 