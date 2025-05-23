package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Timber
import kotlinx.coroutines.*
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeoutException
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext
import java.util.concurrent.ConcurrentHashMap

/**
 * Utility class for structured concurrency patterns and improved error handling
 */
object CoroutineUtils {
    
    /**
     * Default error handler for coroutines
     */
    private val defaultExceptionHandler = CoroutineExceptionHandler { _, exception ->
        if (exception !is CancellationException) {
            Timber.e(exception) { "Unhandled exception in coroutine: ${exception.message}" }
        }
    }
    
    /**
     * Creates a structured scope for launching coroutines with proper error handling
     * 
     * @param context base context to use (defaults to IO dispatcher)
     * @param handleErrors whether to install the default exception handler
     * @return CoroutineScope with proper configuration
     */
    fun createScope(
        context: CoroutineContext = Dispatchers.IO,
        handleErrors: Boolean = true
    ): CoroutineScope {
        val fullContext = if (handleErrors) {
            context + defaultExceptionHandler + SupervisorJob()
        } else {
            context + SupervisorJob()
        }
        return CoroutineScope(fullContext)
    }
    
    /**
     * Executes a suspending block with proper error handling
     * 
     * @param context coroutine context to use
     * @param errorMessage message to log if an error occurs
     * @param block the suspending block to execute
     * @return the result of the block or null if an error occurred
     */
    suspend fun <T> withErrorHandling(
        context: CoroutineContext = Dispatchers.IO,
        errorMessage: String = "Operation failed",
        block: suspend CoroutineScope.() -> T
    ): Result<T> = withContext(context) {
        try {
            Result.success(block())
        } catch (e: CancellationException) {
            throw e // Don't swallow cancellation
        } catch (e: Exception) {
            Timber.e(e) { "$errorMessage: ${e.message}" }
            Result.failure(e)
        }
    }
    
    /**
     * Launches a coroutine with structured concurrency and error tracking
     * 
     * @param context coroutine context to use
     * @param errorMessage message to log if an error occurs 
     * @param block the suspending block to execute
     * @return Job for the launched coroutine
     */
    fun CoroutineScope.launchSafely(
        context: CoroutineContext = EmptyCoroutineContext,
        errorMessage: String = "Operation failed",
        block: suspend CoroutineScope.() -> Unit
    ): Job = this.launch(context + CoroutineExceptionHandler { _, e ->
        if (e !is CancellationException) {
            Timber.e(e) { "$errorMessage: ${e.message}" }
        }
    }) {
        block()
    }
    
    /**
     * Executes multiple coroutines in parallel with proper error handling
     * 
     * @param context coroutine context to use
     * @param operations list of suspending functions to execute in parallel
     * @return list of results (including failures)
     */
    suspend fun <T> runParallel(
        context: CoroutineContext = Dispatchers.IO,
        operations: List<suspend () -> T>
    ): List<Result<T>> = withContext(context) {
        operations.map { operation ->
            async {
                try {
                    Result.success(operation())
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Result.failure(e)
                }
            }
        }.awaitAll()
    }
    
    /**
     * Creates a retry block that will retry a suspending operation with exponential backoff
     * 
     * @param maxAttempts maximum number of retry attempts
     * @param initialDelayMs initial delay in milliseconds
     * @param maxDelayMs maximum delay in milliseconds
     * @param factor multiplicative factor for exponential backoff
     * @param retryOn predicate to determine if an exception should trigger a retry
     * @param block the suspending block to execute with retry
     * @return the result of the operation or throws the last exception if all retries fail
     */
    suspend fun <T> withRetry(
        maxAttempts: Int = 3,
        initialDelayMs: Long = 100,
        maxDelayMs: Long = 5000,
        factor: Double = 2.0,
        retryOn: (Exception) -> Boolean = { true },
        block: suspend () -> T
    ): T {
        var currentDelay = initialDelayMs
        repeat(maxAttempts - 1) { attempt ->
            try {
                return block()
            } catch (e: CancellationException) {
                throw e  // Don't retry cancellations
            } catch (e: Exception) {
                if (!retryOn(e)) throw e
                
                Timber.warn { "Operation failed (attempt ${attempt + 1}/$maxAttempts): ${e.message}. Retrying in $currentDelay ms." }
                delay(currentDelay)
                currentDelay = (currentDelay * factor).toLong().coerceAtMost(maxDelayMs)
            }
        }
        
        // Last attempt
        return block()
    }
    
