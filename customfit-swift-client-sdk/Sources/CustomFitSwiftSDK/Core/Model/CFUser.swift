import Foundation

/// Represents a user in the CustomFit system
public class CFUser: Codable {
    /// User ID (matches user_customer_id in Kotlin)
    public private(set) var user_customer_id: String?
    
    /// Device ID
    public private(set) var deviceId: String?
    
    /// Anonymous ID
    public private(set) var anonymousId: String?
    
    /// Whether the user is anonymous
    public private(set) var anonymous: Bool = false
    
    /// Custom attributes (properties in Kotlin)
    private var properties: [String: Any] = [:]
    
    /// Device context
    internal var device: DeviceContext?
    
    /// Application info
    internal var application: ApplicationInfo?
    
    /// Contexts for evaluation
    private var contexts: [EvaluationContext] = []
    
    /// Initialize a new user
    /// - Parameters:
    ///   - user_customer_id: User ID
    ///   - deviceId: Device ID
    ///   - anonymousId: Anonymous ID
    ///   - anonymous: Whether the user is anonymous
    ///   - properties: Custom properties
    public init(
        user_customer_id: String? = nil,
        deviceId: String? = nil,
        anonymousId: String? = nil,
        anonymous: Bool = false,
        properties: [String: Any] = [:]
    ) {
        self.user_customer_id = user_customer_id
        self.deviceId = deviceId
        self.anonymousId = anonymousId
        self.anonymous = anonymous
        self.properties = properties
    }
    
