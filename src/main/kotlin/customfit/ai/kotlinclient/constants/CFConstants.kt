package customfit.ai.kotlinclient.constants

/**
 * Constants used throughout the CustomFit Kotlin Client SDK.
 * This class centralizes all hardcoded values to improve maintainability and readability.
 */
object CFConstants {
    /**
     * General SDK constants
     */
    object General {
        /** Default SDK version used in device context */
        const val DEFAULT_SDK_VERSION = "1.0.0"
        
        /** Logger name for the CustomFit SDK */
        const val LOGGER_NAME = "Customfit.ai-SDK [Kotlin]"
    }
    
    /**
     * API URL constants
     */
    object Api {
        /** Base URL for the CustomFit API */
        const val BASE_API_URL = "https://api.customfit.ai"
        
        /** Base URL for SDK settings */
        const val SDK_SETTINGS_BASE_URL = "https://sdk.customfit.ai"
        
        /** Path for user configurations */
        const val USER_CONFIGS_PATH = "/v1/users/configs"
        
        /** Path pattern for SDK settings JSON file */
        const val SDK_SETTINGS_PATH_PATTERN = "/%s/cf-sdk-settings.json"
    }
    
    /**
     * Default configuration values for events
     */
    object EventDefaults {
        /** Default queue size for events */
        const val QUEUE_SIZE = 100
        
        /** Default flush time in seconds */
        const val FLUSH_TIME_SECONDS = 60
        
        /** Default flush interval in milliseconds */
        const val FLUSH_INTERVAL_MS = 1000L
        
        /** Maximum events to store when offline */
        const val MAX_STORED_EVENTS = 100
    }
    
    /**
     * Default configuration values for summaries
     */
    object SummaryDefaults {
        /** Default queue size for summaries */
        const val QUEUE_SIZE = 100
        
        /** Default flush time in seconds */
        const val FLUSH_TIME_SECONDS = 60
        
        /** Default flush interval in milliseconds */
        const val FLUSH_INTERVAL_MS = 60_000L
    }
    
    /**
     * Network-related constants
     */
    object Network {
        /** Default connection timeout in milliseconds */
        const val CONNECTION_TIMEOUT_MS = 10_000
        
        /** Default read timeout in milliseconds */
        const val READ_TIMEOUT_MS = 10_000
        
        /** SDK settings request timeout in milliseconds */
        const val SDK_SETTINGS_TIMEOUT_MS: Long = 15_000L
        
        /** SDK settings check timeout in milliseconds */
        const val SDK_SETTINGS_CHECK_TIMEOUT_MS: Long = 20_000L
    }
    
    /**
     * Retry configuration constants
     */
    object RetryConfig {
        /** Default maximum retry attempts */
        const val MAX_RETRY_ATTEMPTS = 3
        
        /** Default initial delay in milliseconds */
        const val INITIAL_DELAY_MS = 1000L
        
        /** Default maximum delay in milliseconds */
        const val MAX_DELAY_MS = 30000L
        
        /** Default retry backoff multiplier */
        const val BACKOFF_MULTIPLIER = 2.0
        
        /** Circuit breaker failure threshold */
        const val CIRCUIT_BREAKER_FAILURE_THRESHOLD = 3
        
        /** Circuit breaker reset timeout in milliseconds */
        const val CIRCUIT_BREAKER_RESET_TIMEOUT_MS = 30_000
    }
    
    /**
     * Background polling constants
     */
    object BackgroundPolling {
        /** Default SDK settings check interval in milliseconds */
        const val SDK_SETTINGS_CHECK_INTERVAL_MS: Long = 300_000L // 5 minutes
        
        /** Default background polling interval in milliseconds */
        const val BACKGROUND_POLLING_INTERVAL_MS: Long = 3_600_000L // 1 hour
        
        /** Default reduced polling interval when battery is low (milliseconds) */
        const val REDUCED_POLLING_INTERVAL_MS: Long = 7_200_000L // 2 hours
    }
    
    /**
     * Logging constants
     */
    object Logging {
        /** Log level: ERROR */
        const val LEVEL_ERROR = "ERROR"
        
        /** Log level: WARN */
        const val LEVEL_WARN = "WARN"
        
        /** Log level: INFO */
        const val LEVEL_INFO = "INFO"
        
        /** Log level: DEBUG */
        const val LEVEL_DEBUG = "DEBUG"
        
        /** Log level: TRACE */
        const val LEVEL_TRACE = "TRACE"
        
        /** Log level: OFF - disables logging */
        const val LEVEL_OFF = "OFF"
        
        /** Default log level */
        const val DEFAULT_LOG_LEVEL = LEVEL_DEBUG
        
        /** List of valid log levels */
        val VALID_LOG_LEVELS = listOf(LEVEL_ERROR, LEVEL_WARN, LEVEL_INFO, LEVEL_DEBUG, LEVEL_TRACE)
    }
    
    /**
     * HTTP related constants
     */
    object Http {
        /** Content-Type header name */
        const val HEADER_CONTENT_TYPE = "Content-Type"
        
        /** Content-Type value for JSON */
        const val CONTENT_TYPE_JSON = "application/json"
        
        /** Last-Modified header name */
        const val HEADER_LAST_MODIFIED = "Last-Modified"
        
        /** ETag header name */
        const val HEADER_ETAG = "ETag"
        
        /** If-Modified-Since header name */
        const val HEADER_IF_MODIFIED_SINCE = "If-Modified-Since"
        
        /** If-None-Match header name for ETag-based conditional requests */
        const val HEADER_IF_NONE_MATCH = "If-None-Match"
    }
} 