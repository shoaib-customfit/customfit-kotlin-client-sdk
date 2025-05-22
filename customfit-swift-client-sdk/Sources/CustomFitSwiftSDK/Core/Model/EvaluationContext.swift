import Foundation

/// Context for feature evaluation with all necessary user and environment attributes
public struct EvaluationContext {
    /// User and environment attributes
    public let attributes: [String: Any]
    
    /// Initialize a new evaluation context
    /// - Parameter attributes: Attributes for evaluation context
    public init(attributes: [String: Any]) {
        self.attributes = attributes
    }
    
    /// Convert to dictionary
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        return attributes
    }
} 