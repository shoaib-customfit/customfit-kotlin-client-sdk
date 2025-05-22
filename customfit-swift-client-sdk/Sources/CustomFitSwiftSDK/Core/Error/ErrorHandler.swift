import Foundation

/// Centralized error handling utility providing standardized error handling,
/// categorization, and reporting capabilities.
public class ErrorHandler {
    
    // MARK: - Enums
    
    /// Error categories for classification
    public enum ErrorCategory: String {
        case network
        case serialization
        case validation
        case permission
        case timeout
        case `internal`
        case unknown
        case state
    }
    
    /// Error severity levels
    public enum ErrorSeverity: String {
        /// Minor issues that don't impact functionality
        case low
        /// Important issues that may impact some functionality
        case medium
        /// Critical issues that significantly impact functionality
        case high
        /// Fatal issues that completely break functionality
        case critical
    }
    
    // MARK: - Properties
    
    /// Track error occurrences for rate limiting and pattern detection
    private static let errorCounts = NSCountedSet()
    private static let errorCountsQueue = DispatchQueue(label: "ai.customfit.errorHandling", attributes: .concurrent)
    private static let MAX_LOG_RATE = 10 // Max times to log same error in a session
    
    // MARK: - Public Methods
    
    /// Handles and logs an exception with standard categorization
    /// - Parameters:
    ///   - error: The error to handle
    ///   - message: The error message
    ///   - source: The component where the error occurred
    ///   - severity: The error severity
    /// - Returns: The appropriate ErrorCategory for the exception
    @discardableResult
    public static func handleException(
        error: Error,
        message: String,
        source: String = "unknown",
        severity: ErrorSeverity = .medium
    ) -> ErrorCategory {
        // Categorize the error
        let category = categorizeError(error)
        
        // Build enhanced error message
        let enhancedMessage = buildErrorMessage(message: message, source: source, severity: severity, category: category)
        
        // Rate-limit repeated errors
        let errorKey = "\(type(of: error)):\(source):\(message)"
        let count = incrementErrorCount(for: errorKey)
        
        if count <= MAX_LOG_RATE {
            // Log with appropriate level based on severity
            switch severity {
            case .low:
                Logger.debug("\(enhancedMessage): \(error.localizedDescription)")
            case .medium:
                Logger.warning("\(enhancedMessage): \(error.localizedDescription)")
            case .high, .critical:
                Logger.error("\(enhancedMessage): \(error.localizedDescription)")
            }
        } else if count == MAX_LOG_RATE + 1 {
            // Log that we're rate limiting this error
            Logger.warning("Rate limiting similar error: \(errorKey). Further occurrences won't be logged.")
        }
        
        return category
    }
    
    /// Handles an error condition without an exception
    /// - Parameters:
    ///   - message: The error message
    ///   - source: The component where the error occurred
    ///   - category: The error category
    ///   - severity: The error severity
    public static func handleError(
        message: String,
        source: String = "unknown",
        category: ErrorCategory = .unknown,
        severity: ErrorSeverity = .medium
    ) {
        // Build enhanced error message
        let enhancedMessage = buildErrorMessage(message: message, source: source, severity: severity, category: category)
        
        // Rate-limit repeated errors
        let errorKey = "\(source):\(message):\(category)"
        let count = incrementErrorCount(for: errorKey)
        
        if count <= MAX_LOG_RATE {
            // Log with appropriate level based on severity
            switch severity {
            case .low:
                Logger.debug(enhancedMessage)
            case .medium:
                Logger.warning(enhancedMessage)
            case .high, .critical:
                Logger.error(enhancedMessage)
            }
        } else if count == MAX_LOG_RATE + 1 {
            // Log that we're rate limiting this error
            Logger.warning("Rate limiting similar error: \(errorKey). Further occurrences won't be logged.")
        }
    }
    
    /// Clears the error count tracking
    public static func resetErrorCounts() {
        errorCountsQueue.async(flags: .barrier) {
            errorCounts.removeAllObjects()
        }
    }
    
    // MARK: - Private Methods
    
    /// Determines the category of an error
    private static func categorizeError(_ error: Error) -> ErrorCategory {
        let nsError = error as NSError
        
        // Check error domain and code for known network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, 
                 NSURLErrorNotConnectedToInternet, NSURLErrorDNSLookupFailed:
                return .network
            default:
                break
            }
        }
        
        // Check error types
        if error is DecodingError || error is EncodingError {
            return .serialization
        } else if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 257 {
            // NSFileReadNoPermissionError
            return .permission
        } else if let _ = error as? URLError {
            return .network
        }
        
        // Check localized description for common patterns
        let description = error.localizedDescription.lowercased()
        if description.contains("timeout") || description.contains("timed out") {
            return .timeout
        } else if description.contains("network") || description.contains("internet") || 
                  description.contains("host") || description.contains("connection") {
            return .network
        } else if description.contains("permission") || description.contains("denied") {
            return .permission
        } else if description.contains("invalid") || description.contains("illegal") {
            return .validation
        }
        
        return .unknown
    }
    
    /// Thread-safe increment of error count
    private static func incrementErrorCount(for key: String) -> Int {
        var count = 0
        errorCountsQueue.sync {
            errorCounts.add(key)
            count = errorCounts.count(for: key)
        }
        return count
    }
    
    /// Builds a standardized error message
    private static func buildErrorMessage(
        message: String,
        source: String,
        severity: ErrorSeverity,
        category: ErrorCategory
    ) -> String {
        return "[\(source)] [\(severity.rawValue.uppercased())] [\(category.rawValue.uppercased())] \(message)"
    }
}

// MARK: - Extensions for ErrorCategory Conversion

extension ErrorHandler.ErrorCategory {
    /// Convert ErrorHandler.ErrorCategory to CFErrorCategory
    public var toCFErrorCategory: CFErrorCategory {
        switch self {
        case .network:
            return .network
        case .serialization:
            return .serialization
        case .validation:
            return .validation
        case .permission:
            return .permission
        case .timeout:
            return .timeout
        case .internal:
            return .state
        case .state:
            return .state
        case .unknown:
            return .unknown
        }
    }
}

extension CFErrorCategory {
    /// Convert CFErrorCategory to ErrorHandler.ErrorCategory
    public var toErrorHandlerCategory: ErrorHandler.ErrorCategory {
        switch self {
        case .network:
            return .network
        case .serialization:
            return .serialization
        case .validation:
            return .validation
        case .permission:
            return .permission
        case .timeout:
            return .timeout
        case .state:
            return .state
        case .storage:
            return .internal
        case .configuration:
            return .internal
        case .authentication:
            return .permission
        case .api:
            return .network
        case .featureFlag:
            return .internal
        case .unknown:
            return .unknown
        }
    }
} 