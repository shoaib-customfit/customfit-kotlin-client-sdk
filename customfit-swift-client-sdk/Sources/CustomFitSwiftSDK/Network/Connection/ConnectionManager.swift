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
    
    /// Record a connection success
    func recordSuccess()
    
    /// Record a connection failure
    func recordFailure(error: String?)
    
    /// Check connection by making a lightweight request
    func checkConnection()
}

/// Connection management implementation matching Kotlin functionality
public class ConnectionManagerImpl: ConnectionManagerInterface {
    
    // MARK: - Properties
    
    private let config: CFConfig
    private var currentStatus: ConnectionStatus = .disconnected
    private var listeners = [ObjectIdentifier: ConnectionStatusListener]()
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
    
    private let stateLock = NSLock()
    private let listenersLock = NSLock()
    private let reconnectLock = NSLock()
    
    // MARK: - Initialization
    
    public init(config: CFConfig) {
        self.config = config
        
        if !isOfflineMode {
            updateStatus(.connecting)
        }
        startHeartbeat()
        Logger.debug("ConnectionManagerImpl initialized. Initial status: \(currentStatus)")
    }
    
    deinit {
        shutdown()
    }
    
    // MARK: - ConnectionManagerInterface Implementation
    
    public func addConnectionStatusListener(listener: ConnectionStatusListener) {
        let id = ObjectIdentifier(listener)
        
        listenersLock.lock()
        self.listeners[id] = listener
        listenersLock.unlock()
        
        // Immediately notify the listener of the current state
        let info = self.getConnectionInformation()
        DispatchQueue.main.async {
            listener.onConnectionStatusChanged(newStatus: self.currentStatus, info: info)
        }
        Logger.debug("Added connection listener. Current listener count: \(listeners.count)")
    }
    
    public func removeConnectionStatusListener(listener: ConnectionStatusListener) {
        let id = ObjectIdentifier(listener)
        
        listenersLock.lock()
        self.listeners.removeValue(forKey: id)
        listenersLock.unlock()
        Logger.debug("Removed connection listener. Current listener count: \(listeners.count)")
    }
    
    public func getConnectionInformation() -> ConnectionInformation {
        stateLock.lock()
        let currentStatusCopy = currentStatus
        let isOfflineModeCopy = isOfflineMode
        let lastErrorMessageCopy = lastErrorMessage
        let lastSuccessfulConnectionCopy = lastSuccessfulConnection
        let failureCountCopy = failureCount
        let nextReconnectTimeCopy = nextReconnectTime
        stateLock.unlock()

        return ConnectionInformation(
            status: currentStatusCopy,
            isOfflineMode: isOfflineModeCopy,
            lastError: lastErrorMessageCopy,
            lastSuccessfulConnectionTimeMs: lastSuccessfulConnectionCopy > 0 ? lastSuccessfulConnectionCopy : nil,
            failureCount: failureCountCopy,
            nextReconnectTimeMs: nextReconnectTimeCopy > 0 ? nextReconnectTimeCopy : nil
        )
    }
    
    public func setOfflineMode(offlineMode: Bool) {
        stateLock.lock()
        self.isOfflineMode = offlineMode
        let oldStatus = self.currentStatus
        stateLock.unlock()

        if offlineMode {
            cancelReconnectTimer()
            if oldStatus != .offline {
                updateStatus(.offline)
            }
        } else {
            if oldStatus == .offline || oldStatus == .disconnected {
                updateStatus(.connecting)
                initiateReconnect(delayMs: 0)
            }
        }
        Logger.info("Offline mode set to \(offlineMode). Status is now \(currentStatus)")
    }
    
    public func getOfflineMode() -> Bool {
        stateLock.lock()
        let offline = isOfflineMode
        stateLock.unlock()
        return offline
    }
    
    public func shutdown() {
        Logger.debug("ConnectionManager shutting down...")
        stopHeartbeat()
        cancelReconnectTimer()
        
        listenersLock.lock()
        listeners.removeAll()
        listenersLock.unlock()
        Logger.debug("ConnectionManager shutdown complete.")
    }
    
    // MARK: - Public Methods (exposed via ConnectionManagerInterface)
    
    /// Check if currently connected
    public func isConnected() -> Bool {
        return currentStatus == ConnectionStatus.connected
    }
    
    /// Record a connection success
    public func recordSuccess() {
        Logger.debug("Connection success recorded.")
        stateLock.lock()
        failureCount = 0
        lastSuccessfulConnection = Int64(Date().timeIntervalSince1970 * 1000)
        lastErrorMessage = nil
        let oldStatus = currentStatus
        stateLock.unlock()

        if oldStatus != .connected {
            updateStatus(.connected)
        }
        cancelReconnectTimer()
    }
    
