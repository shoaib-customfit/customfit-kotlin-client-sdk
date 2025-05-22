import Foundation

/// Error code for CustomFit errors
public enum CFErrorCode: Int {
    // Network error codes (1000-1999)
    case networkConnectionError = 1000
    case networkTimeoutError = 1001
    case networkResponseError = 1002
    
    // Configuration error codes (2000-2999)
    case configurationMissingError = 2000
    case configurationInvalidError = 2001
    
    // Authentication error codes (3000-3999)
    case authenticationFailedError = 3000
    case authenticationExpiredError = 3001
    
    // Validation error codes (4000-4999)
    case validationMissingFieldError = 4000
    case validationInvalidFieldError = 4001
    
    // Serialization error codes (5000-5999)
    case serializationError = 5000
    
    // Internal error codes (9000-9999)
    case internalError = 9000
    case unknownError = 9999
}

/// Error category for CustomFit errors
public enum CFErrorCategory: String {
    /// Unknown error
    case unknown
    
    /// Network error
    case network
    
    /// Storage error
    case storage
    
    /// Configuration error
    case configuration
    
    /// Validation error
    case validation
    
    /// Serialization error
    case serialization
    
    /// Authentication error
    case authentication
    
    /// Permission error
    case permission
    
    /// API error
    case api
    
    /// Feature flag error
    case featureFlag
    
    /// State error
    case state
    
    /// Timeout error
    case timeout
}

/// Custom error type for the SDK
public class CFError: Error {
    /// Error message
    public let message: String
    
    /// Original error that caused this error
    public let cause: Error?
    
    /// Error code (optional)
    public let code: CFErrorCode?
    
    /// Error category
    public let category: CFErrorCategory
    
    /// Initialize a new error
    /// - Parameters:
    ///   - code: Error code (optional)
    ///   - message: Error message
    ///   - cause: Original error (optional)
    ///   - category: Error category
    public init(
        code: CFErrorCode? = nil,
        message: String,
        cause: Error? = nil,
        category: CFErrorCategory = .unknown
    ) {
        self.code = code
        self.message = message
        self.cause = cause
        self.category = category
    }
    
    /// Initialize a new error with Int code
    /// - Parameters:
    ///   - code: Error code as Int (optional)
    ///   - message: Error message
    ///   - cause: Original error (optional)
    ///   - category: Error category
    public convenience init(
        code: Int? = nil,
        message: String,
        cause: Error? = nil,
        category: CFErrorCategory = .unknown
    ) {
        let errorCode: CFErrorCode?
        if let code = code, let mappedCode = CFErrorCode(rawValue: code) {
            errorCode = mappedCode
        } else {
            errorCode = nil
        }
        
        self.init(code: errorCode, message: message, cause: cause, category: category)
    }
    
    /// Factory method to create a CFError with all parameters
    /// - Parameters:
    ///   - message: Error message
    ///   - cause: Original error (optional)
    ///   - code: Error code as Int (optional)
    ///   - category: Error category
    /// - Returns: A new CFError instance
    public static func create(
        message: String,
        cause: Error? = nil,
        code: Int? = nil,
        category: CFErrorCategory = .unknown
    ) -> CFError {
        return CFError(code: code, message: message, cause: cause, category: category)
    }
    
    /// Factory method to create a CFError with all parameters
    /// - Parameters:
    ///   - message: Error message
    ///   - cause: Original error (optional)
    ///   - code: Error code (optional)
    ///   - category: Error category
    /// - Returns: A new CFError instance
    public static func create(
        message: String,
        cause: Error? = nil,
        code: CFErrorCode? = nil,
        category: CFErrorCategory = .unknown
    ) -> CFError {
        return CFError(code: code, message: message, cause: cause, category: category)
    }
    
    /// Custom description implementation
    public var localizedDescription: String {
        var result = message
        
        if let code = code {
            result += " (code: \(code.rawValue))"
        }
        
        if let cause = cause {
            result += " - Caused by: \(cause.localizedDescription)"
        }
        
        return result
    }
    
    /// Create a network error
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: A network error
    public static func networkError(
        code: CFErrorCode = .networkConnectionError,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: code,
            message: message,
            cause: underlyingError,
            category: .network
        )
    }
    
    /// Create a configuration error
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: A configuration error
    public static func configurationError(
        code: CFErrorCode = .configurationMissingError,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: code,
            message: message,
            cause: underlyingError,
            category: .configuration
        )
    }
    
    /// Create an authentication error
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: An authentication error
    public static func authenticationError(
        code: CFErrorCode = .authenticationFailedError,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: code,
            message: message,
            cause: underlyingError,
            category: .authentication
        )
    }
    
    /// Create a validation error
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: A validation error
    public static func validationError(
        code: CFErrorCode = .validationMissingFieldError,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: code,
            message: message,
            cause: underlyingError,
            category: .validation
        )
    }
    
    /// Create an internal error
    /// - Parameters:
    ///   - code: Error code
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: An internal error
    public static func internalError(
        code: CFErrorCode = .internalError,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: code,
            message: message,
            cause: underlyingError,
            category: .state
        )
    }
    
    /// Create an unknown error
    /// - Parameters:
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    /// - Returns: An unknown error
    public static func unknownError(
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) -> CFError {
        return CFError(
            code: nil as CFErrorCode?,
            message: message,
            cause: underlyingError,
            category: .unknown
        )
    }
}

/// Extension to provide a localizedDescription
extension CFError: LocalizedError {
    public var errorDescription: String? {
        return message
    }
} 