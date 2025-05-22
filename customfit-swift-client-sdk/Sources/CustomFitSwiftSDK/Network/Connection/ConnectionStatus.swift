import Foundation

/// Connection status for network connections
public enum ConnectionStatus {
    /// Connected to the server
    case connected
    
    /// Connecting to the server
    case connecting
    
    /// Disconnected from the server
    case disconnected
    
    /// Failed to connect to the server
    case failed
    
    /// Offline mode active
    case offline
} 