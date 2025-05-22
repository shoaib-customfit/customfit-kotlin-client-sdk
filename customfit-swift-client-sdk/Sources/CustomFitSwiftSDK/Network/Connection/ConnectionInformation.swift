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

/// Information about a network connection, mirroring Kotlin's ConnectionInformation
public struct ConnectionInformation {
    /// Connection status
    public let status: ConnectionStatus

    /// When true, indicates the SDK was put in offline mode intentionally.
    public let isOfflineMode: Bool

    /// Last connection error message, if any.
    public let lastError: String?

    /// Timestamp of the last successful connection in milliseconds.
    public let lastSuccessfulConnectionTimeMs: Int64? // Kotlin has non-optional Long, default 0

    /// Number of consecutive connection failures.
    public let failureCount: Int

    /// Time of the next reconnection attempt in milliseconds.
    public let nextReconnectTimeMs: Int64? // Kotlin has non-optional Long, default 0

    /// Initialize a new connection information
    public init(
        status: ConnectionStatus,
        isOfflineMode: Bool = false,
        lastError: String? = nil,
        lastSuccessfulConnectionTimeMs: Int64? = nil, // Default to nil to match optional type
        failureCount: Int = 0,
        nextReconnectTimeMs: Int64? = nil // Default to nil to match optional type
    ) {
        self.status = status
        self.isOfflineMode = isOfflineMode
        self.lastError = lastError
        self.lastSuccessfulConnectionTimeMs = lastSuccessfulConnectionTimeMs
        self.failureCount = failureCount
        self.nextReconnectTimeMs = nextReconnectTimeMs
    }
} 