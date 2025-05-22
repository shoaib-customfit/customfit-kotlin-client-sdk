import Foundation
import Network

/// Protocol for managing network connections
public protocol ConnectionManager {
    /// Check if the client is connected to the network
    /// - Returns: Whether connected to network
    func isConnected() -> Bool
    
    /// Get the current connection status
    /// - Returns: Current connection status
    func getConnectionStatus() -> ConnectionStatus
    
    /// Add connection status listener
    /// - Parameter listener: Listener to add
    func addConnectionStatusListener(listener: ConnectionStatusListener)
    
    /// Remove connection status listener
    /// - Parameter listener: Listener to remove
    func removeConnectionStatusListener(listener: ConnectionStatusListener)
}

/// Connection Manager protocol matching Kotlin implementation
public protocol ConnectionManagerInterface {
    /// Add a connection status listener
    func addConnectionStatusListener(listener: ConnectionStatusListener)
    
    /// Remove a connection status listener
    func removeConnectionStatusListener(listener: ConnectionStatusListener)
    
    /// Get the current connection information
    func getConnectionInformation() -> ConnectionInformation
    
    /// Set offline mode
    func setOfflineMode(offlineMode: Bool)
    
    /// Check if in offline mode
    func getOfflineMode() -> Bool
    
    /// Shutdown the connection manager
    func shutdown()
}

/// Connection management implementation matching Kotlin functionality
public class ConnectionManagerImpl: ConnectionManagerInterface {
    
    // MARK: - Properties
    
