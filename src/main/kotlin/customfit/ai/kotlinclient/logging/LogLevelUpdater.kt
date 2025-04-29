package customfit.ai.kotlinclient.logging

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.config.core.CFConfig
import org.slf4j.LoggerFactory

/**
 * Updates the log level programmatically for the CustomFitSDK logger
 */
object LogLevelUpdater {
    
    /**
     * Update the log level for the CustomFitSDK logger
     * 
     * @param config The CFConfig containing the log level to set
     */
    fun updateLogLevel(config: CFConfig) {
        if (!config.loggingEnabled) {
            setLogLevel(CFConstants.Logging.LEVEL_OFF)
            return
        }
        
        setLogLevel(config.logLevel)
    }
    
    /**
     * Set the log level for the CustomFitSDK logger
     * 
     * @param levelString The log level as a string (ERROR, WARN, INFO, DEBUG, TRACE, OFF)
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
            
            val loggerContext = LoggerFactory.getILoggerFactory()
            val logger = loggerContext.getLogger(CFConstants.General.LOGGER_NAME) as Logger
            logger.level = level
            
            Timber.i("CustomFitSDK log level set to: $levelString")
        } catch (e: Exception) {
            Timber.e(e, "Failed to set log level to $levelString")
        }
    }
} 