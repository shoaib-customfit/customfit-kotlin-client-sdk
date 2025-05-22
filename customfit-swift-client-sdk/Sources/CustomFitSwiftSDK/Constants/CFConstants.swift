import Foundation

/// Constants used throughout the SDK
public struct CFConstants {
    /// General constants
    public struct General {
        /// SDK name
        public static let SDK_NAME = "CustomFitSwiftSDK"
        
        /// Default SDK version
        public static let DEFAULT_SDK_VERSION = "1.0.0"
        
        /// Logger name
        public static let LOGGER_NAME = "CustomFitSDK"
    }
    
    /// API URL constants
    public struct Api {
        /// Base URL for the CustomFit API
        public static let BASE_API_URL = "https://api.customfit.ai/v1"
        
        /// Base URL for SDK settings
        public static let SDK_SETTINGS_BASE_URL = "https://sdk.customfit.ai"
        
        /// Path for user configurations
        public static let USER_CONFIGS_PATH = "/users/configs"
        
        /// Path pattern for SDK settings JSON file
        public static let SDK_SETTINGS_PATH_PATTERN = "/%s/cf-sdk-settings.json"
        
        /// Path for event data
        public static let EVENTS_PATH = "/v1/cfe"
        
        /// Path for summary data
        public static let SUMMARIES_PATH = "/v1/summary"
        
        /// Path for config polling
        public static let CONFIG_POLL_PATH = "/v1/config"
    }
    
    /// Default configuration values for events
    public struct EventDefaults {
        /// Default queue size for events
        public static let QUEUE_SIZE = 100
        
        /// Default flush time in seconds
        public static let FLUSH_TIME_SECONDS = 60
        
        /// Default flush interval in milliseconds
        public static let FLUSH_INTERVAL_MS: Int64 = 1000
        
        /// Maximum events to store when offline
        public static let MAX_STORED_EVENTS = 100
    }
    
    /// Default configuration values for summaries
    public struct SummaryDefaults {
        /// Default queue size for summaries
        public static let QUEUE_SIZE = 100
        
        /// Default flush time in seconds
        public static let FLUSH_TIME_SECONDS = 60
        
        /// Default flush interval in milliseconds
        public static let FLUSH_INTERVAL_MS: Int64 = 60_000
    }
    
    /// Network-related constants
    public struct Network {
        /// Default connection timeout in milliseconds
        public static let CONNECTION_TIMEOUT_MS = 10_000
        
        /// Default read timeout in milliseconds
        public static let READ_TIMEOUT_MS = 10_000
        
        /// SDK settings request timeout in milliseconds
        public static let SDK_SETTINGS_TIMEOUT_MS: Int64 = 15_000
        
        /// SDK settings check timeout in milliseconds
        public static let SDK_SETTINGS_CHECK_TIMEOUT_MS: Int64 = 20_000
    }
    
    /// Retry configuration constants
    public struct RetryConfig {
        /// Default maximum retry attempts
        public static let MAX_RETRY_ATTEMPTS = 3
        
        /// Default initial delay in milliseconds
        public static let INITIAL_DELAY_MS: Int64 = 1000
        
        /// Default maximum delay in milliseconds
        public static let MAX_DELAY_MS: Int64 = 30000
        
        /// Default retry backoff multiplier
        public static let BACKOFF_MULTIPLIER = 2.0
        
        /// Circuit breaker failure threshold
        public static let CIRCUIT_BREAKER_FAILURE_THRESHOLD = 3
        
        /// Circuit breaker reset timeout in milliseconds
        public static let CIRCUIT_BREAKER_RESET_TIMEOUT_MS = 30_000
        
        /// Default jitter factor for exponential backoff
        public static let JITTER_FACTOR = 0.5
    }
    
    /// Background polling constants
    public struct BackgroundPolling {
        /// Default SDK settings check interval in milliseconds
        public static let SDK_SETTINGS_CHECK_INTERVAL_MS: Int64 = 300_000 // 5 minutes
        
        /// Default background polling interval in milliseconds
        public static let BACKGROUND_POLLING_INTERVAL_MS: Int64 = 3_600_000 // 1 hour
        
        /// Default reduced polling interval when battery is low (milliseconds)
        public static let REDUCED_POLLING_INTERVAL_MS: Int64 = 7_200_000 // 2 hours
        
        /// Default reduced SDK settings check interval in milliseconds
        public static let REDUCED_SDK_SETTINGS_CHECK_INTERVAL_MS: Int64 = 600_000 // 10 minutes
    }
    
    /// Logging constants
    public struct Logging {
        /// Log level: ERROR
        public static let LEVEL_ERROR = "ERROR"
        
        /// Log level: WARN
        public static let LEVEL_WARN = "WARN"
        
        /// Log level: INFO
        public static let LEVEL_INFO = "INFO"
        
        /// Log level: DEBUG
        public static let LEVEL_DEBUG = "DEBUG"
        
        /// Log level: TRACE
        public static let LEVEL_TRACE = "TRACE"
        
        /// Log level: OFF - disables logging
        public static let LEVEL_OFF = "OFF"
        
        /// Default log level
        public static let DEFAULT_LOG_LEVEL = LEVEL_DEBUG
        
        /// List of valid log levels
        public static let VALID_LOG_LEVELS = [LEVEL_ERROR, LEVEL_WARN, LEVEL_INFO, LEVEL_DEBUG, LEVEL_TRACE]
    }
    
    /// HTTP related constants
    public struct Http {
        /// Content-Type header name
        public static let HEADER_CONTENT_TYPE = "Content-Type"
        
        /// Content-Type value for JSON
        public static let CONTENT_TYPE_JSON = "application/json"
        
        /// Last-Modified header name
        public static let HEADER_LAST_MODIFIED = "Last-Modified"
        
        /// ETag header name
        public static let HEADER_ETAG = "ETag"
        
        /// If-Modified-Since header name
        public static let HEADER_IF_MODIFIED_SINCE = "If-Modified-Since"
        
        /// If-None-Match header name for ETag-based conditional requests
        public static let HEADER_IF_NONE_MATCH = "If-None-Match"
    }
    
    /// User attribute constants
    public struct UserAttributes {
        /// User ID attribute key
        public static let USER_ID = "user_id"
        
        /// Device ID attribute key
        public static let DEVICE_ID = "device_id"
        
        /// Anonymous ID attribute key
        public static let ANONYMOUS_ID = "anonymous_id"
    }
    
    /// Event type constants
    public struct EventTypes {
        /// App start event type
        public static let APP_START = "app_start"
        
        /// App stop event type
        public static let APP_STOP = "app_stop"
        
        /// App foreground event type
        public static let APP_FOREGROUND = "app_foreground"
        
        /// App background event type
        public static let APP_BACKGROUND = "app_background"
        
        /// Screen view event type
        public static let SCREEN_VIEW = "screen_view"
        
        /// Feature usage event type
        public static let FEATURE_USAGE = "feature_usage"
    }
    
    /// API endpoint constants
    public struct Endpoints {
        /// Base API URL
        public static let BASE_URL = "https://api.customfit.ai/v1"
        
        /// Config endpoint
        public static let CONFIG = "/config"
        
        /// Events endpoint
        public static let EVENTS = "/events"
        
        /// Summary endpoint
        public static let SUMMARY = "/summary"
    }
} 