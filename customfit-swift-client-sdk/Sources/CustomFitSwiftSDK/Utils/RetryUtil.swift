import Foundation

/// Utility for retrying operations with configurable backoff
public class RetryUtil {
    
    // MARK: - Constants
    
    /// Default number of retry attempts
    public static let DEFAULT_MAX_ATTEMPTS = 3
    
    /// Default initial delay between retries (200ms)
    public static let DEFAULT_INITIAL_DELAY_MS: Int64 = 200
    
    /// Default maximum delay between retries (10s)
    public static let DEFAULT_MAX_DELAY_MS: Int64 = 10000
    
    /// Default backoff multiplier for exponential backoff
    public static let DEFAULT_BACKOFF_MULTIPLIER = 2.0
    
    /// Default jitter factor to add randomness to delays (0-1)
    public static let DEFAULT_JITTER_FACTOR = 0.2
    
    // MARK: - Retry Utilities
    
    /// Execute operation with retry logic (synchronous version)
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - initialDelayMs: Initial delay between retries in milliseconds
    ///   - maxDelayMs: Maximum delay between retries in milliseconds
    ///   - backoffMultiplier: Multiplier for exponential backoff
    ///   - jitterFactor: Random factor to add jitter to delays (0-1)
    ///   - retryIf: Predicate to determine if error is retryable
    ///   - operation: Operation to execute
    /// - Returns: Result of the operation
    /// - Throws: Last error if all attempts fail
    public static func withRetry<T>(
        maxAttempts: Int = DEFAULT_MAX_ATTEMPTS,
        initialDelayMs: Int64 = DEFAULT_INITIAL_DELAY_MS,
        maxDelayMs: Int64 = DEFAULT_MAX_DELAY_MS,
        backoffMultiplier: Double = DEFAULT_BACKOFF_MULTIPLIER,
        jitterFactor: Double = DEFAULT_JITTER_FACTOR,
        retryIf: ((Error) -> Bool)? = nil,
        operation: () throws -> T
    ) throws -> T {
        var attempt = 0
        var lastError: Error?
        var currentDelay = initialDelayMs
        
        while attempt < maxAttempts {
            do {
                // If not first attempt, log the retry
                if attempt > 0 {
                    Logger.debug("Retry attempt \(attempt)/\(maxAttempts) after \(currentDelay)ms delay")
                }
                
                // Execute the operation
                let result = try operation()
                
                // If successful, log success after retry (if not first attempt)
                if attempt > 0 {
                    Logger.debug("Operation succeeded after \(attempt) retries")
                }
                
                return result
            } catch let error {
                lastError = error
                
                // Check if error is retryable
                let isRetryable = retryIf?(error) ?? true
                
                // If not retryable or last attempt, don't retry
                if !isRetryable || attempt >= maxAttempts - 1 {
                    break
                }
                
                // Log the error and retry
                Logger.debug("Operation failed (attempt \(attempt + 1)/\(maxAttempts)): \(error.localizedDescription)")
                
                // Sleep for the current delay
                Thread.sleep(forTimeInterval: TimeInterval(currentDelay) / 1000.0)
                
                // Calculate next delay with exponential backoff and jitter
                let nextDelay = calculateNextDelay(
                    currentDelay: currentDelay,
                    maxDelayMs: maxDelayMs,
                    backoffMultiplier: backoffMultiplier,
                    jitterFactor: jitterFactor
                )
                
                currentDelay = nextDelay
                attempt += 1
            }
        }
        
        // All attempts failed
        Logger.warning("Operation failed after \(maxAttempts) attempts")
        throw lastError ?? NSError(domain: "RetryUtil", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    /// Execute async operation with retry logic
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - initialDelayMs: Initial delay between retries in milliseconds
    ///   - maxDelayMs: Maximum delay between retries in milliseconds
    ///   - backoffMultiplier: Multiplier for exponential backoff
    ///   - jitterFactor: Random factor to add jitter to delays (0-1)
    ///   - retryIf: Predicate to determine if error is retryable
    ///   - operation: Async operation to execute
    ///   - completion: Completion handler with result or error
    public static func withRetryAsync<T>(
        maxAttempts: Int = DEFAULT_MAX_ATTEMPTS,
        initialDelayMs: Int64 = DEFAULT_INITIAL_DELAY_MS,
        maxDelayMs: Int64 = DEFAULT_MAX_DELAY_MS,
        backoffMultiplier: Double = DEFAULT_BACKOFF_MULTIPLIER,
        jitterFactor: Double = DEFAULT_JITTER_FACTOR,
        retryIf: ((Error) -> Bool)? = nil,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        executeRetryAsync(
            maxAttempts: maxAttempts,
            initialDelayMs: initialDelayMs,
            maxDelayMs: maxDelayMs,
            backoffMultiplier: backoffMultiplier,
            jitterFactor: jitterFactor,
            retryIf: retryIf,
            attempt: 0,
            currentDelay: initialDelayMs,
            operation: operation,
            completion: completion
        )
    }
    
    // MARK: - Helper Methods
    
    /// Execute the retry logic recursively for async operations
    private static func executeRetryAsync<T>(
        maxAttempts: Int,
        initialDelayMs: Int64,
        maxDelayMs: Int64,
        backoffMultiplier: Double,
        jitterFactor: Double,
        retryIf: ((Error) -> Bool)?,
        attempt: Int,
        currentDelay: Int64,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // If not first attempt, log the retry
        if attempt > 0 {
            Logger.debug("Retry attempt \(attempt)/\(maxAttempts) after \(currentDelay)ms delay")
        }
        
        // Execute the operation
        operation { result in
            switch result {
            case .success(let value):
                // If successful, log success after retry (if not first attempt)
                if attempt > 0 {
                    Logger.debug("Operation succeeded after \(attempt) retries")
                }
                
                completion(.success(value))
                
            case .failure(let error):
                // Check if error is retryable
                let isRetryable = retryIf?(error) ?? true
                
                // If not retryable or last attempt, don't retry
                if !isRetryable || attempt >= maxAttempts - 1 {
                    Logger.warning("Operation failed after \(attempt + 1) attempts: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Log the error and retry
                Logger.debug("Operation failed (attempt \(attempt + 1)/\(maxAttempts)): \(error.localizedDescription)")
                
                // Calculate next delay with exponential backoff and jitter
                let nextDelay = calculateNextDelay(
                    currentDelay: currentDelay,
                    maxDelayMs: maxDelayMs,
                    backoffMultiplier: backoffMultiplier,
                    jitterFactor: jitterFactor
                )
                
                // Schedule retry after delay
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(currentDelay))) {
                    executeRetryAsync(
                        maxAttempts: maxAttempts,
                        initialDelayMs: initialDelayMs,
                        maxDelayMs: maxDelayMs,
                        backoffMultiplier: backoffMultiplier,
                        jitterFactor: jitterFactor,
                        retryIf: retryIf,
                        attempt: attempt + 1,
                        currentDelay: nextDelay,
                        operation: operation,
                        completion: completion
                    )
                }
            }
        }
    }
    
    /// Calculate the next retry delay with exponential backoff and jitter
    private static func calculateNextDelay(
        currentDelay: Int64,
        maxDelayMs: Int64,
        backoffMultiplier: Double,
        jitterFactor: Double
    ) -> Int64 {
        // Calculate exponential backoff
        let exponentialDelay = min(
            Int64(Double(currentDelay) * backoffMultiplier),
            maxDelayMs
        )
        
        // Add jitter
        let jitterRange = Double(exponentialDelay) * jitterFactor
        let jitter = Int64(Double.random(in: -jitterRange...jitterRange))
        
        // Ensure delay is within bounds
        return max(0, min(exponentialDelay + jitter, maxDelayMs))
    }
    
    // MARK: - Convenience Methods
    
    /// Execute operation with timeout
    ///
    /// - Parameters:
    ///   - timeoutMs: Timeout in milliseconds
    ///   - operation: Operation to execute
    /// - Returns: Result of the operation or nil if timed out
    public static func withTimeout<T>(
        timeoutMs: Int64,
        operation: @escaping () throws -> T
    ) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T?
        var operationError: Error?
        
        // Execute operation in background
        DispatchQueue.global().async {
            do {
                result = try operation()
            } catch {
                operationError = error
            }
            semaphore.signal()
        }
        
        // Wait for completion or timeout
        if semaphore.wait(timeout: .now() + .milliseconds(Int(timeoutMs))) == .timedOut {
            Logger.warning("Operation timed out after \(timeoutMs)ms")
            return nil
        }
        
        // If operation completed with error, log it
        if let error = operationError {
            Logger.warning("Operation failed with error: \(error.localizedDescription)")
        }
        
        return result
    }
    
    /// Execute async operation with timeout
    ///
    /// - Parameters:
    ///   - timeoutMs: Timeout in milliseconds
    ///   - operation: Async operation to execute
    ///   - completion: Completion handler with result or nil if timed out
    public static func withTimeoutAsync<T>(
        timeoutMs: Int64,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T?, Error>?) -> Void
    ) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        var completed = false
        
        // Set timeout
        timer.schedule(deadline: .now() + .milliseconds(Int(timeoutMs)))
        timer.setEventHandler {
            if !completed {
                completed = true
                Logger.warning("Operation timed out after \(timeoutMs)ms")
                completion(nil)
                timer.cancel()
            }
        }
        timer.resume()
        
        // Execute operation
        operation { result in
            if !completed {
                completed = true
                completion(result)
                timer.cancel()
            }
        }
    }
} 