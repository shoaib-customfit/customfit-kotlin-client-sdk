package customfit.ai.kotlinclient.core.util

import customfit.ai.kotlinclient.logging.Timber
import kotlinx.coroutines.delay
import java.util.concurrent.TimeUnit

/**
 * Utility class for handling retry operations with exponential backoff
 */
object RetryUtil {
    /**
     * Executes a suspend function with retry logic
     * 
     * @param maxAttempts Maximum number of retry attempts
     * @param initialDelayMs Initial delay between retries in milliseconds
     * @param maxDelayMs Maximum delay between retries in milliseconds
     * @param backoffMultiplier Multiplier for exponential backoff
     * @param block The suspend function to execute
     * @return Result of the operation
     * @throws Exception if all retry attempts fail
     */
    suspend fun <T> withRetry(
        maxAttempts: Int,
        initialDelayMs: Long,
        maxDelayMs: Long,
        backoffMultiplier: Double,
        block: suspend () -> T
    ): T {
        var currentDelay = initialDelayMs
        var attempt = 0
        var lastException: Exception? = null

        while (attempt < maxAttempts) {
            try {
                return block()
            } catch (e: Exception) {
                lastException = e
                attempt++
                
                if (attempt < maxAttempts) {
                    Timber.w("Attempt $attempt failed, retrying in ${currentDelay}ms: ${e.message}")
                    delay(currentDelay)
                    
                    // Calculate next delay with exponential backoff
                    currentDelay = (currentDelay * backoffMultiplier).toLong()
                        .coerceAtMost(maxDelayMs)
                }
            }
        }

        throw lastException ?: Exception("All retry attempts failed")
    }

    /**
     * Executes a suspend function with retry logic and returns null on failure
     * 
     * @param maxAttempts Maximum number of retry attempts
     * @param initialDelayMs Initial delay between retries in milliseconds
     * @param maxDelayMs Maximum delay between retries in milliseconds
     * @param backoffMultiplier Multiplier for exponential backoff
     * @param block The suspend function to execute
     * @return Result of the operation or null if all attempts fail
     */
    suspend fun <T> withRetryOrNull(
        maxAttempts: Int,
        initialDelayMs: Long,
        maxDelayMs: Long,
        backoffMultiplier: Double,
        block: suspend () -> T
    ): T? {
        return try {
            withRetry(maxAttempts, initialDelayMs, maxDelayMs, backoffMultiplier, block)
        } catch (e: Exception) {
            Timber.e(e, "All retry attempts failed, returning null")
            null
        }
    }
} 