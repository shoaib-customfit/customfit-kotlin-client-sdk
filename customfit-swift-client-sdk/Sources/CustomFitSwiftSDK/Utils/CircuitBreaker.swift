import Foundation

/// Circuit state enumeration
public enum CircuitState {
    /// Circuit is closed and operations can proceed normally
    case closed
    
    /// Circuit is open and operations will fail-fast without executing
    case open
    
    /// Circuit is allowing a limited number of operations to test if the system has recovered
    case halfOpen
}

/// CircuitBreaker implementation to prevent cascading failures
public class CircuitBreaker {
    
    // MARK: - Properties
    
    /// Unique identifier for this circuit breaker
    private let name: String
    
    /// Maximum number of failures before the circuit opens
    private let failureThreshold: Int
    
    /// Time window in milliseconds after which to reset failure count
    private let resetTimeoutMs: Int64
    
    /// Time to wait before attempting to close circuit after opening
    private let halfOpenTimeoutMs: Int64
    
    /// Current state of the circuit
    private var _state: CircuitState = .closed
    private let stateLock = NSLock()
    
    /// Current failure count
    private var _failureCount: Int = 0
    private let countLock = NSLock()
    
    /// Timestamp when circuit was opened
    private var openTimestamp: Int64 = 0
    
    /// Last time failure count was reset
    private var lastResetTime: Int64 = 0
    
    /// Storage for circuit breakers by name
    private static var circuitBreakers = [String: CircuitBreaker]()
    private static let circuitBreakersLock = NSLock()
    
    /// Timestamp provider for testing
    internal var currentTimeProvider: () -> Int64 = {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    // MARK: - Computed Properties
    
    /// Current state of the circuit
    public var state: CircuitState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state
    }
    
    /// Current failure count
    public var failureCount: Int {
        countLock.lock()
        defer { countLock.unlock() }
        return _failureCount
    }
    
    // MARK: - Initialization
    
