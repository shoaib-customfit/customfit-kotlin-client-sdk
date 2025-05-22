import Foundation

/// Event type definitions
public enum EventType: String, Codable {
    /// When the app starts
    case appStart = "app_start"
    
    /// When a screen is viewed
    case screenView = "screen_view"
    
    /// When a click or tap occurs
    case click = "click"
    
    /// When a feature flag is evaluated
    case flagEvaluation = "flag_evaluation"
    
    /// When a user performs a custom action
    case customEvent = "custom_event"
    
    /// When a session starts
    case sessionStart = "session_start"
    
    /// When a session ends
    case sessionEnd = "session_end"
    
    /// When an app error occurs
    case error = "error"
    
    /// When a network request completes
    case networkRequest = "network_request"
    
    /// When content is viewed
    case contentView = "content_view"
    
    /// When a user engages with content
    case engagement = "engagement"
    
    /// When a conversion occurs
    case conversion = "conversion"
    
    /// When an impression is recorded
    case impression = "impression"
} 