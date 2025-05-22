import Foundation

/// Event data structure
public struct EventData: Codable {
    /// Unique identifier for the event
    public let eventId: String
    
    /// Type of event
    public let eventType: EventType
    
    /// Timestamp when the event occurred
    public let timestamp: Date
    
    /// User identifier
    public let userId: String?
    
    /// Whether the user is anonymous
    public let isAnonymous: Bool
    
    /// Device context
    public let deviceContext: DeviceContext?
    
    /// Application information
    public let applicationInfo: ApplicationInfo?
    
    /// Event-specific properties
    public let properties: [String: Any]
    
    /// Event metadata
    public let metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case eventId, eventType, timestamp, userId, isAnonymous, deviceContext, applicationInfo
        case properties, metadata
    }
    
    public init(
        eventId: String = UUID().uuidString,
        eventType: EventType,
        timestamp: Date = Date(),
        userId: String?,
        isAnonymous: Bool,
        deviceContext: DeviceContext?,
        applicationInfo: ApplicationInfo?,
        properties: [String: Any],
        metadata: [String: Any]? = nil
    ) {
        self.eventId = eventId
        self.eventType = eventType
        self.timestamp = timestamp
        self.userId = userId
        self.isAnonymous = isAnonymous
        self.deviceContext = deviceContext
        self.applicationInfo = applicationInfo
        self.properties = properties
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        isAnonymous = try container.decode(Bool.self, forKey: .isAnonymous)
        deviceContext = try container.decodeIfPresent(DeviceContext.self, forKey: .deviceContext)
        applicationInfo = try container.decodeIfPresent(ApplicationInfo.self, forKey: .applicationInfo)
        
        let propertiesData = try container.decode(Data.self, forKey: .properties)
        let metadataData = try container.decodeIfPresent(Data.self, forKey: .metadata)
        
        guard let propertiesDict = try JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] else {
            throw DecodingError.dataCorruptedError(forKey: .properties, in: container, debugDescription: "Could not decode properties")
        }
        
        var metadataDict: [String: Any]? = nil
        if let metadataData = metadataData {
            guard let decodedMetadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] else {
                throw DecodingError.dataCorruptedError(forKey: .metadata, in: container, debugDescription: "Could not decode metadata")
            }
            metadataDict = decodedMetadata
        }
        
        self.properties = propertiesDict
        self.metadata = metadataDict
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(isAnonymous, forKey: .isAnonymous)
        try container.encodeIfPresent(deviceContext, forKey: .deviceContext)
        try container.encodeIfPresent(applicationInfo, forKey: .applicationInfo)
        
        let propertiesData = try JSONSerialization.data(withJSONObject: properties)
        try container.encode(propertiesData, forKey: .properties)
        
        if let metadata = metadata {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            try container.encode(metadataData, forKey: .metadata)
        }
    }
} 