    /// Creates a new circuit breaker
    /// - Parameters:
    ///   - name: Unique identifier for this circuit breaker
    ///   - failureThreshold: Maximum failures before opening circuit
    ///   - resetTimeoutMs: Time window in ms to count failures
    ///   - halfOpenTimeoutMs: Time in ms before trying to close circuit after opening
    private init(
        name: String,
        failureThreshold: Int,
        resetTimeoutMs: Int64,
        halfOpenTimeoutMs: Int64
    ) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.resetTimeoutMs = resetTimeoutMs
        self.halfOpenTimeoutMs = halfOpenTimeoutMs
        self.lastResetTime = currentTimeProvider()
    }
    
    // MARK: - Static Methods
    
    /// Get or create a circuit breaker with the given parameters
    /// - Parameters:
    ///   - name: Unique identifier for the circuit breaker
    ///   - failureThreshold: Maximum failures before opening circuit
    ///   - resetTimeoutMs: Time window in ms to count failures
    ///   - halfOpenTimeoutMs: Time in ms before trying to close circuit after opening
    /// - Returns: A new or existing circuit breaker
    public static func getOrCreate(
        name: String,
        failureThreshold: Int = 5,
        resetTimeoutMs: Int64 = 60000,
        halfOpenTimeoutMs: Int64 = 30000
    ) -> CircuitBreaker {
        circuitBreakersLock.lock()
        defer { circuitBreakersLock.unlock() }
        
        if let existingBreaker = circuitBreakers[name] {
            return existingBreaker
        }
        
        let newBreaker = CircuitBreaker(
            name: name,
            failureThreshold: failureThreshold,
            resetTimeoutMs: resetTimeoutMs,
            halfOpenTimeoutMs: halfOpenTimeoutMs
        )
        
        circuitBreakers[name] = newBreaker
        return newBreaker
    }
    
    /// Remove all circuit breakers (primarily for testing)
    public static func reset() {
        circuitBreakersLock.lock()
        defer { circuitBreakersLock.unlock() }
        circuitBreakers.removeAll()
    }
    
    // MARK: - Circuit Breaker Methods
    
    /// Execute an operation with circuit breaker protection
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - fallback: Optional fallback value to return if circuit is open
    /// - Returns: The result of the operation or fallback
    public func execute<T>(operation: () throws -> T, fallback: T? = nil) throws -> T {
        // Check if we need to transition from open to half-open
        checkStateTransition()
        
        // Check if circuit is open
        if state == .open {
            Logger.debug("Circuit '\(name)' is open, failing fast")
            
            if let fallbackValue = fallback {
                return fallbackValue
            }
            
            throw CircuitBreakerError.circuitOpen
        }
        
        do {
            // Execute the operation
            let result = try operation()
            
            // If we're in half-open state and operation succeeded, close the circuit
            if state == .halfOpen {
                Logger.info("Circuit '\(name)' test succeeded in half-open state, closing circuit")
                closeCircuit()
            }
            
            return result
        } catch {
            // Record the failure
            recordFailure()
            
            // If fallback is provided, return it
            if let fallbackValue = fallback {
                return fallbackValue
            }
            
            // Otherwise rethrow the error
            throw error
        }
    }
    
    /// Execute an async operation with circuit breaker protection
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - fallback: Optional fallback value to return if circuit is open
    /// - Returns: The result of the operation or fallback
    public func executeAsync<T>(
        operation: (@escaping (Result<T, Error>) -> Void) -> Void,
        fallback: T? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Check if we need to transition from open to half-open
        checkStateTransition()
        
        // Check if circuit is open
        if state == .open {
            Logger.debug("Circuit '\(name)' is open, failing fast")
            
            if let fallbackValue = fallback {
                completion(.success(fallbackValue))
            } else {
                completion(.failure(CircuitBreakerError.circuitOpen))
            }
            return
        }
        
        // Execute the operation
        operation { [weak self] result in
            guard let self = self else {
                completion(result)
                return
            }
            
            switch result {
            case .success(let value):
                // If we're in half-open state and operation succeeded, close the circuit
                if self.state == .halfOpen {
                    Logger.info("Circuit '\(self.name)' test succeeded in half-open state, closing circuit")
                    self.closeCircuit()
                }
                completion(.success(value))
                
            case .failure(let error):
                // Record the failure
                self.recordFailure()
                
                // If fallback is provided, return it
                if let fallbackValue = fallback {
                    completion(.success(fallbackValue))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Record a successful operation
    public func recordSuccess() {
        // If we're in half-open state, close the circuit
        if state == .halfOpen {
            Logger.info("Circuit '\(name)' test succeeded in half-open state, closing circuit")
            closeCircuit()
        }
    }
    
    /// Record a failed operation
    public func recordFailure() {
        countLock.lock()
        
        // Check if we need to reset the failure count due to time window
        let now = currentTimeProvider()
        if now - lastResetTime > resetTimeoutMs {
            _failureCount = 0
            lastResetTime = now
        }
        
        // Increment failure count
        _failureCount += 1
        
        let currentCount = _failureCount
        countLock.unlock()
        
        // Check if we need to open the circuit
        if currentCount >= failureThreshold && state == .closed {
            Logger.warning("Circuit '\(name)' threshold reached (\(currentCount)/\(failureThreshold) failures), opening circuit")
            openCircuit()
        }
    }
    
    // MARK: - Private Methods
    
    /// Open the circuit
    private func openCircuit() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        _state = .open
        openTimestamp = currentTimeProvider()
        Logger.info("Circuit '\(name)' opened")
    }
    
    /// Close the circuit
    private func closeCircuit() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        _state = .closed
        
        countLock.lock()
        _failureCount = 0
        lastResetTime = currentTimeProvider()
        countLock.unlock()
        
        Logger.info("Circuit '\(name)' closed")
    }
    
    /// Transition to half-open state if appropriate
    private func transitionToHalfOpen() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        _state = .halfOpen
        Logger.info("Circuit '\(name)' transitioned to half-open state")
    }
    
    /// Check if state transition is needed
    private func checkStateTransition() {
        if state == .open {
            let now = currentTimeProvider()
            if now - openTimestamp > halfOpenTimeoutMs {
                Logger.debug("Circuit '\(name)' half-open timeout reached, transitioning to half-open state")
                transitionToHalfOpen()
            }
        }
    }
}

/// Circuit Breaker Error
public enum CircuitBreakerError: Error {
    /// Circuit is open and operation was rejected
    case circuitOpen
}

/// Extension with convenience methods similar to Kotlin's withCircuitBreaker
public extension CircuitBreaker {
    /// Execute an operation with a fallback value
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - fallback: Fallback value if circuit is open or operation fails
    /// - Returns: The result of operation or fallback
    static func withCircuitBreaker<T>(
        name: String,
        failureThreshold: Int = 5,
        resetTimeoutMs: Int64 = 60000,
        fallback: T,
        operation: () throws -> T
    ) -> T {
        let breaker = CircuitBreaker.getOrCreate(
            name: name,
            failureThreshold: failureThreshold,
            resetTimeoutMs: resetTimeoutMs
        )
        
        do {
            return try breaker.execute(operation: operation, fallback: fallback)
        } catch {
            return fallback
        }
    }
    
    /// Execute an async operation with a fallback value
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - fallback: Fallback value if circuit is open or operation fails
    ///   - completion: Completion handler with the result
    static func withCircuitBreakerAsync<T>(
        name: String,
        failureThreshold: Int = 5,
        resetTimeoutMs: Int64 = 60000,
        fallback: T,
        operation: (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (T) -> Void
    ) {
        let breaker = CircuitBreaker.getOrCreate(
            name: name,
            failureThreshold: failureThreshold,
            resetTimeoutMs: resetTimeoutMs
        )
        
        breaker.executeAsync(
            operation: operation,
            fallback: fallback
        ) { result in
            switch result {
            case .success(let value):
                completion(value)
            case .failure:
                completion(fallback)
            }
        }
    }
} 