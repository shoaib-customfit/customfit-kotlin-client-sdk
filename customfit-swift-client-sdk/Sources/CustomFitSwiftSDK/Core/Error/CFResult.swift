import Foundation

/// Result type for CustomFit operations
public enum CFResult<Value> {
    /// Represents a successful operation with a result
    case success(value: Value)
    
    /// Represents an error/failure result
    case error(
        message: String,
        error: Error? = nil,
        code: Int? = nil,
        category: CFErrorCategory = .unknown
    )
    
    /// Whether the result is a success
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .error:
            return false
        }
    }
    
    /// Whether the result is an error
    public var isError: Bool {
        return !isSuccess
    }
    
    /// Get the success value if available
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .error:
            return nil
        }
    }
    
    /// Get the error message if available
    public var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .error(let message, _, _, _):
            return message
        }
    }
    
    /// Get the error if available
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .error(_, let error, _, _):
            return error
        }
    }
    
    /// Get the error code if available
    public var errorCode: Int? {
        switch self {
        case .success:
            return nil
        case .error(_, _, let code, _):
            return code
        }
    }
    
    /// Get the error category if available
    public var errorCategory: CFErrorCategory? {
        switch self {
        case .success:
            return nil
        case .error(_, _, _, let category):
            return category
        }
    }
    
    /// Map success value to another type
    /// - Parameter transform: Transform function
    /// - Returns: New result with transformed value
    public func map<T>(_ transform: (Value) -> T) -> CFResult<T> {
        switch self {
        case .success(let value):
            return .success(value: transform(value))
        case .error(let message, let error, let code, let category):
            return .error(message: message, error: error, code: code, category: category)
        }
    }
    
    /// Creates a Success result with the given value
    public static func success(value: Value) -> CFResult<Value> {
        return .success(value: value)
    }
    
    /// Creates an Error result
    public static func error(
        message: String,
        error: Error? = nil,
        code: Int? = nil,
        category: CFErrorCategory = .unknown
    ) -> CFResult<Value> {
        return .error(message: message, error: error, code: code, category: category)
    }
    
    // MARK: - Factory Methods
    
    /// Creates a CFResult from a Swift Result
    public static func from(result: Result<Value, Error>, errorMessage: String = "Operation failed") -> CFResult<Value> {
        switch result {
        case .success(let value):
            return .success(value: value)
        case .failure(let error):
            return .error(message: errorMessage, error: error)
        }
    }
    
    // MARK: - Accessors
    
    /// Returns the success value or nil if this is an error
    public func getOrNil() -> Value? {
        return value
    }
    
    /// Returns the success value or executes the default function if this is an error
    public func getOrElse(_ defaultHandler: (String, Error?, Int?, CFErrorCategory) -> Value) -> Value {
        switch self {
        case .success(let value):
            return value
        case .error(let message, let error, let code, let category):
            return defaultHandler(message, error, code, category)
        }
    }
    
    /// Returns the success value or the default value if this is an error
    public func getOrDefault(_ defaultValue: Value) -> Value {
        return value ?? defaultValue
    }
    
    /// Returns the success value or throws the error
    /// - Throws: The wrapped error or a CFError if no error was provided
    /// - Returns: The success value
    public func getOrThrow() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .error(let message, let error, let code, let category):
            if let error = error {
                throw error
            } else {
                throw CFError(message: message, code: code, category: category)
            }
        }
    }
    
    /// Converts this result to Swift's Result type
    public func toResult() -> Result<Value, Error> {
        switch self {
        case .success(let value):
            return .success(value)
        case .error(let message, let error, let code, let category):
            if let error = error {
                return .failure(error)
            } else {
                return .failure(CFError(message: message, code: code, category: category))
            }
        }
    }
    
    // MARK: - Transformations
    
    /// Transform a success result using the given transform function that may itself fail
    public func flatMap<NewValue>(_ transform: (Value) -> CFResult<NewValue>) -> CFResult<NewValue> {
        switch self {
        case .success(let value):
            return transform(value)
        case .error(let message, let error, let code, let category):
            return .error(message: message, error: error, code: code, category: category)
        }
    }
    
    /// Process the result with respective handlers for success and error
    public func fold<NewValue>(
        onSuccess: (Value) -> NewValue,
        onError: (String, Error?, Int?, CFErrorCategory) -> NewValue
    ) -> NewValue {
        switch self {
        case .success(let value):
            return onSuccess(value)
        case .error(let message, let error, let code, let category):
            return onError(message, error, code, category)
        }
    }
    
    // MARK: - Side-effects
    
    /// Executes the given action if this is a success
    @discardableResult
    public func onSuccess(_ action: (Value) -> Void) -> CFResult<Value> {
        if case .success(let value) = self {
            action(value)
        }
        return self
    }
    
    /// Executes the given action if this is an error
    @discardableResult
    public func onError(_ action: (String, Error?, Int?, CFErrorCategory) -> Void) -> CFResult<Value> {
        if case .error(let message, let error, let code, let category) = self {
            action(message, error, code, category)
        }
        return self
    }
    
    /// Executes an action on both success and error
    @discardableResult
    public func onComplete(action: (CFResult<Value>) -> Void) -> CFResult<Value> {
        action(self)
        return self
    }
    
    /// Wraps any errors from the given operation in a CFResult
    public static func catching(action: () throws -> Value) -> CFResult<Value> {
        do {
            let result = try action()
            return .success(value: result)
        } catch let error as CFError {
            return .error(
                message: error.message,
                error: error,
                code: error.code,
                category: error.category
            )
        } catch {
            return .error(message: error.localizedDescription, error: error)
        }
    }
}

/// Extension for handling Result type conversion
extension CFResult {
    /// Creates a CFResult from a Swift Result
    public static func from<E: Error>(_ result: Result<Value, E>) -> CFResult<Value> {
        switch result {
        case .success(let value):
            return .success(value: value)
        case .failure(let error):
            return .error(message: error.localizedDescription, error: error)
        }
    }
    
    /// Converts an Error into a CFResult.error
    public static func failure(_ error: Error) -> CFResult<Value> {
        if let cfError = error as? CFError {
            return .error(
                message: error.localizedDescription,
                error: error,
                code: cfError.code.rawValue,
                category: cfError.category
            )
        } else {
            return .error(message: error.localizedDescription, error: error)
        }
    }
} 