    /// Record a connection failure
    public func recordFailure(error: String?) {
        stateLock.lock()
        failureCount += 1
        lastErrorMessage = error
        let currentOfflineMode = isOfflineMode
        let oldStatus = currentStatus
        let currentFailureCount = failureCount
        stateLock.unlock()
        
        Logger.warning("Connection failure recorded. Error: \(error ?? "Unknown"). Attempt: \(currentFailureCount)")

        if !currentOfflineMode {
            if oldStatus != .connecting {
                updateStatus(.connecting)
            }
            let delayMs = calculateBackoffDelay(retryCount: currentFailureCount)
            initiateReconnect(delayMs: delayMs)
        }
    }
    
    /// Check connection by making a lightweight request (simulated by onReconnect in Kotlin)
    /// In Swift, this would typically trigger the onReconnect callback provided by the client.
    /// For now, it just ensures we try to reconnect if disconnected.
    public func checkConnection() {
        stateLock.lock()
        let currentOfflineMode = isOfflineMode
        let status = currentStatus
        stateLock.unlock()

        Logger.debug("checkConnection called. Offline: \(currentOfflineMode), Status: \(status)")

        if currentOfflineMode {
            Logger.debug("In offline mode, checkConnection is a no-op.")
            return
        }
        
        if status == .connected {
            updateStatus(.connecting)
        }
        initiateReconnect(delayMs: 0)
    }
    
    /// Callback for actual reconnection logic, to be set by the CFClient
    /// This mirrors the 'onReconnect: () -> Unit' in Kotlin's ConnectionManager
    /// CFClient will be responsible for setting this to perform an actual config poll or ping
    public var onReconnect: (() -> Void)?
    
    // MARK: - Private Methods
    
    private func updateStatus(_ newStatus: ConnectionStatus) {
        stateLock.lock()
        let oldStatus = currentStatus
        if oldStatus == newStatus {
            stateLock.unlock()
            return
        }
        currentStatus = newStatus
        stateLock.unlock()

        Logger.info("Connection status changed from \(oldStatus) to: \(newStatus)")
        let info = getConnectionInformation()

        listenersLock.lock()
        let listenersCopy = listeners
        listenersLock.unlock()

        DispatchQueue.main.async {
            for (_, listener) in listenersCopy {
                listener.onConnectionStatusChanged(newStatus: newStatus, info: info)
            }
        }
    }
    
    /// Calculate backoff delay with exponential backoff and jitter
    private func calculateBackoffDelay(retryCount: Int) -> Int64 {
        let exponentialDelay = baseReconnectDelayMs * (1 << min(retryCount, 10))
        let cappedDelay = min(exponentialDelay, maxReconnectDelayMs)
        let jitterFactor = 0.8 + Double.random(in: 0.0...0.4)
        let finalDelay = Int64(Double(cappedDelay) * jitterFactor)
        Logger.debug("Calculated backoff delay: \(finalDelay)ms for retry count \(retryCount)")
        return finalDelay
    }
    
