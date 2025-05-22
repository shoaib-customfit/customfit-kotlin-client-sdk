import Foundation

/// Information about a network connection
public struct ConnectionInformation {
    /// Connection status
    public let status: ConnectionStatus
    
    /// Timestamp when the status was last changed
    public let timestamp: Date
    
    /// Error message if applicable
    public let errorMessage: String?
    
    /// Network state if applicable
    public let networkState: NetworkState?
    
    /// Initialize a new connection information
    /// - Parameters:
    ///   - status: Connection status
    ///   - timestamp: Timestamp when the status was last changed
    ///   - errorMessage: Error message if applicable
    ///   - networkState: Network state if applicable
    public init(
        status: ConnectionStatus,
        timestamp: Date = Date(),
        errorMessage: String? = nil,
        networkState: NetworkState? = nil
    ) {
        self.status = status
        self.timestamp = timestamp
        self.errorMessage = errorMessage
        self.networkState = networkState
    }
} 