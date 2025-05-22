import Foundation

/// Utility for retrying operations with exponential backoff
public class RetryUtil {
    /// Retry an operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts
    ///   - delay: Initial delay in milliseconds
    ///   - maxDelay: Maximum delay in milliseconds
    ///   - factor: Backoff factor (multiplier for next delay)
    ///   - jitter: Jitter factor (0.0-1.0) to add randomness to delay
    ///   - operation: The operation to retry
    /// - Returns: The result of the operation
    public static func withRetry<T>(
        maxAttempts: Int = 3,
        delay: Int = 100,
        maxDelay: Int = 10000,
        factor: Double = 2.0,
        jitter: Double = 0.2,
        operation: () throws -> T
    ) throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                // Try the operation
                return try operation()
            } catch {
                lastError = error
                
                // If this was the last attempt, don't delay
                if attempt == maxAttempts {
                    break
                }
                
                // Add jitter to delay
                let jitterAmount = Double(currentDelay) * jitter
                let jitterRange = -jitterAmount...jitterAmount
                let jitteredDelay = currentDelay + Int(jitterRange.lowerBound + (jitterRange.upperBound - jitterRange.lowerBound) * Double.random(in: 0...1))
                
                // Sleep for the calculated delay
                Thread.sleep(forTimeInterval: TimeInterval(jitteredDelay) / 1000.0)
                
                // Increase delay for next attempt, but cap it
                currentDelay = min(maxDelay, Int(Double(currentDelay) * factor))
            }
        }
        
        // If we reached here, all attempts failed
        throw lastError ?? NSError(domain: "RetryUtil", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    /// Retry an asynchronous operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts
    ///   - delay: Initial delay in milliseconds
    ///   - maxDelay: Maximum delay in milliseconds
    ///   - factor: Backoff factor (multiplier for next delay)
    ///   - jitter: Jitter factor (0.0-1.0) to add randomness to delay
    ///   - operation: The asynchronous operation to retry
    /// - Returns: The result of the operation
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func withRetryAsync<T>(
        maxAttempts: Int = 3,
        delay: Int = 100,
        maxDelay: Int = 10000,
        factor: Double = 2.0,
        jitter: Double = 0.2,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            retryAsync(
                currentAttempt: 1,
                maxAttempts: maxAttempts,
                delay: delay,
                maxDelay: maxDelay,
                factor: factor,
                jitter: jitter,
                operation: operation,
                continuation: continuation
            )
        }
    }
    
    /// Helper for retrying an asynchronous operation recursively
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private static func retryAsync<T>(
        currentAttempt: Int,
        maxAttempts: Int,
        delay: Int,
        maxDelay: Int,
        factor: Double,
        jitter: Double,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        continuation: CheckedContinuation<T, Error>
    ) {
        operation { result in
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
                
            case .failure(let error):
                if currentAttempt >= maxAttempts {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Calculate next delay with jitter
                let currentDelay = min(maxDelay, Int(pow(Double(delay), Double(currentAttempt)) * factor))
                let jitterAmount = Double(currentDelay) * jitter
                let jitterRange = -jitterAmount...jitterAmount
                let jitteredDelay = currentDelay + Int(jitterRange.lowerBound + (jitterRange.upperBound - jitterRange.lowerBound) * Double.random(in: 0...1))
                
                // Schedule retry after delay
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(jitteredDelay)) {
                    retryAsync(
                        currentAttempt: currentAttempt + 1,
                        maxAttempts: maxAttempts,
                        delay: delay,
                        maxDelay: maxDelay,
                        factor: factor,
                        jitter: jitter,
                        operation: operation,
                        continuation: continuation
                    )
                }
            }
        }
    }
    
    /// Transform a closure with completion handler into an async operation
    /// - Parameter body: The closure with completion handler
    /// - Returns: The result of the operation
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func asyncOperation<T>(
        body: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            body { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
} 