import Foundation

/// Represents a user in the CustomFit system
public class CFUser: Codable {
    /// User ID
    public private(set) var userId: String?
    
    /// Device ID
    public private(set) var deviceId: String?
    
    /// Anonymous ID
    public private(set) var anonymousId: String?
    
    /// Custom attributes
    private var attributes: [String: Any] = [:]
    
    /// Device context
    internal var deviceContext: DeviceContext?
    
    /// Application info
    internal var applicationInfo: ApplicationInfo?
    
    /// Initialize a new user
    /// - Parameters:
    ///   - userId: User ID
    ///   - deviceId: Device ID
    ///   - anonymousId: Anonymous ID
    ///   - attributes: Custom attributes
    public init(
        userId: String? = nil,
        deviceId: String? = nil,
        anonymousId: String? = nil,
        attributes: [String: Any] = [:]
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.anonymousId = anonymousId
        self.attributes = attributes
    }
    
    /// Get the user ID
    /// - Returns: User ID
    public func getUserId() -> String? {
        return userId
    }
    
    /// Get the device ID
    /// - Returns: Device ID
    public func getDeviceId() -> String? {
        return deviceId
    }
    
    /// Get the anonymous ID
    /// - Returns: Anonymous ID
    public func getAnonymousId() -> String? {
        return anonymousId
    }
    
    /// Get the user attributes
    /// - Returns: User attributes
    public func getAttributes() -> [String: Any] {
        return attributes
    }
    
    /// Get a specific attribute
    /// - Parameter key: Attribute key
    /// - Returns: Attribute value or nil
    public func getAttribute(key: String) -> Any? {
        return attributes[key]
    }
    
    /// Convert user to dictionary
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let userId = userId {
            result[CFConstants.UserAttributes.USER_ID] = userId
        }
        
        if let deviceId = deviceId {
            result[CFConstants.UserAttributes.DEVICE_ID] = deviceId
        }
        
        if let anonymousId = anonymousId {
            result[CFConstants.UserAttributes.ANONYMOUS_ID] = anonymousId
        }
        
        // Add all custom attributes
        for (key, value) in attributes {
            // Don't overwrite built-in attributes
            if key != CFConstants.UserAttributes.USER_ID &&
               key != CFConstants.UserAttributes.DEVICE_ID &&
               key != CFConstants.UserAttributes.ANONYMOUS_ID {
                result[key] = value
            }
        }
        
        return result
    }
    
    /// Convert user data to a map for API requests
    /// Based on the Kotlin implementation
    public func toUserMap() -> [String: Any] {
        var updatedProperties = attributes
        
        // Add device context if available
        if let deviceContext = deviceContext {
            updatedProperties["device"] = deviceContext.toDictionary()
        }
        
        // Add application info if available
        if let appInfo = applicationInfo {
            updatedProperties["application"] = appInfo.toDictionary()
        }
        
        var result: [String: Any] = [:]
        
        // Add user identification fields
        if let userId = userId {
            result["user_customer_id"] = userId
        }
        
        // Add anonymous status (default to false)
        result["anonymous"] = anonymousId != nil && userId == nil
        
        // Add properties with device and app info 
        result["properties"] = updatedProperties
        
        return result
    }
    
    /// Get evaluation context for feature evaluation
    /// - Returns: Evaluation context
    public func getEvaluationContext() -> EvaluationContext {
        var context = toDictionary()
        
        // Add device context if available
        if let deviceContext = deviceContext {
            let deviceDict = deviceContext.toDictionary()
            for (key, value) in deviceDict {
                context["device_\(key)"] = value
            }
        }
        
        // Add application info if available
        if let appInfo = applicationInfo {
            let appDict = appInfo.toDictionary()
            for (key, value) in appDict {
                context["app_\(key)"] = value
            }
        }
        
        return EvaluationContext(attributes: context)
    }
    
    // MARK: - Builder-like Methods
    
    /// Create a copy with a new user ID
    /// - Parameter userId: New user ID
    /// - Returns: Updated user
    public func withUserId(_ userId: String) -> CFUser {
        let copy = copyUser()
        copy.userId = userId
        return copy
    }
    
    /// Create a copy with a new device ID
    /// - Parameter deviceId: New device ID
    /// - Returns: Updated user
    public func withDeviceId(_ deviceId: String) -> CFUser {
        let copy = copyUser()
        copy.deviceId = deviceId
        return copy
    }
    
    /// Create a copy with a new anonymous ID
    /// - Parameter anonymousId: New anonymous ID
    /// - Returns: Updated user
    public func withAnonymousId(_ anonymousId: String) -> CFUser {
        let copy = copyUser()
        copy.anonymousId = anonymousId
        return copy
    }
    
    /// Create a copy with updated attributes
    /// - Parameter attributes: New attributes
    /// - Returns: Updated user
    public func withAttributes(_ attributes: [String: Any]) -> CFUser {
        let copy = copyUser()
        copy.attributes = attributes
        return copy
    }
    
    /// Create a copy with a new attribute
    /// - Parameters:
    ///   - key: Attribute key
    ///   - value: Attribute value
    /// - Returns: Updated user
    public func withAttribute(key: String, value: Any) -> CFUser {
        let copy = copyUser()
        copy.attributes[key] = value
        return copy
    }
    
    /// Create a copy of this user
    /// - Returns: Copy of user
    private func copyUser() -> CFUser {
        let copy = CFUser(
            userId: userId,
            deviceId: deviceId,
            anonymousId: anonymousId,
            attributes: attributes
        )
        copy.deviceContext = deviceContext
        copy.applicationInfo = applicationInfo
        return copy
    }
    
    /// Create a default user
    /// - Returns: A default user for system operations
    public static func defaultUser() -> CFUser {
        return CFUser(
            userId: nil,
            deviceId: UUID().uuidString,
            anonymousId: UUID().uuidString,
            attributes: [:]
        )
    }
    
    // MARK: - Codable implementation
    
    private enum CodingKeys: String, CodingKey {
        case userId
        case deviceId
        case anonymousId
        case attributes
        case deviceContext
        case applicationInfo
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encodeIfPresent(anonymousId, forKey: .anonymousId)
        try container.encodeIfPresent(deviceContext, forKey: .deviceContext)
        try container.encodeIfPresent(applicationInfo, forKey: .applicationInfo)
        
        // Encode attributes as a Data object
        let attributesData = try JSONSerialization.data(withJSONObject: attributes)
        try container.encode(attributesData, forKey: .attributes)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        anonymousId = try container.decodeIfPresent(String.self, forKey: .anonymousId)
        deviceContext = try container.decodeIfPresent(DeviceContext.self, forKey: .deviceContext)
        applicationInfo = try container.decodeIfPresent(ApplicationInfo.self, forKey: .applicationInfo)
        
        // Decode attributes from Data
        let attributesData = try container.decode(Data.self, forKey: .attributes)
        if let decodedAttributes = try JSONSerialization.jsonObject(with: attributesData) as? [String: Any] {
            attributes = decodedAttributes
        } else {
            attributes = [:]
        }
    }
} 