    /**
     * Executes a suspending block with a timeout, returning a fallback value if the timeout is exceeded
     * 
     * @param timeoutMs timeout in milliseconds
     * @param fallback fallback value to return if timeout is exceeded
     * @param logTimeout whether to log a warning on timeout
     * @param block the suspending block to execute
     * @return result of the block or fallback if timeout exceeded
     */
    suspend fun <T> withTimeoutOrDefault(
        timeoutMs: Long,
        fallback: T,
        logTimeout: Boolean = true,
        block: suspend () -> T
    ): T {
        return try {
            withTimeout(timeoutMs) {
                block()
            }
        } catch (e: TimeoutException) {
            if (logTimeout) {
                Timber.warn { "Operation timed out after $timeoutMs ms. Using fallback value." }
            }
            fallback
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Timber.e(e) { "Operation failed: ${e.message}. Using fallback value." }
            fallback
        }
    }
    
    /**
     * Executes a suspending block with a timeout, returning null if the timeout is exceeded
     * 
     * @param timeoutMs timeout in milliseconds
     * @param logTimeout whether to log a warning on timeout
     * @param block the suspending block to execute
     * @return result of the block or null if timeout exceeded
     */
    suspend fun <T> withTimeoutOrNull(
        timeoutMs: Long,
        logTimeout: Boolean = true,
        block: suspend () -> T
    ): T? {
        return try {
            withTimeout(timeoutMs) {
                block()
            }
        } catch (e: TimeoutException) {
            if (logTimeout) {
                Timber.warn { "Operation timed out after $timeoutMs ms" }
            }
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Timber.e(e) { "Operation failed: ${e.message}" }
            null
        }
    }
    
    /**
     * Executes a suspending block, tracing execution time for performance monitoring
     * 
     * @param operationName name of the operation for logging
     * @param warnThresholdMs threshold in milliseconds above which to log a warning
     * @param block the suspending block to execute
     * @return result of the block
     */
    suspend fun <T> withTiming(
        operationName: String,
        warnThresholdMs: Long = 500,
        block: suspend () -> T
    ): T {
        val startTime = System.currentTimeMillis()
        try {
            return block()
        } finally {
            val duration = System.currentTimeMillis() - startTime
            if (duration > warnThresholdMs) {
                Timber.warn { "SLOW OPERATION: $operationName took $duration ms (threshold: $warnThresholdMs ms)" }
            } else {
                Timber.d("Operation $operationName completed in $duration ms")
            }
        }
    }
    
    /**
     * Executes a suspending operation with circuit breaker pattern to prevent
     * repeated calls to failing systems.
     * 
     * @param operationKey unique key for this operation type (used for tracking failure state)
     * @param failureThreshold number of consecutive failures before opening circuit
     * @param resetTimeoutMs time in milliseconds after which to try again (half-open state)
     * @param fallback fallback value to return when circuit is open
     * @param operation the operation to execute
     * @return result of operation or fallback when circuit is open
     */
    suspend fun <T> withCircuitBreaker(
        operationKey: String,
        failureThreshold: Int = 3,
        resetTimeoutMs: Long = 30_000,
        fallback: T,
        operation: suspend () -> T
    ): T {
        // Get or create circuit state
        val state = circuitBreakerStates.getOrPut(operationKey) { CircuitBreakerState() }
        
        // Check if circuit is open
        if (state.isOpen() && !state.shouldTryAgain()) {
            Timber.d("Circuit $operationKey is OPEN, using fallback")
            return fallback
        }
        
        // Try operation
        return try {
            val result = operation()
            state.recordSuccess()
            result
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            state.recordFailure()
            
            // If we've hit the threshold, open the circuit
            if (state.consecutiveFailures >= failureThreshold) {
                Timber.warn { "Circuit $operationKey OPENED after $failureThreshold consecutive failures" }
                state.openCircuit(resetTimeoutMs)
            }
            
            Timber.e(e) { "Operation $operationKey failed: ${e.message}" }
            fallback
        }
    }
    
    // Circuit breaker state storage - thread-safe
    private val circuitBreakerStates = ConcurrentHashMap<String, CircuitBreakerState>()
    
    // Circuit breaker state class
    private class CircuitBreakerState {
        var consecutiveFailures = 0
        private var openUntil: Long = 0
        
        @Synchronized
        fun recordSuccess() {
            consecutiveFailures = 0
            openUntil = 0
        }
        
        @Synchronized
        fun recordFailure() {
            consecutiveFailures++
        }
        
        @Synchronized
        fun openCircuit(resetTimeoutMs: Long) {
            openUntil = System.currentTimeMillis() + resetTimeoutMs
        }
        
        @Synchronized
        fun isOpen(): Boolean {
            return openUntil > 0
        }
        
        @Synchronized
        fun shouldTryAgain(): Boolean {
            val now = System.currentTimeMillis()
            return now >= openUntil
        }
    }
} 