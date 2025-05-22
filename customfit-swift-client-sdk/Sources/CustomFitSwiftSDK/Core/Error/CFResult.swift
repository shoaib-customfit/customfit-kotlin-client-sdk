import Foundation

/// Represents a result which can be either success or error
public enum CFResult<Value> {
    /// Success case with a value
    case success(value: Value)
    
    /// Error case with details
    case error(message: String, error: Error? = nil, code: Int? = nil, category: CFErrorCategory = .unknown)
    
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
    
    /// Get the value if success, throws an error if not
    /// - Returns: The value
    /// - Throws: CFError if result is error
    public func get() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .error(let message, let error, let code, let category):
            if let error = error {
                throw error
            } else {
                throw CFError(code: code != nil ? CFErrorCode(rawValue: code!) : nil, message: message, category: category)
            }
        }
    }
    
    /// Get the value if success, or nil if error
    /// - Returns: The value or nil
    public func getOrNull() -> Value? {
        switch self {
        case .success(let value):
            return value
        case .error:
            return nil
        }
    }
    
    /// Get the value if success, or default value if error
    /// - Parameter defaultValue: The default value
    /// - Returns: The value or default value
    public func getOrDefault(_ defaultValue: Value) -> Value {
        switch self {
        case .success(let value):
            return value
        case .error:
            return defaultValue
        }
    }
    
    /// Maps the value if success
    /// - Parameter transform: The transform function
    /// - Returns: A new result with transformed value
    public func map<NewValue>(_ transform: (Value) -> NewValue) -> CFResult<NewValue> {
        switch self {
        case .success(let value):
            return .success(value: transform(value))
        case .error(let message, let error, let code, let category):
            return .error(message: message, error: error, code: code, category: category)
        }
    }
    
    /// Maps the value with a potentially failing transform
    /// - Parameter transform: The transform function that may throw
    /// - Returns: A new result with transformed value or error
    public func flatMap<NewValue>(_ transform: (Value) throws -> NewValue) -> CFResult<NewValue> {
        switch self {
        case .success(let value):
            do {
                let newValue = try transform(value)
                return .success(value: newValue)
            } catch {
                return .error(message: "Transform failed: \(error.localizedDescription)", error: error)
            }
        case .error(let message, let error, let code, let category):
            return .error(message: message, error: error, code: code, category: category)
        }
    }
    
    /// Factory methods to create success results
    public static func createSuccess(value: Value) -> CFResult<Value> {
        return .success(value: value)
    }
    
    /// Factory method to create error results
    public static func createError(
        message: String,
        error: Error? = nil,
        code: Int? = nil,
        category: CFErrorCategory = .unknown
    ) -> CFResult<Value> {
        return .error(message: message, error: error, code: code, category: category)
    }
    
    /// Run operation and wrap result
    /// - Parameter action: The action to run
    /// - Returns: CFResult containing result or error
    public static func of<T>(_ action: () throws -> T) -> CFResult<T> {
        do {
            let result = try action()
            return CFResult<T>.success(value: result)
        } catch let error as CFError {
            return CFResult<T>.error(
                message: error.message,
                error: error,
                code: error.code?.rawValue,
                category: error.category
            )
        } catch {
            return CFResult<T>.error(message: error.localizedDescription, error: error)
        }
    }
    
    /// Convert from Result<T, Error>
    /// - Parameter result: Swift standard Result
    /// - Returns: Equivalent CFResult
    public static func from<T, E: Error>(_ result: Result<T, E>, errorMessage: String? = nil) -> CFResult<T> {
        switch result {
        case .success(let value):
            return CFResult<T>.success(value: value)
        case .failure(let error):
            return CFResult<T>.error(
                message: errorMessage ?? error.localizedDescription,
                error: error
            )
        }
    }
    
    // MARK: - Callback Handlers
    
    /// Execute action if result is success
    /// - Parameter action: Action to execute with value
    /// - Returns: Same result for chaining
    @discardableResult
    public func onSuccess(_ action: (Value) -> Void) -> CFResult<Value> {
        if case .success(let value) = self {
            action(value)
        }
        return self
    }
    
    /// Execute action if result is error
    /// - Parameter action: Action to execute with error details
    /// - Returns: Same result for chaining
    @discardableResult
    public func onError(_ action: (String, Error?, Int?, CFErrorCategory) -> Void) -> CFResult<Value> {
        if case .error(let message, let error, let code, let category) = self {
            action(message, error, code, category)
        }
        return self
    }
    
    /// Tries to extract an error or creates a generic one
    /// - Returns: The contained error or a generic one
    public func toError() -> Error {
        switch self {
        case .error(let message, let error, let code, let category):
            if let error = error {
                return error
            } else {
                if let code = code {
                    return CFError(code: CFErrorCode(rawValue: code), message: message, category: category)
                } else {
                    return CFError(code: nil as CFErrorCode?, message: message, category: category)
                }
            }
        case .success:
            return CFError(code: nil as CFErrorCode?, message: "Cannot convert success to error", category: .unknown)
        }
    }
    
    /// Create result from error
    /// - Parameter error: Error object
    /// - Returns: Error result
    public static func failure(_ error: Error) -> CFResult<Value> {
        if let cfError = error as? CFError {
            return .error(
                message: error.localizedDescription,
                error: error,
                code: cfError.code?.rawValue,
                category: cfError.category
            )
        } else {
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
} 