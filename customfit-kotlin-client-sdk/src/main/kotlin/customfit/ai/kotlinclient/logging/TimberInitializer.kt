package customfit.ai.kotlinclient.logging

import customfit.ai.kotlinclient.constants.CFConstants
import org.slf4j.LoggerFactory
import java.text.SimpleDateFormat
import java.util.Date

/**
 * A Timber-like logging interface that uses SLF4J underneath.
 * This allows us to maintain the Timber-style API while using standard logging.
 */
object Timber {
    private val logger = LoggerFactory.getLogger(CFConstants.General.LOGGER_NAME)
    private val timestamp = { SimpleDateFormat("HH:mm:ss.SSS").format(Date()) }
    private const val LOG_PREFIX = "Customfit.ai-SDK [Kotlin]"
    
    // Add direct console output for important logs
    private fun directConsoleOutput(message: String) {
        if (message.contains("API POLL")) {
            println("[${timestamp()}] 📡 $LOG_PREFIX: $message")
        } else if (message.contains("SUMMARY")) {
            println("[${timestamp()}] 📊 $LOG_PREFIX: $message")
        } else if (message.contains("CONFIG VALUE") || message.contains("CONFIG UPDATE")) {
            println("[${timestamp()}] 🔧 $LOG_PREFIX: $message")
        } else if (message.contains("TRACK") || message.contains("🔔")) {
            println("[${timestamp()}] 🔔 $LOG_PREFIX: $message")
        } else {
            println("[${timestamp()}] $LOG_PREFIX: $message")
        }
    }
    
    /**
     * Log a debug message
     */
    fun d(message: String) {
        if (logger.isDebugEnabled) {
            logger.debug(message)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log a debug message with exception
     */
    fun d(throwable: Throwable, message: String) {
        if (logger.isDebugEnabled) {
            logger.debug(message, throwable)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log an info message
     */
    fun i(message: String) {
        if (logger.isInfoEnabled) {
            logger.info(message)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log an info message with exception
     */
    fun i(throwable: Throwable, message: String) {
        if (logger.isInfoEnabled) {
            logger.info(message, throwable)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log a warning message
     */
    fun w(message: String) {
        if (logger.isWarnEnabled) {
            logger.warn(message)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log a warning message with a lambda
     */
    fun warn(messageProducer: () -> Any?) {
        if (logger.isWarnEnabled) {
            val message = messageProducer().toString()
            logger.warn(message)
            directConsoleOutput(message)
        }
    }
    
    /**
     * Log a warning message with exception
     */
    fun w(throwable: Throwable, message: String) {
        if (logger.isWarnEnabled) {
            logger.warn(message, throwable)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log an error message
     */
    fun e(message: String) {
        if (logger.isErrorEnabled) {
            logger.error(message)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log an error message with exception
     */
    fun e(throwable: Throwable, message: String) {
        if (logger.isErrorEnabled) {
            logger.error(message, throwable)
        }
        directConsoleOutput(message)
    }
    
    /**
     * Log an error message with a lambda
     */
    fun e(throwable: Throwable, messageProducer: () -> Any?) {
        if (logger.isErrorEnabled) {
            val message = messageProducer().toString()
            logger.error(message, throwable)
            directConsoleOutput(message)
        }
    }
} 