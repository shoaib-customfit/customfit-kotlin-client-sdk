package customfit.ai.kotlinclient.logging

import customfit.ai.kotlinclient.constants.CFConstants
import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.LoggerContext
import ch.qos.logback.classic.encoder.PatternLayoutEncoder
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.ConsoleAppender
import ch.qos.logback.core.FileAppender
import org.slf4j.LoggerFactory
import java.io.File
import java.nio.charset.StandardCharsets

/**
 * Enhanced logging configuration with advanced features.
 * This class provides methods to configure logging programmatically.
 */
object LoggingConfig {
    private val LOGGER_NAME = CFConstants.General.LOGGER_NAME
    private const val DEFAULT_LOG_PATTERN = "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
    private const val DEFAULT_LOG_RETENTION_DAYS = 7
    private const val DEFAULT_MAX_LOG_FILE_SIZE = 10 * 1024 * 1024 // 10MB
    
    // Current log file being used
    private var currentLogFile: File? = null

    /**
     * Configures logging with default parameters
     */
    fun configureLogging(enabled: Boolean = true, logLevel: String = CFConstants.Logging.DEFAULT_LOG_LEVEL) {
        if (!enabled) {
            setLogLevel(CFConstants.Logging.LEVEL_OFF)
            return
        }
        
        setLogLevel(logLevel)
    }
    
    /**
     * Sets the log level for the CustomFitSDK logger
     */
    fun setLogLevel(levelString: String) {
        try {
            val level = when (levelString.uppercase()) {
                CFConstants.Logging.LEVEL_ERROR -> Level.ERROR
                CFConstants.Logging.LEVEL_WARN -> Level.WARN
                CFConstants.Logging.LEVEL_INFO -> Level.INFO
                CFConstants.Logging.LEVEL_DEBUG -> Level.DEBUG
                CFConstants.Logging.LEVEL_TRACE -> Level.TRACE
                CFConstants.Logging.LEVEL_OFF -> Level.OFF
                else -> {
                    Timber.w("Invalid log level: $levelString. Using ${CFConstants.Logging.DEFAULT_LOG_LEVEL}.")
                    Level.DEBUG
                }
            }
            
            val loggerContext = LoggerFactory.getILoggerFactory() as LoggerContext
            val logger = loggerContext.getLogger(LOGGER_NAME) as Logger
            logger.level = level
            
            Timber.i("CustomFitSDK log level set to: $levelString")
        } catch (e: Exception) {
            Timber.e(e, "Failed to set log level to $levelString")
        }
    }
    
    /**
     * Enables file logging to the specified directory
     */
    fun enableFileLogging(logDirectory: String) {
        try {
            val logDir = File(logDirectory)
            if (!logDir.exists()) {
                logDir.mkdirs()
            }
            
            // Create a log file with timestamp
            val timestamp = java.time.LocalDateTime.now().toString().replace(":", "-")
            val logFile = File(logDir, "customfit-sdk-$timestamp.log")
            currentLogFile = logFile
            
            val loggerContext = LoggerFactory.getILoggerFactory() as LoggerContext
            val logger = loggerContext.getLogger(LOGGER_NAME) as Logger
            
            // Create and configure the file appender
            val fileAppender = FileAppender<ILoggingEvent>()
            fileAppender.context = loggerContext
            fileAppender.name = "CFFileAppender"
            fileAppender.file = logFile.absolutePath
            
            val encoder = PatternLayoutEncoder()
            encoder.context = loggerContext
            encoder.pattern = DEFAULT_LOG_PATTERN
            encoder.charset = StandardCharsets.UTF_8
            encoder.start()
            
            fileAppender.encoder = encoder
            fileAppender.start()
            
            // Add the appender to the logger
            logger.addAppender(fileAppender)
            
            Timber.i("File logging enabled at: ${logFile.absolutePath}")
            
            // Clean up old log files
            cleanupOldLogFiles(logDir)
        } catch (e: Exception) {
            Timber.e(e, "Failed to enable file logging")
        }
    }
    
    /**
     * Cleans up old log files based on retention policy
     */
    private fun cleanupOldLogFiles(logDir: File, retentionDays: Int = DEFAULT_LOG_RETENTION_DAYS) {
        try {
            val cutoffTime = System.currentTimeMillis() - (retentionDays * 24 * 60 * 60 * 1000L)
            
            logDir.listFiles { file ->
                file.name.startsWith("customfit-sdk-") && file.name.endsWith(".log")
            }?.forEach { file ->
                if (file.lastModified() < cutoffTime) {
                    if (file.delete()) {
                        Timber.d("Deleted old log file: ${file.name}")
                    }
                }
            }
        } catch (e: Exception) {
            Timber.w(e, "Error cleaning up old log files")
        }
    }
    
    /**
     * Configures a console appender with proper formatting
     */
    fun configureConsoleLogging(enabled: Boolean = true) {
        try {
            val loggerContext = LoggerFactory.getILoggerFactory() as LoggerContext
            val logger = loggerContext.getLogger(LOGGER_NAME) as Logger
            
            // Remove existing console appenders
            val existingAppenders = logger.iteratorForAppenders().asSequence().toList()
            existingAppenders.forEach { appender ->
                if (appender is ConsoleAppender<*>) {
                    logger.detachAppender(appender)
                }
            }
            
            if (!enabled) {
                return
            }
            
            // Create and configure the console appender
            val consoleAppender = ConsoleAppender<ILoggingEvent>()
            consoleAppender.context = loggerContext
            consoleAppender.name = "CFConsoleAppender"
            
            val encoder = PatternLayoutEncoder()
            encoder.context = loggerContext
            encoder.pattern = DEFAULT_LOG_PATTERN
            encoder.charset = StandardCharsets.UTF_8
            encoder.start()
            
            consoleAppender.encoder = encoder
            consoleAppender.start()
            
            // Add the appender to the logger
            logger.addAppender(consoleAppender)
            
            Timber.i("Console logging configured")
        } catch (e: Exception) {
            Timber.e(e, "Failed to configure console logging")
        }
    }
    
    /**
     * Returns the path to the current log file
     */
    fun getCurrentLogFilePath(): String? = currentLogFile?.absolutePath
} 