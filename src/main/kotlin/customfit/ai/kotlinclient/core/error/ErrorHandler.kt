package customfit.ai.kotlinclient.core.error

import customfit.ai.kotlinclient.logging.Timber
import kotlinx.serialization.SerializationException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Centralized error handling utility providing standardized error handling,
 * categorization, and reporting capabilities.
 */
object ErrorHandler {
    // Error categories for classification
    enum class ErrorCategory {
        NETWORK,
        SERIALIZATION,
        VALIDATION,
        PERMISSION,
        TIMEOUT,
        INTERNAL,
        UNKNOWN
    }

    // Error severity levels
    enum class ErrorSeverity {
        LOW,      // Minor issues that don't impact functionality
        MEDIUM,   // Important issues that may impact some functionality
        HIGH,     // Critical issues that significantly impact functionality
        CRITICAL  // Fatal issues that completely break functionality
    }

    // Track error occurrences for rate limiting and pattern detection
    private val errorCounts = ConcurrentHashMap<String, AtomicInteger>()
    private val MAX_LOG_RATE = 10 // Max times to log same error in a session

    /**
     * Handles and logs an exception with standard categorization
     *
     * @param e The exception to handle
     * @param message The error message
     * @param source The component where the error occurred
     * @param severity The error severity
     * @return The appropriate ErrorCategory for the exception
     */
    fun handleException(
        e: Throwable,
        message: String,
        source: String = "unknown",
        severity: ErrorSeverity = ErrorSeverity.MEDIUM
    ): ErrorCategory {
        // Categorize the error
        val category = categorizeException(e)
        
        // Build enhanced error message
        val enhancedMessage = buildErrorMessage(message, source, severity, category)
        
        // Rate-limit repeated errors
        val errorKey = "${e.javaClass.name}:$source:$message"
        val count = errorCounts.computeIfAbsent(errorKey) { AtomicInteger(0) }.incrementAndGet()
        
        if (count <= MAX_LOG_RATE) {
            // Log with appropriate level based on severity
            when (severity) {
                ErrorSeverity.LOW -> Timber.d(e, enhancedMessage)
                ErrorSeverity.MEDIUM -> Timber.w(e, enhancedMessage)
                ErrorSeverity.HIGH, ErrorSeverity.CRITICAL -> Timber.e(e, enhancedMessage)
            }
        } else if (count == MAX_LOG_RATE + 1) {
            // Log that we're rate limiting this error
            Timber.w("Rate limiting similar error: $errorKey. Further occurrences won't be logged.")
        }
        
        return category
    }

    /**
     * Handles an error condition without an exception
     *
     * @param message The error message
     * @param source The component where the error occurred
     * @param category The error category
     * @param severity The error severity
     */
    fun handleError(
        message: String,
        source: String = "unknown",
        category: ErrorCategory = ErrorCategory.UNKNOWN,
        severity: ErrorSeverity = ErrorSeverity.MEDIUM
    ) {
        // Build enhanced error message
        val enhancedMessage = buildErrorMessage(message, source, severity, category)
        
        // Rate-limit repeated errors
        val errorKey = "$source:$message:$category"
        val count = errorCounts.computeIfAbsent(errorKey) { AtomicInteger(0) }.incrementAndGet()
        
        if (count <= MAX_LOG_RATE) {
            // Log with appropriate level based on severity
            when (severity) {
                ErrorSeverity.LOW -> Timber.d(enhancedMessage)
                ErrorSeverity.MEDIUM -> Timber.w(enhancedMessage)
                ErrorSeverity.HIGH, ErrorSeverity.CRITICAL -> Timber.e(enhancedMessage)
            }
        } else if (count == MAX_LOG_RATE + 1) {
            // Log that we're rate limiting this error
            Timber.w("Rate limiting similar error: $errorKey. Further occurrences won't be logged.")
        }
    }

    /**
     * Determines the category of an exception
     */
    private fun categorizeException(e: Throwable): ErrorCategory {
        return when (e) {
            is ConnectException, is UnknownHostException -> ErrorCategory.NETWORK
            is SocketTimeoutException -> ErrorCategory.TIMEOUT
            is SerializationException -> ErrorCategory.SERIALIZATION
            is IllegalArgumentException, is IllegalStateException -> ErrorCategory.VALIDATION
            is SecurityException -> ErrorCategory.PERMISSION
            else -> ErrorCategory.UNKNOWN
        }
    }

    /**
     * Builds a standardized error message
     */
    private fun buildErrorMessage(
        message: String,
        source: String,
        severity: ErrorSeverity,
        category: ErrorCategory
    ): String {
        return "[$source] [$severity] [$category] $message"
    }

    /**
     * Clears the error count tracking
     */
    fun resetErrorCounts() {
        errorCounts.clear()
    }
} 