    private let config: CFConfig
    private var currentStatus: ConnectionStatus = .disconnected
    private var listeners = [ObjectIdentifier: ConnectionStatusListener]()
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "ai.customfit.networkMonitor", qos: .utility)
    private let workQueue = DispatchQueue(label: "ai.customfit.connection", qos: .utility)
    
    // Connection state
    private var isOfflineMode: Bool = false
    private var failureCount: Int = 0
    private var lastSuccessfulConnection: Int64 = 0
    private var nextReconnectTime: Int64 = 0
    private var lastErrorMessage: String? = nil
    
    // Reconnection settings
    private let baseReconnectDelayMs: Int64 = 1000
    private let maxReconnectDelayMs: Int64 = 30000
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    
    private let reconnectLock = NSLock()
    
    // MARK: - Initialization
    
    public init(config: CFConfig) {
        self.config = config
        self.monitor = NWPathMonitor()
        
        setupNetworkMonitoring()
        startHeartbeat()
    }
    
    deinit {
        shutdown()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Don't change status if in offline mode
            if self.isOfflineMode {
                return
            }
            
            if path.status == .satisfied {
                // Network is available, but we still need to verify server connection
                if self.currentStatus == ConnectionStatus.disconnected {
                    self.updateStatus(ConnectionStatus.connecting)
                    self.initiateReconnect(delayMs: 0)
                }
            } else {
                // Network is unavailable
                self.recordFailure(error: "Network unavailable")
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - ConnectionManagerInterface Implementation
    
    public func addConnectionStatusListener(listener: ConnectionStatusListener) {
        let id = ObjectIdentifier(listener)
        
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.listeners[id] = listener
            
            // Immediately notify the listener of the current state
            let info = self.getConnectionInformation()
            DispatchQueue.main.async(execute: DispatchWorkItem {
                listener.onConnectionStatusChanged(newStatus: self.currentStatus, info: info)
            })
        }
    }
    
    public func removeConnectionStatusListener(listener: ConnectionStatusListener) {
        let id = ObjectIdentifier(listener)
        
        workQueue.async { [weak self] in
            self?.listeners.removeValue(forKey: id)
        }
    }
    
    public func getConnectionInformation() -> ConnectionInformation {
        let connectionType = getConnectionType()
        
        return ConnectionInformation(
            status: currentStatus,
            isOfflineMode: isOfflineMode,
            lastError: lastErrorMessage,
            lastSuccessfulConnectionTimeMs: lastSuccessfulConnection > 0 ? lastSuccessfulConnection : nil,
            failureCount: failureCount,
            nextReconnectTimeMs: nextReconnectTime > 0 ? nextReconnectTime : nil,
            connectionType: connectionType
        )
    }
    
    public func setOfflineMode(offlineMode: Bool) {
        self.isOfflineMode = offlineMode
        
        if offlineMode {
            cancelReconnectTimer()
            updateStatus(ConnectionStatus.offline)
        } else {
            updateStatus(ConnectionStatus.connecting)
            initiateReconnect(delayMs: 0)
        }
        
        Logger.debug("Offline mode set to \(offlineMode)")
    }
    
    public func getOfflineMode() -> Bool {
        return isOfflineMode
    }
    
    public func shutdown() {
        stopHeartbeat()
        monitor.cancel()
        cancelReconnectTimer()
        listeners.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Check if currently connected
    public func isConnected() -> Bool {
        return currentStatus == ConnectionStatus.connected
    }
    
    /// Record a connection success
    public func recordSuccess() {
        failureCount = 0
        lastSuccessfulConnection = Int64(Date().timeIntervalSince1970 * 1000)
        lastErrorMessage = nil
        updateStatus(ConnectionStatus.connected)
    }
    
    /// Record a connection failure
    public func recordFailure(error: String?) {
        failureCount += 1
        lastErrorMessage = error
        
        if !isOfflineMode {
            updateStatus(ConnectionStatus.connecting)
            
            // Calculate exponential backoff with jitter
            let delayMs = calculateBackoffDelay(retryCount: failureCount)
            initiateReconnect(delayMs: delayMs)
        }
    }
    
    /// Check connection by making a lightweight request
    public func checkConnection() {
        if isOfflineMode {
            return
        }
        
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If we were previously connected, set status to connecting during check
            if self.currentStatus == ConnectionStatus.connected {
                self.updateStatus(ConnectionStatus.connecting)
            }
            
            // Trigger reconnect which will attempt to reach the server
            self.initiateReconnect(delayMs: 0)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateStatus(_ newStatus: ConnectionStatus) {
        if currentStatus != newStatus {
            currentStatus = newStatus
            let info = getConnectionInformation()
            
            Logger.info("Connection status changed to: \(newStatus)")
            
            // Notify listeners on main thread
            let listenersCopy = listeners
            DispatchQueue.main.async(execute: DispatchWorkItem {
                for (_, listener) in listenersCopy {
                    listener.onConnectionStatusChanged(newStatus: newStatus, info: info)
                }
            })
        }
    }
    
    private func getConnectionType() -> String? {
        // Capture the current path snapshot
        let path = monitor.currentPath
        
        // Check if any interfaces are available
        if path.usesInterfaceType(.wifi) {
            return "wifi"
        } else if path.usesInterfaceType(.cellular) {
            return "cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "ethernet"
        } else if path.usesInterfaceType(.loopback) {
            return "loopback"
        } else if path.status == .satisfied {
            return "other"
        } else {
            return nil
        }
    }
    
    /// Calculate backoff delay with exponential backoff and jitter
    private func calculateBackoffDelay(retryCount: Int) -> Int64 {
        // Calculate exponential backoff: baseDelay * 2^retryAttempt
        let exponentialDelay = baseReconnectDelayMs * Int64(1 << min(retryCount, 10))
        
        // Cap at maximum delay
        let cappedDelay = min(exponentialDelay, maxReconnectDelayMs)
        
        // Add jitter (±20%)
        let jitterFactor = 0.8 + Double.random(in: 0...0.4)
        
        return Int64(Double(cappedDelay) * jitterFactor)
    }
    
    /// Initiate a reconnection attempt after a delay
    private func initiateReconnect(delayMs: Int64) {
        reconnectLock.lock()
        defer { reconnectLock.unlock() }
        
        cancelReconnectTimer()
        
        if delayMs > 0 {
            nextReconnectTime = Int64(Date().timeIntervalSince1970 * 1000) + delayMs
            Logger.debug("Scheduling reconnect in \(delayMs) ms")
        }
        
        if !isOfflineMode {
            if delayMs > 0 {
                // Use DispatchQueue for the delay instead of Timer for more reliability
                workQueue.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs))) { [weak self] in
                    guard let self = self, !self.isOfflineMode else { return }
                    
                    Logger.debug("Attempting reconnection")
                    self.nextReconnectTime = 0
                    
                    // Try to perform a lightweight networking request to check connectivity
                    self.performConnectivityCheck()
                }
            } else {
                performConnectivityCheck()
            }
        }
    }
    
    private func performConnectivityCheck() {
        // For simplicity, we'll use a basic URL check
        // In a real implementation, this would use a lightweight API endpoint
        
        guard let url = URL(string: "\(CFConstants.Api.BASE_API_URL)/ping") else {
            recordFailure(error: "Invalid ping URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.recordFailure(error: "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.recordFailure(error: "Invalid response")
                return
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                self.recordSuccess()
            } else {
                self.recordFailure(error: "HTTP error: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        nextReconnectTime = 0
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.isOfflineMode && 
               (self.currentStatus == ConnectionStatus.disconnected || 
                Int64(Date().timeIntervalSince1970 * 1000) - self.lastSuccessfulConnection > 60000) {
                self.checkConnection()
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

/// Default implementation of ConnectionManager
public class DefaultConnectionManager: ConnectionManager {
    /// HTTP client
    private let httpClient: HttpClient
    
    /// SDK configuration
    private let config: CFConfig
    
    /// Current connection status
    private var connectionStatus: ConnectionStatus = .failed
    
    /// Connection information
    private var connectionInfo: ConnectionInformation
    
    /// Listeners for connection status changes
    private var listeners = [ConnectionStatusListener]()
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Initialize with HTTP client and config
    /// - Parameters:
    ///   - httpClient: HTTP client
    ///   - config: SDK configuration
    public init(httpClient: HttpClient, config: CFConfig) {
        self.httpClient = httpClient
        self.config = config
        self.connectionInfo = ConnectionInformation(status: ConnectionStatus.failed)
    }
    
    /// Check if connected to network
    /// - Returns: Whether connected
    public func isConnected() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return connectionStatus == ConnectionStatus.connected
    }
    
    /// Get current connection status
    /// - Returns: Connection status
    public func getConnectionStatus() -> ConnectionStatus {
        lock.lock()
        defer { lock.unlock() }
        return connectionStatus
    }
    
    /// Add connection status listener
    /// - Parameter listener: Listener to add
    public func addConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        if !listeners.contains(where: { $0 === listener as AnyObject }) {
            listeners.append(listener)
        }
    }
    
    /// Remove connection status listener
    /// - Parameter listener: Listener to remove
    public func removeConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        listeners.removeAll(where: { $0 === listener as AnyObject })
    }
    
    /// Update connection status
    /// - Parameter status: New status
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        lock.lock()
        
        // Only notify if status changed
        let changed = connectionStatus != status
        connectionStatus = status
        
        // Update connection info
        switch status {
        case .connected:
            connectionInfo = ConnectionInformation(
                status: ConnectionStatus.connected, 
                connectionType: "wifi"
            )
        case .disconnected:
            connectionInfo = ConnectionInformation(
                status: ConnectionStatus.disconnected,
                connectionType: "none"
            )
        default:
            connectionInfo = ConnectionInformation(status: status)
        }
        
        // Copy listeners before unlocking to avoid race conditions
        let listenersCopy = listeners
        
        lock.unlock()
        
        // Only notify if status changed
        if changed {
            // Notify listeners on main thread
            DispatchQueue.main.async(execute: DispatchWorkItem {
                for listener in listenersCopy {
                    listener.onConnectionStatusChanged(newStatus: status, info: self.connectionInfo)
                }
            })
        }
    }
} 