import Foundation

/// Network state information
public struct NetworkState {
    /// Connection type (e.g., wifi, cellular)
    public let connectionType: String?
    
    /// Whether offline mode is enabled
    public let isOfflineMode: Bool
    
    /// Last successful connection time in milliseconds since epoch
    public let lastSuccessfulConnectionTimeMs: Int64?
    
    /// Number of consecutive failures
    public let failureCount: Int
    
    /// Time for next reconnection attempt in milliseconds since epoch
    public let nextReconnectTimeMs: Int64?
    
    /// Initialize a new network state
    public init(
        connectionType: String? = nil,
        isOfflineMode: Bool = false,
        lastSuccessfulConnectionTimeMs: Int64? = nil,
        failureCount: Int = 0,
        nextReconnectTimeMs: Int64? = nil
    ) {
        self.connectionType = connectionType
        self.isOfflineMode = isOfflineMode
        self.lastSuccessfulConnectionTimeMs = lastSuccessfulConnectionTimeMs
        self.failureCount = failureCount
        self.nextReconnectTimeMs = nextReconnectTimeMs
    }
}

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
    
    /// Convenience initializer with detailed connection information
    public init(
        status: ConnectionStatus,
        isOfflineMode: Bool = false,
        lastError: String? = nil,
        lastSuccessfulConnectionTimeMs: Int64? = nil,
        failureCount: Int = 0,
        nextReconnectTimeMs: Int64? = nil,
        connectionType: String? = nil
    ) {
        self.status = status
        self.timestamp = Date()
        self.errorMessage = lastError
        self.networkState = NetworkState(
            connectionType: connectionType,
            isOfflineMode: isOfflineMode,
            lastSuccessfulConnectionTimeMs: lastSuccessfulConnectionTimeMs,
            failureCount: failureCount,
            nextReconnectTimeMs: nextReconnectTimeMs
        )
    }
} 