package customfit.ai.kotlinclient.core.error

import customfit.ai.kotlinclient.logging.Timber

/**
 * A sealed class representing the result of an operation that may succeed or fail.
 * This provides a standardized way to handle operation results throughout the SDK.
 *
 * @param T The type of successful result
 */
sealed class CFResult<out T> {
    /**
     * Represents a successful operation with a result
     *
     * @param data The operation result data
     */
    data class Success<out T>(val data: T) : CFResult<T>()

    /**
     * Represents an error/failure result
     *
     * @param error The error message
     * @param exception The exception that caused the error, if any
     * @param code An optional error code
     * @param category The error category
     */
    data class Error(
        val error: String,
        val exception: Throwable? = null,
        val code: Int = 0,
        val category: ErrorHandler.ErrorCategory = ErrorHandler.ErrorCategory.UNKNOWN
    ) : CFResult<Nothing>()

    companion object {
        /**
         * Creates a Success result with the given data
         */
        fun <T> success(data: T): CFResult<T> = Success(data)

        /**
         * Creates an Error result
         */
        fun error(
            message: String,
            exception: Throwable? = null,
            code: Int = 0,
            category: ErrorHandler.ErrorCategory = ErrorHandler.ErrorCategory.UNKNOWN
        ): CFResult<Nothing> {
            // Log the error if an exception is provided
            exception?.let {
                ErrorHandler.handleException(
                    it,
                    message,
                    "CFResult",
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
            } ?: ErrorHandler.handleError(
                message,
                "CFResult",
                category,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            
            return Error(message, exception, code, category)
        }

        /**
         * Creates a CFResult from a Kotlin Result
         */
        fun <T> fromResult(result: Result<T>, errorMessage: String = "Operation failed"): CFResult<T> {
            return result.fold(
                onSuccess = { Success(it) },
                onFailure = { Error(errorMessage, it) }
            )
        }
    }

    /**
     * Returns the success value or null if this is an error
     */
    fun getOrNull(): T? {
        return when (this) {
            is Success -> data
            is Error -> null
        }
    }

    /**
     * Returns the success value or executes the default function if this is an error
     */
    fun getOrElse(default: Function1<Error, @UnsafeVariance T>): T {
        return when (this) {
            is Success -> data
            is Error -> default(this)
        }
    }

    /**
     * Returns the success value or the default value if this is an error
     */
    fun getOrDefault(defaultValue: @UnsafeVariance T): T {
        return when (this) {
            is Success -> data
            is Error -> defaultValue
        }
    }

    /**
     * Transform a success result using the given transform function
     */
    fun <R> map(transform: (T) -> R): CFResult<R> {
        return when (this) {
            is Success -> Success(transform(data))
            is Error -> this
        }
    }

    /**
     * Process the result with respective handlers for success and error
     */
    fun <R> fold(
        onSuccess: Function1<T, R>,
        onError: Function1<Error, R>
    ): R {
        return when (this) {
            is Success -> onSuccess(data)
            is Error -> onError(this)
        }
    }

    /**
     * Executes the given action if this is a success
     */
    inline fun onSuccess(action: (T) -> Unit): CFResult<T> {
        if (this is Success) {
            action(data)
        }
        return this
    }

    /**
     * Executes the given action if this is an error
     */
    inline fun onError(action: (Error) -> Unit): CFResult<T> {
        if (this is Error) {
            action(this)
        }
        return this
    }
} 