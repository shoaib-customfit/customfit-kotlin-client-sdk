import Foundation

/// Model for registering a batch of events with user context
public struct RegisterEvent: Codable {
    /// List of events to register
    public let events: [EventData]
    
    /// User context for the events
    public let user: CFUser
    
    public init(events: [EventData], user: CFUser) {
        self.events = events
        self.user = user
    }
} 