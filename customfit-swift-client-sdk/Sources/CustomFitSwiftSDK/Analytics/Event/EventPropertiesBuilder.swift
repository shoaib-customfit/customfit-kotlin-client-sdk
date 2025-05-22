import Foundation

/// Builder for event properties
public class EventPropertiesBuilder {
    private var properties: [String: Any] = [:]
    
    public init() {}
    
    /// Add a string property
    @discardableResult
    public func with(key: String, value: String?) -> EventPropertiesBuilder {
        if let value = value {
            properties[key] = value
        }
        return self
    }
    
    /// Add a boolean property
    @discardableResult
    public func with(key: String, value: Bool?) -> EventPropertiesBuilder {
        if let value = value {
            properties[key] = value
        }
        return self
    }
    
    /// Add an integer property
    @discardableResult
    public func with(key: String, value: Int?) -> EventPropertiesBuilder {
        if let value = value {
            properties[key] = value
        }
        return self
    }
    
    /// Add a double property
    @discardableResult
    public func with(key: String, value: Double?) -> EventPropertiesBuilder {
        if let value = value {
            properties[key] = value
        }
        return self
    }
    
    /// Add a date property
    @discardableResult
    public func with(key: String, value: Date?) -> EventPropertiesBuilder {
        if let value = value {
            // Format date to ISO 8601 string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            properties[key] = formatter.string(from: value)
        }
        return self
    }
    
    /// Add properties from dictionary
    @discardableResult
    public func with(properties: [String: Any]) -> EventPropertiesBuilder {
        self.properties.merge(properties) { (_, new) in new }
        return self
    }
    
    /// Add a dictionary property
    @discardableResult
    public func with(key: String, dictionary: [String: Any]?) -> EventPropertiesBuilder {
        if let dictionary = dictionary {
            properties[key] = dictionary
        }
        return self
    }
    
    /// Add an array property
    @discardableResult
    public func with(key: String, array: [Any]?) -> EventPropertiesBuilder {
        if let array = array {
            properties[key] = array
        }
        return self
    }
    
    /// Build the properties dictionary
    public func build() -> [String: Any] {
        return properties
    }
} 