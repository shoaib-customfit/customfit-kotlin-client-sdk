import Foundation

// This file imports the ConnectionStatusListener protocol from ListenerManager
// to avoid duplication and ambiguity.
@_exported import struct Foundation.URL
@_exported import protocol CustomFitSwiftSDK.ConnectionStatusListener

/// Connection status listener protocol matching Kotlin implementation
public protocol ConnectionStatusListener: AnyObject {
    /**
     * Called when the connection status changes.
     *
     * @param newStatus The new connection status
     * @param info Detailed connection information
     */
    func onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation)
} 