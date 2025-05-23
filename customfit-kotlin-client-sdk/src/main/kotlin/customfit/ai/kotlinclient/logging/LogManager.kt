package customfit.ai.kotlinclient.logging

import customfit.ai.kotlinclient.constants.CFConstants

/**
 * Log level enum for controlling log verbosity
 */
enum class LogLevel(val value: Int) {
    ERROR(1),
    WARN(2),
    INFO(3),
    DEBUG(4),
    TRACE(5);
    
    companion object {
        fun fromString(levelStr: String): LogLevel {
            return when (levelStr.uppercase()) {
                "ERROR" -> ERROR
                "WARN" -> WARN
                "INFO" -> INFO
                "DEBUG" -> DEBUG
                "TRACE" -> TRACE
                else -> DEBUG // Default to DEBUG if unknown
            }
        }
    }
    
    fun shouldLog(level: LogLevel): Boolean {
        return this.value >= level.value
    }
}

/**
 * Log manager that controls logging behavior based on configuration settings
 * This wraps Timber to respect config settings for logging
 */
class LogManager {
    companion object {
        @Volatile
        private var instance: LogManager? = null
        
        fun getInstance(): LogManager {
            return instance ?: synchronized(this) {
                instance ?: LogManager().also { instance = it }
            }
        }
    }
    
    @Volatile
    private var currentLogLevel: LogLevel = LogLevel.DEBUG
    
    @Volatile
    private var loggingEnabled: Boolean = true
    
    @Volatile
    private var debugLoggingEnabled: Boolean = false
    
    /**
     * Configure logging based on config settings
     */
    fun configure(
        loggingEnabled: Boolean,
        debugLoggingEnabled: Boolean,
        logLevelStr: String
    ) {
        synchronized(this) {
            this.loggingEnabled = loggingEnabled
            this.debugLoggingEnabled = debugLoggingEnabled
            
            // Parse log level from string
            val levelFromString = try {
                LogLevel.fromString(logLevelStr)
            } catch (e: Exception) {
                LogLevel.DEBUG // Default to DEBUG if parsing fails
            }
            
            // If debug logging is disabled, cap the maximum log level at INFO
            this.currentLogLevel = if (!debugLoggingEnabled && levelFromString.value > LogLevel.INFO.value) {
                LogLevel.INFO
            } else {
                levelFromString
            }
            
            // In a real implementation, we would configure Timber here
            // For now, just log the configuration
            if (loggingEnabled) {
                println("LogManager configured: logLevel=${currentLogLevel.name}, debugEnabled=$debugLoggingEnabled")
            } else {
                println("LogManager: logging disabled")
            }
        }
    }
    
    /**
     * Check if a specific log level should be logged
     */
    fun isLoggable(level: LogLevel): Boolean {
        return loggingEnabled && level.value <= currentLogLevel.value
    }
    
    /**
     * Get the current log level
     */
    fun getCurrentLogLevel(): LogLevel {
        return currentLogLevel
    }
    
    /**
     * Check if logging is enabled
     */
    fun isLoggingEnabled(): Boolean {
        return loggingEnabled
    }
    
    /**
     * Check if debug logging is enabled
     */
    fun isDebugLoggingEnabled(): Boolean {
        return debugLoggingEnabled
    }
    
    /**
     * Update logging enabled state at runtime
     */
    fun setLoggingEnabled(enabled: Boolean) {
        synchronized(this) {
            if (this.loggingEnabled != enabled) {
                this.loggingEnabled = enabled
                if (enabled) {
                    println("LogManager: logging enabled")
                } else {
                    println("LogManager: logging disabled")
                }
            }
        }
    }
    
    /**
     * Set debug logging enabled state at runtime
     */
    fun setDebugLoggingEnabled(enabled: Boolean) {
        synchronized(this) {
            if (this.debugLoggingEnabled != enabled) {
                this.debugLoggingEnabled = enabled
                
                // If debug logging is being disabled, cap the log level at INFO
                if (!enabled && currentLogLevel.value > LogLevel.INFO.value) {
                    currentLogLevel = LogLevel.INFO
                }
                
                println("LogManager: debug logging ${if (enabled) "enabled" else "disabled"}")
            }
        }
    }
    
    /**
     * Set log level at runtime
     */
    fun setLogLevel(level: LogLevel) {
        synchronized(this) {
            // If debug logging is disabled, cap the level at INFO
            val newLevel = if (!debugLoggingEnabled && level.value > LogLevel.INFO.value) {
                LogLevel.INFO
            } else {
                level
            }
            
            if (currentLogLevel != newLevel) {
                currentLogLevel = newLevel
                println("LogManager: log level set to ${newLevel.name}")
            }
        }
    }
} 