    /// Get the user ID
    /// - Returns: User ID
    public func getUserId() -> String? {
        return user_customer_id
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
    
    /// Get the user properties (matches getCurrentProperties in Kotlin)
    /// - Returns: User properties
    public func getCurrentProperties() -> [String: Any] {
        return properties
    }
    
    /// Get a specific property
    /// - Parameter key: Property key
    /// - Returns: Property value or nil
    public func getProperty(key: String) -> Any? {
        return properties[key]
    }
    
    /// Get the device context
    /// - Returns: Device context
    public func getDeviceContext() -> DeviceContext? {
        return device
    }
    
    /// Get the application info
    /// - Returns: Application info
    public func getApplicationInfo() -> ApplicationInfo? {
        return application
    }
    
    /// Get all contexts
    /// - Returns: All contexts
    public func getAllContexts() -> [EvaluationContext] {
        return contexts
    }
    
    /// Convert user to dictionary
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let userId = user_customer_id {
            result[CFConstants.UserAttributes.USER_ID] = userId
        }
        
        if let deviceId = deviceId {
            result[CFConstants.UserAttributes.DEVICE_ID] = deviceId
        }
        
        if let anonymousId = anonymousId {
            result[CFConstants.UserAttributes.ANONYMOUS_ID] = anonymousId
        }
        
        result["anonymous"] = anonymous
        
        // Add all custom properties
        for (key, value) in properties {
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
        var updatedProperties = properties
        
        // Inject contexts if available
        if !contexts.isEmpty {
            updatedProperties["contexts"] = contexts.map { $0.toDictionary() }
        }
        
        // Add device context if available
        if let deviceContext = device {
            updatedProperties["device"] = deviceContext.toDictionary()
        }
        
        // Add application info if available
        if let appInfo = application {
            updatedProperties["application"] = appInfo.toDictionary()
        }
        
        var result: [String: Any] = [:]
        
        // Add user identification fields
        if let userId = user_customer_id {
            result["user_customer_id"] = userId
        }
        
        // Add anonymous status
        result["anonymous"] = anonymous
        
        // Add properties with device and app info 
        result["properties"] = updatedProperties
        
        // Filter nil values
        return result.filter { $0.value is Any }
    }
    
    /// Set the device context
    /// - Parameter deviceContext: Device context
    /// - Returns: Updated user
    public func setDeviceContext(_ deviceContext: DeviceContext) -> CFUser {
        let copy = copyUser()
        copy.device = deviceContext
        return copy
    }
    
    /// Set the application info
    /// - Parameter appInfo: Application info
    /// - Returns: Updated user
    public func setApplicationInfo(_ appInfo: ApplicationInfo) -> CFUser {
        let copy = copyUser()
        copy.application = appInfo
        return copy
    }
    
    /// Add a context
    /// - Parameter context: Context to add
    /// - Returns: Updated user
    public func addContext(_ context: EvaluationContext) -> CFUser {
        let copy = copyUser()
        var updatedContexts = copy.contexts
        updatedContexts.append(context)
        copy.contexts = updatedContexts
        return copy
    }
    
    /// Add a property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    /// - Returns: Updated user
    public func addProperty(key: String, value: Any) -> CFUser {
        let copy = copyUser()
        var updatedProperties = copy.properties
        updatedProperties[key] = value
        copy.properties = updatedProperties
        return copy
    }
    
    /// Add multiple properties
    /// - Parameter newProperties: Properties to add
    /// - Returns: Updated user
    public func addProperties(_ newProperties: [String: Any]) -> CFUser {
        let copy = copyUser()
        var updatedProperties = copy.properties
        for (key, value) in newProperties {
            updatedProperties[key] = value
        }
        copy.properties = updatedProperties
        return copy
    }
    
    // MARK: - Builder-like Methods
    
    /// Create a copy with a new user ID
    /// - Parameter userId: New user ID
    /// - Returns: Updated user
    public func withUserId(_ userId: String) -> CFUser {
        let copy = copyUser()
        copy.user_customer_id = userId
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
    
    /// Make the user anonymous
    /// - Parameter anonymous: Whether the user is anonymous
    /// - Returns: Updated user
    public func makeAnonymous(_ anonymous: Bool) -> CFUser {
        let copy = copyUser()
        copy.anonymous = anonymous
        return copy
    }
    
    /// Create a copy with updated properties
    /// - Parameter properties: New properties
    /// - Returns: Updated user
    public func withProperties(_ properties: [String: Any]) -> CFUser {
        let copy = copyUser()
        copy.properties = properties
        return copy
    }
    
    /// Create a copy with a new property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    /// - Returns: Updated user
    public func withAttribute(key: String, value: Any) -> CFUser {
        let copy = copyUser()
        copy.properties[key] = value
        return copy
    }
    
    /// Create a copy with a specific number property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Number value
    /// - Returns: Updated user
    public func withNumberProperty(key: String, value: NSNumber) -> CFUser {
        return withAttribute(key: key, value: value)
    }
    
    /// Create a copy with a specific string property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: String value
    /// - Returns: Updated user
    public func withStringProperty(key: String, value: String) -> CFUser {
        return withAttribute(key: key, value: value)
    }
    
    /// Create a copy with a specific boolean property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Boolean value
    /// - Returns: Updated user
    public func withBooleanProperty(key: String, value: Bool) -> CFUser {
        return withAttribute(key: key, value: value)
    }
    
    /// Create a copy with a specific date property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Date value
    /// - Returns: Updated user
    public func withDateProperty(key: String, value: Date) -> CFUser {
        return withAttribute(key: key, value: value)
    }
    
    /// Create a copy with a specific geo point property
    /// - Parameters:
    ///   - key: Property key
    ///   - lat: Latitude
    ///   - lon: Longitude
    /// - Returns: Updated user
    public func withGeoPointProperty(key: String, lat: Double, lon: Double) -> CFUser {
        return withAttribute(key: key, value: ["lat": lat, "lon": lon])
    }
    
    /// Create a copy with a specific JSON property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: JSON value
    /// - Returns: Updated user
    public func withJsonProperty(key: String, value: [String: Any]) -> CFUser {
        return withAttribute(key: key, value: value)
    }
    
    /// Create a copy of this user
    /// - Returns: Copy of user
    private func copyUser() -> CFUser {
        let copy = CFUser(
            user_customer_id: user_customer_id,
            deviceId: deviceId,
            anonymousId: anonymousId,
            anonymous: anonymous,
            properties: properties
        )
        copy.device = device
        copy.application = application
        copy.contexts = contexts
        return copy
    }
    
    /// Create a default user
    /// - Returns: A default user for system operations
    public static func defaultUser() -> CFUser {
        return CFUser(
            user_customer_id: nil,
            deviceId: UUID().uuidString,
            anonymousId: UUID().uuidString,
            anonymous: true,
            properties: [:]
        )
    }
    
    /// Create a builder with a user ID
    /// - Parameter userId: User ID
    /// - Returns: Builder
    public static func builder(user_customer_id: String) -> Builder {
        return Builder(user_customer_id: user_customer_id)
    }
    
    // MARK: - Builder
    
    /// Builder for constructing a CFUser with fluent API
    public class Builder {
        private let user_customer_id: String
        private var anonymous: Bool = false
        private var deviceId: String? = nil
        private var anonymousId: String? = nil
        private var properties: [String: Any] = [:]
        private var contexts: [EvaluationContext] = []
        private var device: DeviceContext? = nil
        private var application: ApplicationInfo? = nil
        
        /// Initialize with a user ID
        /// - Parameter user_customer_id: User ID
        public init(user_customer_id: String) {
            self.user_customer_id = user_customer_id
        }
        
        /// Make the user anonymous
        /// - Parameter anonymous: Whether the user is anonymous
        /// - Returns: Builder
        public func makeAnonymous(_ anonymous: Bool) -> Builder {
            self.anonymous = anonymous
            return self
        }
        
        /// Set a device ID
        /// - Parameter deviceId: Device ID
        /// - Returns: Builder
        public func withDeviceId(_ deviceId: String) -> Builder {
            self.deviceId = deviceId
            return self
        }
        
        /// Set an anonymous ID
        /// - Parameter anonymousId: Anonymous ID
        /// - Returns: Builder
        public func withAnonymousId(_ anonymousId: String) -> Builder {
            self.anonymousId = anonymousId
            return self
        }
        
        /// Set properties
        /// - Parameter properties: Properties
        /// - Returns: Builder
        public func withProperties(_ properties: [String: Any]) -> Builder {
            self.properties = properties
            return self
        }
        
        /// Set a specific number property
        /// - Parameters:
        ///   - key: Property key
        ///   - value: Number value
        /// - Returns: Builder
        public func withNumberProperty(key: String, value: NSNumber) -> Builder {
            properties[key] = value
            return self
        }
        
        /// Set a specific string property
        /// - Parameters:
        ///   - key: Property key
        ///   - value: String value
        /// - Returns: Builder
        public func withStringProperty(key: String, value: String) -> Builder {
            properties[key] = value
            return self
        }
        
        /// Set a specific boolean property
        /// - Parameters:
        ///   - key: Property key
        ///   - value: Boolean value
        /// - Returns: Builder
        public func withBooleanProperty(key: String, value: Bool) -> Builder {
            properties[key] = value
            return self
        }
        
        /// Set a specific date property
        /// - Parameters:
        ///   - key: Property key
        ///   - value: Date value
        /// - Returns: Builder
        public func withDateProperty(key: String, value: Date) -> Builder {
            properties[key] = value
            return self
        }
        
        /// Set a specific geo point property
        /// - Parameters:
        ///   - key: Property key
        ///   - lat: Latitude
        ///   - lon: Longitude
        /// - Returns: Builder
        public func withGeoPointProperty(key: String, lat: Double, lon: Double) -> Builder {
            properties[key] = ["lat": lat, "lon": lon]
            return self
        }
        
        /// Set a specific JSON property
        /// - Parameters:
        ///   - key: Property key
        ///   - value: JSON value
        /// - Returns: Builder
        public func withJsonProperty(key: String, value: [String: Any]) -> Builder {
            properties[key] = value
            return self
        }
        
        /// Set a context
        /// - Parameter context: Context
        /// - Returns: Builder
        public func withContext(_ context: EvaluationContext) -> Builder {
            contexts.append(context)
            return self
        }
        
        /// Set a device context
        /// - Parameter device: Device context
        /// - Returns: Builder
        public func withDeviceContext(_ device: DeviceContext) -> Builder {
            self.device = device
            return self
        }
        
        /// Set an application info
        /// - Parameter application: Application info
        /// - Returns: Builder
        public func withApplicationInfo(_ application: ApplicationInfo) -> Builder {
            self.application = application
            return self
        }
        
        /// Build the user
        /// - Returns: Built user
        public func build() -> CFUser {
            let user = CFUser(
                user_customer_id: user_customer_id,
                deviceId: deviceId,
                anonymousId: anonymousId,
                anonymous: anonymous,
                properties: properties
            )
            
            user.device = device
            user.application = application
            user.contexts = contexts
            
            return user
        }
    }
    
    // MARK: - Codable implementation
    
    private enum CodingKeys: String, CodingKey {
        case user_customer_id
        case deviceId
        case anonymousId
        case anonymous
        case properties
        case device
        case application
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(user_customer_id, forKey: .user_customer_id)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encodeIfPresent(anonymousId, forKey: .anonymousId)
        try container.encode(anonymous, forKey: .anonymous)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(application, forKey: .application)
        
        // Encode properties as a Data object
        let propertiesData = try JSONSerialization.data(withJSONObject: properties)
        try container.encode(propertiesData, forKey: .properties)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        user_customer_id = try container.decodeIfPresent(String.self, forKey: .user_customer_id)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        anonymousId = try container.decodeIfPresent(String.self, forKey: .anonymousId)
        anonymous = try container.decode(Bool.self, forKey: .anonymous)
        device = try container.decodeIfPresent(DeviceContext.self, forKey: .device)
        application = try container.decodeIfPresent(ApplicationInfo.self, forKey: .application)
        contexts = [] // Initialize to empty array, contexts aren't part of Codable
        
        // Decode properties from Data
        let propertiesData = try container.decode(Data.self, forKey: .properties)
        if let decodedProperties = try JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] {
            properties = decodedProperties
        } else {
            properties = [:]
        }
    }
}

// MARK: - Helper Extensions

extension Dictionary {
    /// Filter values that are not nil
    /// Equivalent to Kotlin's filterValues { it != null }
    fileprivate func filterValues(isIncluded: (Value) -> Bool) -> [Key: Value] {
        return self.filter { isIncluded($0.value) }
    }
} 