    /// Initiate a reconnection attempt after a delay
    private func initiateReconnect(delayMs: Int64) {
        reconnectLock.lock()
        defer { reconnectLock.unlock() }

        cancelReconnectTimerInternal()

        stateLock.lock()
        let currentOfflineMode = isOfflineMode
        stateLock.unlock()

        if currentOfflineMode {
            Logger.debug("Attempted to initiate reconnect while in offline mode. Aborting.")
            return
        }
        
        let reconnectTime = Date().addingTimeInterval(TimeInterval(delayMs) / 1000.0)
        
        stateLock.lock()
        nextReconnectTime = Int64(reconnectTime.timeIntervalSince1970 * 1000)
        stateLock.unlock()

        if delayMs > 0 {
            Logger.debug("Scheduling reconnect in \(delayMs) ms. Next attempt at: \(reconnectTime)")
        } else {
            Logger.debug("Initiating immediate reconnect attempt.")
        }
        
        DispatchQueue.main.async {
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(delayMs) / 1000.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                self.stateLock.lock()
                let stillOffline = self.isOfflineMode
                self.nextReconnectTime = 0
                self.stateLock.unlock()

                if !stillOffline {
                    Logger.info("Attempting reconnection now...")
                    self.onReconnect?()
                } else {
                    Logger.debug("Reconnect timer fired, but now in offline mode. Aborting reconnect.")
                }
                self.reconnectLock.lock()
                self.reconnectTimer = nil
                self.reconnectLock.unlock()
            }
        }
    }

    /// Cancel any pending reconnection job (internal, doesn't lock)
    private func cancelReconnectTimerInternal() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        stateLock.lock()
        nextReconnectTime = 0
        stateLock.unlock()
    }
    
    /// Cancel any pending reconnection job (public facing, locks)
    private func cancelReconnectTimer() {
        reconnectLock.lock()
        defer { reconnectLock.unlock() }
        cancelReconnectTimerInternal()
        Logger.debug("Cancelled pending reconnect timer.")
    }
    
    /// Start heartbeat timer to check connection periodically
    private func startHeartbeat() {
        stopHeartbeat()
        Logger.debug("Starting connection heartbeat timer.")
        DispatchQueue.main.async {
            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                self.stateLock.lock()
                let currentOffline = self.isOfflineMode
                let status = self.currentStatus
                let lastConnTime = self.lastSuccessfulConnection
                self.stateLock.unlock()

                if !currentOffline {
                    let idleTimeMs = Int64(Date().timeIntervalSince1970 * 1000) - lastConnTime
                    if status == .disconnected || (status != .connecting && idleTimeMs > 60000) {
                        Logger.debug("Heartbeat: Connection check triggered. Status: \(status), Idle time: \(idleTimeMs)ms")
                        self.checkConnection()
                    }
                }
            }
        }
    }
    
    /// Stop heartbeat timer
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        Logger.debug("Stopped connection heartbeat timer.")
    }
}

/// Default implementation of ConnectionManager
public class DefaultConnectionManager: ConnectionManager, ConnectionManagerInterface {
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
    
    /// Offline mode flag
    private var isOfflineMode: Bool = false
    
    /// Last connection error
    private var lastError: String? = nil
    
    /// Failure count for backoff calculation
    private var failureCount: Int = 0
    
    /// Last successful connection timestamp
    private var lastSuccessfulConnection: Int64 = 0
    
    /// Next reconnect timestamp
    private var nextReconnectTime: Int64 = 0
    
    /// Initialize with HTTP client and config
    /// - Parameters:
    ///   - httpClient: HTTP client
    ///   - config: SDK configuration
    public init(httpClient: HttpClient, config: CFConfig) {
        self.httpClient = httpClient
        self.config = config
        self.connectionInfo = ConnectionInformation(status: ConnectionStatus.failed)
    }
    
    // MARK: - ConnectionManagerInterface Implementation
    
    public func getConnectionInformation() -> ConnectionInformation {
        lock.lock()
        defer { lock.unlock() }
        return connectionInfo
    }
    
    public func setOfflineMode(offlineMode: Bool) {
        lock.lock()
        self.isOfflineMode = offlineMode
        lock.unlock()
        
        if offlineMode {
            updateConnectionStatus(.offline)
        } else {
            // Try to reconnect when coming back online
            checkConnection()
        }
    }
    
    public func getOfflineMode() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOfflineMode
    }
    
    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }
        listeners.removeAll()
    }
    
    public func recordSuccess() {
        lock.lock()
        failureCount = 0
        lastError = nil
        lastSuccessfulConnection = Int64(Date().timeIntervalSince1970 * 1000)
        lock.unlock()
        
        updateConnectionStatus(.connected)
    }
    
    public func recordFailure(error: String?) {
        lock.lock()
        failureCount += 1
        lastError = error
        lock.unlock()
        
        updateConnectionStatus(.disconnected)
    }
    
    public func checkConnection() {
        if getOfflineMode() {
            return
        }
        
        // In a real implementation, this would make a network request
        // For now, just update the status based on previous state
        if connectionStatus == .disconnected || connectionStatus == .failed {
            updateConnectionStatus(.connecting)
        }
        
        // Trigger onReconnect callback if present
        onReconnect?()
    }
    
    /// Callback for actual reconnection logic, to be set by the CFClient
    public var onReconnect: (() -> Void)?
    
    // MARK: - ConnectionManager Implementation (existing methods)
    
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
                isOfflineMode: false,
                lastError: nil,
                lastSuccessfulConnectionTimeMs: Int64(Date().timeIntervalSince1970 * 1000),
                failureCount: 0,
                nextReconnectTimeMs: nil
            )
        case .disconnected:
            connectionInfo = ConnectionInformation(
                status: ConnectionStatus.disconnected,
                isOfflineMode: false,
                lastError: "No network connection",
                lastSuccessfulConnectionTimeMs: nil,
                failureCount: 0,
                nextReconnectTimeMs: nil
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