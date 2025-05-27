import Foundation

/// Event data model for tracking user activities
public class EventData: Codable {
    
    // MARK: - Properties
    
    /// Unique event ID
    public var eventId: String
    
    /// Event name
    public var name: String
    
    /// Event type
    public var eventType: EventType
    
    /// Timestamp when the event occurred
    public var timestamp: Date
    
    /// Session ID to group events
    public var sessionId: String
    
    /// User ID for the event
    public var userId: String?
    
    /// Whether the user is anonymous
    public var isAnonymous: Bool
    
    /// Device context information
    public var deviceContext: DeviceContext?
    
    /// Application information
    public var applicationInfo: ApplicationInfo?
    
    /// Event properties
    public var properties: [String: Any]
    
    // MARK: - Coding Keys
    
    private enum CodingKeys: String, CodingKey {
        case eventId
        case name
        case eventType
        case timestamp
        case sessionId
        case userId
        case isAnonymous
        case deviceContext
        case applicationInfo
        case properties
    }
    
    // MARK: - Initialization
    
    /// Initialize with all required fields
    /// - Parameters:
    ///   - eventId: Unique event ID
    ///   - name: Event name
    ///   - eventType: Event type
    ///   - timestamp: Timestamp when the event occurred
    ///   - sessionId: Session ID to group events
    ///   - userId: User ID for the event
    ///   - isAnonymous: Whether the user is anonymous
    ///   - deviceContext: Device context information
    ///   - applicationInfo: Application information
    ///   - properties: Event properties
    public init(
        eventId: String,
        name: String,
        eventType: EventType,
        timestamp: Date,
        sessionId: String,
        userId: String? = nil,
        isAnonymous: Bool = true,
        deviceContext: DeviceContext? = nil,
        applicationInfo: ApplicationInfo? = nil,
        properties: [String: Any] = [:]
    ) {
        self.eventId = eventId
        self.name = name
        self.eventType = eventType
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.isAnonymous = isAnonymous
        self.deviceContext = deviceContext
        self.applicationInfo = applicationInfo
        self.properties = properties
    }
    
    // MARK: - Decodable
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        eventId = try container.decode(String.self, forKey: .eventId)
        name = try container.decode(String.self, forKey: .name)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        isAnonymous = try container.decode(Bool.self, forKey: .isAnonymous)
        
        // Handle the complex types with optional decoding
        if let deviceContextData = try container.decodeIfPresent(Data.self, forKey: .deviceContext) {
            deviceContext = try JSONDecoder().decode(DeviceContext.self, from: deviceContextData)
        }
        
        if let appInfoData = try container.decodeIfPresent(Data.self, forKey: .applicationInfo) {
            applicationInfo = try JSONDecoder().decode(ApplicationInfo.self, from: appInfoData)
        }
        
        let propertiesData = try container.decode(Data.self, forKey: .properties)
        if let propertiesDict = try JSONSerialization.jsonObject(with: propertiesData, options: []) as? [String: Any] {
            properties = propertiesDict
        } else {
            properties = [:]
        }
    }
    
    // MARK: - Encodable
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(eventId, forKey: .eventId)
        try container.encode(name, forKey: .name)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(isAnonymous, forKey: .isAnonymous)
        
        // Handle complex types by serializing to Data
        if let deviceContext = deviceContext {
            let deviceContextData = try JSONEncoder().encode(deviceContext)
            try container.encode(deviceContextData, forKey: .deviceContext)
        }
        
        if let applicationInfo = applicationInfo {
            let appInfoData = try JSONEncoder().encode(applicationInfo)
            try container.encode(appInfoData, forKey: .applicationInfo)
        }
        
        let propertiesData = try JSONSerialization.data(withJSONObject: properties)
        try container.encode(propertiesData, forKey: .properties)
    }
    
    // MARK: - Serialization
    
    /// Convert to dictionary for serialization (Kotlin-compatible format)
    /// - Returns: Dictionary representation of the event
    public func toDictionary() -> [String: Any] {
        // Create timestamp formatter matching Kotlin's format
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSX"
        timestampFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        var dict: [String: Any] = [
            "event_customer_id": name,  // Kotlin uses event_customer_id
            "event_type": eventType.rawValue,
            "event_timestamp": timestampFormatter.string(from: timestamp),  // Kotlin format
            "session_id": sessionId,
            "insert_id": eventId  // Kotlin uses insert_id
        ]
        
        // Add properties
        dict["properties"] = properties
        
        return dict
    }
    
    /// Create from dictionary representation
    /// - Parameter dict: Dictionary to create from
    /// - Returns: EventData instance or nil if conversion fails
    public static func fromDictionary(_ dict: [String: Any]) -> EventData? {
        guard
            let eventId = dict["event_id"] as? String,
            let name = dict["name"] as? String,
            let eventTypeStr = dict["event_type"] as? String,
            let eventType = EventType(rawValue: eventTypeStr),
            let timestampMs = dict["timestamp"] as? Int64,
            let sessionId = dict["session_id"] as? String,
            let isAnonymous = dict["is_anonymous"] as? Bool
        else {
            return nil
        }
        
        // Convert timestamp
        let timestamp = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        
        // Extract optional fields
        let userId = dict["user_id"] as? String
        
        // Create device context if available
        let deviceContextDict = dict["device_context"] as? [String: Any]
        let deviceContext = deviceContextDict.flatMap(DeviceContext.fromDictionary)
        
        // Create application info if available
        let appInfoDict = dict["application_info"] as? [String: Any]
        let applicationInfo = appInfoDict.flatMap(ApplicationInfo.fromDictionary)
        
        // Extract properties
        let properties = dict["properties"] as? [String: Any] ?? [:]
        
        return EventData(
            eventId: eventId,
            name: name,
            eventType: eventType,
            timestamp: timestamp,
            sessionId: sessionId,
            userId: userId,
            isAnonymous: isAnonymous,
            deviceContext: deviceContext,
            applicationInfo: applicationInfo,
            properties: properties
        )
    }
} 