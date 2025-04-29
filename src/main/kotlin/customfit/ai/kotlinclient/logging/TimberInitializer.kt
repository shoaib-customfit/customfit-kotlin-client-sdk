package customfit.ai.kotlinclient.logging

import customfit.ai.kotlinclient.constants.CFConstants
import org.slf4j.LoggerFactory

/**
 * A Timber-like logging interface that uses SLF4J underneath.
 * This allows us to maintain the Timber-style API while using standard logging.
 */
object Timber {
    private val logger = LoggerFactory.getLogger(CFConstants.General.LOGGER_NAME)
    
    /**
     * Log a debug message
     */
    fun d(message: String) {
        if (logger.isDebugEnabled) {
            logger.debug(message)
        }
    }
    
    /**
     * Log a debug message with exception
     */
    fun d(throwable: Throwable, message: String) {
        if (logger.isDebugEnabled) {
            logger.debug(message, throwable)
        }
    }
    
    /**
     * Log an info message
     */
    fun i(message: String) {
        if (logger.isInfoEnabled) {
            logger.info(message)
        }
    }
    
    /**
     * Log an info message with exception
     */
    fun i(throwable: Throwable, message: String) {
        if (logger.isInfoEnabled) {
            logger.info(message, throwable)
        }
    }
    
    /**
     * Log a warning message
     */
    fun w(message: String) {
        if (logger.isWarnEnabled) {
            logger.warn(message)
        }
    }
    
    /**
     * Log a warning message with a lambda
     */
    fun warn(messageProducer: () -> Any?) {
        if (logger.isWarnEnabled) {
            logger.warn(messageProducer().toString())
        }
    }
    
    /**
     * Log a warning message with exception
     */
    fun w(throwable: Throwable, message: String) {
        if (logger.isWarnEnabled) {
            logger.warn(message, throwable)
        }
    }
    
    /**
     * Log an error message
     */
    fun e(message: String) {
        if (logger.isErrorEnabled) {
            logger.error(message)
        }
    }
    
    /**
     * Log an error message with exception
     */
    fun e(throwable: Throwable, message: String) {
        if (logger.isErrorEnabled) {
            logger.error(message, throwable)
        }
    }
    
    /**
     * Log an error message with a lambda
     */
    fun e(throwable: Throwable, messageProducer: () -> Any?) {
        if (logger.isErrorEnabled) {
            logger.error(messageProducer().toString(), throwable)
        }
    }
} 