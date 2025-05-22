import Foundation

/// Error category for CustomFit error
public enum CFErrorCategory: String {
    /// Network-related errors
    case network = "NETWORK"
    
    /// Configuration-related errors
    case configuration = "CONFIGURATION"
    
    /// Authentication-related errors
    case authentication = "AUTHENTICATION"
    
    /// Validation-related errors
    case validation = "VALIDATION"
    
    /// Internal errors
    case `internal` = "INTERNAL"
    
    /// Unknown errors
    case unknown = "UNKNOWN"
}

/// Error code for CustomFit error
public enum CFErrorCode: Int {
    /// Network connection error
    case networkConnectionError = 1001
    
    /// Network timeout error
    case networkTimeoutError = 1002
    
    /// Network response error
    case networkResponseError = 1003
    
    /// Configuration missing error
    case configurationMissingError = 2001
    
    /// Configuration invalid error
    case configurationInvalidError = 2002
    
    /// Authentication failed error
    case authenticationFailedError = 3001
    
    /// Authentication token expired error
    case authenticationTokenExpiredError = 3002
    
    /// Validation missing field error
    case validationMissingFieldError = 4001
    
    /// Validation invalid field error
    case validationInvalidFieldError = 4002
    
    /// Internal error
    case internalError = 5001
    
    /// Unknown error
    case unknownError = 9999
}

/// CustomFit error class
public class CFError: Error {
    /// Error code
    public let code: CFErrorCode
    
    /// Error category
    public let category: CFErrorCategory
    
    /// Error message
    public let message: String
    
    /// Underlying error
    public let underlyingError: Error?
    
    /// Extra information
    public let info: [String: Any]?
    
    /// Initialize a new CustomFit error
    /// - Parameters:
    ///   - code: Error code
    ///   - category: Error category
    ///   - message: Error message
    ///   - underlyingError: Underlying error
    ///   - info: Extra information
    public init(
        code: CFErrorCode,
        category: CFErrorCategory = .unknown,
        message: String,
        underlyingError: Error? = nil,
        info: [String: Any]? = nil
    ) {
        self.code = code
        self.category = category
        self.message = message
        self.underlyingError = underlyingError
        self.info = info
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
            category: .network,
            message: message,
            underlyingError: underlyingError,
            info: info
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
            category: .configuration,
            message: message,
            underlyingError: underlyingError,
            info: info
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
            category: .authentication,
            message: message,
            underlyingError: underlyingError,
            info: info
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
            category: .validation,
            message: message,
            underlyingError: underlyingError,
            info: info
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
            category: .internal,
            message: message,
            underlyingError: underlyingError,
            info: info
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
            code: .unknownError,
            category: .unknown,
            message: message,
            underlyingError: underlyingError,
            info: info
        )
    }
}

/// Extension to provide a localizedDescription
extension CFError: LocalizedError {
    public var errorDescription: String? {
        return message
    }
    
    public var localizedDescription: String {
        return message
    }
} 