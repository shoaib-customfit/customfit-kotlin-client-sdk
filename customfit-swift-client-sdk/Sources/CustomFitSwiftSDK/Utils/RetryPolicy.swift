import Foundation

/// Error type for retry operations
public enum RetryError: Error {
    /// Indicates that the maximum number of retry attempts was reached
    case maxAttemptsExceeded(attempts: Int, underlyingError: Error?)
    
    /// Indicates a general retry error
    case retryFailed(message: String, underlyingError: Error?)
}

/// Protocol for retry policy that defines how operations should be retried
public protocol RetryPolicy {
    /// Execute an operation with retry
    /// - Parameters:
    ///   - operation: The operation to execute
    /// - Returns: The result of the operation
    func execute<T>(_ operation: @escaping () throws -> T) throws -> T
    
    /// Execute an operation with retry and completion handler
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - completion: Completion handler called with the result
    func executeAsync<T>(_ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void, completion: @escaping (Result<T, Error>) -> Void)
}

/// Configuration for exponential backoff retry policy
public struct ExponentialBackoffRetryConfig {
    /// Maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Initial delay in milliseconds
    public let initialDelayMs: Int64
    
    /// Maximum delay in milliseconds
    public let maxDelayMs: Int64
    
    /// Backoff multiplier for each retry
    public let backoffMultiplier: Double
    
    /// Jitter factor to randomize delay
    public let jitterFactor: Double
    
    /// Initialize with default values
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - initialDelayMs: Initial delay in milliseconds
    ///   - maxDelayMs: Maximum delay in milliseconds
    ///   - backoffMultiplier: Backoff multiplier for each retry
    ///   - jitterFactor: Jitter factor to randomize delay
    public init(
        maxAttempts: Int = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS,
        initialDelayMs: Int64 = CFConstants.RetryConfig.INITIAL_DELAY_MS,
        maxDelayMs: Int64 = CFConstants.RetryConfig.MAX_DELAY_MS,
        backoffMultiplier: Double = CFConstants.RetryConfig.BACKOFF_MULTIPLIER,
        jitterFactor: Double = CFConstants.RetryConfig.JITTER_FACTOR
    ) {
        precondition(maxAttempts >= 0, "maxAttempts must be non-negative")
        precondition(initialDelayMs > 0, "initialDelayMs must be positive")
        precondition(maxDelayMs >= initialDelayMs, "maxDelayMs must be greater than or equal to initialDelayMs")
        precondition(backoffMultiplier > 1.0, "backoffMultiplier must be greater than 1.0")
        precondition(jitterFactor >= 0.0 && jitterFactor <= 1.0, "jitterFactor must be between 0.0 and 1.0")
        
        self.maxAttempts = maxAttempts
        self.initialDelayMs = initialDelayMs
        self.maxDelayMs = maxDelayMs
        self.backoffMultiplier = backoffMultiplier
        self.jitterFactor = jitterFactor
    }
}

/// Implementation of exponential backoff retry policy
public class ExponentialBackoffRetryPolicy: RetryPolicy {
    
    /// Configuration for the retry policy
    private let config: ExponentialBackoffRetryConfig
    
    /// Whether the current operation should be retried
    private let shouldRetry: (Error) -> Bool
    
    /// Whether to log retry attempts
    private let logRetryAttempts: Bool
    
    /// Dispatch queue for async operations
    private let queue: DispatchQueue
    
    /// Initialize with configuration
    /// - Parameters:
    ///   - config: Configuration for the retry policy
    ///   - shouldRetry: Closure that determines whether an error should be retried
    ///   - logRetryAttempts: Whether to log retry attempts
    ///   - queue: Dispatch queue for async operations
    public init(
        config: ExponentialBackoffRetryConfig = ExponentialBackoffRetryConfig(),
        shouldRetry: @escaping (Error) -> Bool = { _ in true },
        logRetryAttempts: Bool = true,
        queue: DispatchQueue = DispatchQueue.global(qos: .utility)
    ) {
        self.config = config
        self.shouldRetry = shouldRetry
        self.logRetryAttempts = logRetryAttempts
        self.queue = queue
    }
    
    /// Execute an operation with retry
    /// - Parameter operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: RetryError or the error from the operation
    public func execute<T>(_ operation: @escaping () throws -> T) throws -> T {
        var lastError: Error?
        
        for attempt in 1...config.maxAttempts {
            do {
                // Execute the operation
                let result = try operation()
                
                // If successful, return the result
                if logRetryAttempts && attempt > 1 {
                    Logger.info("Retry succeeded on attempt \(attempt)/\(config.maxAttempts)")
                }
                
                return result
            } catch let error {
                lastError = error
                
                // Check if we should retry
                if !shouldRetry(error) {
                    if logRetryAttempts {
                        Logger.info("Not retrying on attempt \(attempt)/\(config.maxAttempts): Error type not eligible for retry")
                    }
                    throw error
                }
                
                // Check if we've reached the maximum attempts
                if attempt >= config.maxAttempts {
                    if logRetryAttempts {
                        Logger.warning("Retry failed after \(attempt)/\(config.maxAttempts) attempts")
                    }
                    break
                }
                
                // Calculate delay with jitter
                let delay = calculateDelayWithJitter(attempt: attempt)
                
                if logRetryAttempts {
                    Logger.info("Retry attempt \(attempt)/\(config.maxAttempts) failed, retrying in \(delay)ms: \(error.localizedDescription)")
                }
                
                // Sleep for the calculated delay
                Thread.sleep(forTimeInterval: Double(delay) / 1000.0)
            }
        }
        
        throw RetryError.maxAttemptsExceeded(attempts: config.maxAttempts, underlyingError: lastError)
    }
    
    /// Execute an operation with retry and completion handler
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - completion: Completion handler called with the result
    public func executeAsync<T>(_ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void, completion: @escaping (Result<T, Error>) -> Void) {
        executeAsyncInternal(operation: operation, attempt: 1, lastError: nil, completion: completion)
    }
    
    // MARK: - Private Methods
    
    /// Recursively execute an async operation with retry
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - attempt: Current attempt number
    ///   - lastError: Last error encountered
    ///   - completion: Completion handler called with the result
    private func executeAsyncInternal<T>(
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        attempt: Int,
        lastError: Error?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Check if we've reached the maximum attempts
        if attempt > config.maxAttempts {
            if logRetryAttempts {
                Logger.warning("Retry failed after \(attempt-1)/\(config.maxAttempts) attempts")
            }
            
            completion(.failure(RetryError.maxAttemptsExceeded(attempts: config.maxAttempts, underlyingError: lastError)))
            return
        }
        
        // Execute the operation
        operation { result in
            switch result {
            case .success(let value):
                // If successful, return the result
                if self.logRetryAttempts && attempt > 1 {
                    Logger.info("Retry succeeded on attempt \(attempt)/\(self.config.maxAttempts)")
                }
                
                completion(.success(value))
                
            case .failure(let error):
                // Check if we should retry
                if !self.shouldRetry(error) {
                    if self.logRetryAttempts {
                        Logger.info("Not retrying on attempt \(attempt)/\(self.config.maxAttempts): Error type not eligible for retry")
                    }
                    completion(.failure(error))
                    return
                }
                
                // Check if we've reached the maximum attempts
                if attempt >= self.config.maxAttempts {
                    if self.logRetryAttempts {
                        Logger.warning("Retry failed after \(attempt)/\(self.config.maxAttempts) attempts")
                    }
                    completion(.failure(RetryError.maxAttemptsExceeded(attempts: self.config.maxAttempts, underlyingError: error)))
                    return
                }
                
                // Calculate delay with jitter
                let delay = self.calculateDelayWithJitter(attempt: attempt)
                
                if self.logRetryAttempts {
                    Logger.info("Retry attempt \(attempt)/\(self.config.maxAttempts) failed, retrying in \(delay)ms: \(error.localizedDescription)")
                }
                
                // Schedule next retry
                self.queue.asyncAfter(deadline: .now() + .milliseconds(Int(delay))) {
                    self.executeAsyncInternal(operation: operation, attempt: attempt + 1, lastError: error, completion: completion)
                }
            }
        }
    }
    
    /// Calculate delay with exponential backoff and jitter
    /// - Parameter attempt: Current attempt number
    /// - Returns: Delay in milliseconds
    private func calculateDelayWithJitter(attempt: Int) -> Int64 {
        // Calculate exponential backoff
        let exponentialDelay = min(
            Double(config.initialDelayMs) * pow(config.backoffMultiplier, Double(attempt - 1)),
            Double(config.maxDelayMs)
        )
        
        // Apply jitter
        let jitterOffset = Double(exponentialDelay) * config.jitterFactor * Double.random(in: -1.0...1.0)
        let jitteredDelay = exponentialDelay + jitterOffset
        
        // Ensure within bounds
        return Int64(max(Double(config.initialDelayMs), min(jitteredDelay, Double(config.maxDelayMs))))
    }
}

/// Factory for creating retry policies
public class RetryPolicyFactory {
    
    /// Create an exponential backoff retry policy with default configuration
    /// - Returns: A retry policy
    public static func createDefaultRetryPolicy() -> RetryPolicy {
        return ExponentialBackoffRetryPolicy()
    }
    
    /// Create an exponential backoff retry policy with custom configuration
    /// - Parameter config: Custom configuration
    /// - Returns: A retry policy
    public static func createExponentialBackoffRetryPolicy(config: ExponentialBackoffRetryConfig) -> RetryPolicy {
        return ExponentialBackoffRetryPolicy(config: config)
    }
    
    /// Create a retry policy that only retries network errors
    /// - Returns: A retry policy
    public static func createNetworkRetryPolicy() -> RetryPolicy {
        return ExponentialBackoffRetryPolicy(shouldRetry: { error in
            // Check if it's a CFError with network category
            if let cfError = error as? CFError {
                return cfError.category == .network
            }
            
            // Check if it's a URLError
            if let urlError = error as? URLError {
                // Retry for network-related errors
                switch urlError.code {
                case .notConnectedToInternet,
                     .networkConnectionLost,
                     .timedOut,
                     .dnsLookupFailed,
                     .cannotConnectToHost,
                     .cannotFindHost,
                     .secureConnectionFailed:
                    return true
                default:
                    return false
                }
            }
            
            return false
        })
    }
} 