import Foundation
import Network

/// Network connectivity state
public enum NetworkState {
    /// Connected to WiFi
    case wifi
    
    /// Connected to cellular network
    case cellular
    
    /// Connected to other non-cellular, non-WiFi network
    case other
    
    /// No network connectivity
    case notConnected
    
    /// Unknown network state
    case unknown
}

/// Protocol for listening to network state changes
public protocol NetworkStateListener: AnyObject {
    /// Called when network state changes
    /// - Parameter state: The new network state
    func onNetworkStateChanged(state: NetworkState)
}

/// Protocol for monitoring network connectivity
public protocol NetworkConnectivityMonitor {
    /// Start monitoring network state
    func startMonitoring()
    
    /// Stop monitoring network state
    func stopMonitoring()
    
    /// Add a network state listener
    /// - Parameter listener: The listener to add
    func addNetworkStateListener(listener: NetworkStateListener)
    
    /// Remove a network state listener
    /// - Parameter listener: The listener to remove
    func removeNetworkStateListener(listener: NetworkStateListener)
    
    /// Get current network state
    /// - Returns: The current network state
    func getCurrentNetworkState() -> NetworkState
    
    /// Check if network is connected
    /// - Returns: Whether the network is connected
    func isNetworkConnected() -> Bool
}

/// Default implementation of NetworkConnectivityMonitor
public class DefaultNetworkConnectivityMonitor: NetworkConnectivityMonitor {
    
    // MARK: - Properties
    
    /// Network path monitor
    private let pathMonitor: NWPathMonitor
    
    /// Current network state
    private var currentState: NetworkState = .unknown
    
    /// Thread-safe network state
    private let stateLock = NSLock()
    
    /// Network state listeners
    private var listeners: [NetworkStateListener] = []
    
    /// Thread-safe listeners
    private let listenersLock = NSLock()
    
    /// Monitor queue
    private let monitorQueue: DispatchQueue
    
    /// Whether monitoring is active
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    /// Initialize a new network connectivity monitor
    /// - Parameter queue: The queue to use for monitoring
    public init(queue: DispatchQueue = DispatchQueue(label: "ai.customfit.NetworkMonitor", qos: .utility)) {
        self.pathMonitor = NWPathMonitor()
        self.monitorQueue = queue
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - NetworkConnectivityMonitor Protocol
    
    /// Start monitoring network state
    public func startMonitoring() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard !isMonitoring else { return }
        
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.handlePathUpdate(path)
        }
        
        pathMonitor.start(queue: monitorQueue)
        isMonitoring = true
        
        Logger.debug("Network connectivity monitoring started")
    }
    
    /// Stop monitoring network state
    public func stopMonitoring() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard isMonitoring else { return }
        
        pathMonitor.cancel()
        isMonitoring = false
        
        Logger.debug("Network connectivity monitoring stopped")
    }
    
    /// Add a network state listener
    /// - Parameter listener: The listener to add
    public func addNetworkStateListener(listener: NetworkStateListener) {
        listenersLock.lock()
        defer { listenersLock.unlock() }
        
        if !listeners.contains(where: { $0 === listener }) {
            listeners.append(listener)
            
            // Notify immediately with current state
            let state = getCurrentNetworkState()
            DispatchQueue.main.async {
                listener.onNetworkStateChanged(state: state)
            }
        }
    }
    
    /// Remove a network state listener
    /// - Parameter listener: The listener to remove
    public func removeNetworkStateListener(listener: NetworkStateListener) {
        listenersLock.lock()
        defer { listenersLock.unlock() }
        
        listeners.removeAll(where: { $0 === listener })
    }
    
    /// Get current network state
    /// - Returns: The current network state
    public func getCurrentNetworkState() -> NetworkState {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState
    }
    
    /// Check if network is connected
    /// - Returns: Whether the network is connected
    public func isNetworkConnected() -> Bool {
        let state = getCurrentNetworkState()
        return state == .wifi || state == .cellular || state == .other
    }
    
    // MARK: - Private Methods
    
    /// Handle a network path update
    /// - Parameter path: The updated network path
    private func handlePathUpdate(_ path: NWPath) {
        let newState = mapPathToNetworkState(path)
        
        stateLock.lock()
        let stateChanged = currentState != newState
        currentState = newState
        stateLock.unlock()
        
        if stateChanged {
            Logger.info("Network state changed to: \(stateToString(newState))")
            notifyListeners(state: newState)
        }
    }
    
    /// Map a network path to a network state
    /// - Parameter path: The network path
    /// - Returns: The network state
    private func mapPathToNetworkState(_ path: NWPath) -> NetworkState {
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wifi) {
                return .wifi
            } else if path.usesInterfaceType(.cellular) {
                return .cellular
            } else {
                return .other
            }
        case .unsatisfied:
            return .notConnected
        case .requiresConnection:
            return .notConnected
        @unknown default:
            return .unknown
        }
    }
    
    /// Convert a network state to a string
    /// - Parameter state: The network state
    /// - Returns: The string representation
    private func stateToString(_ state: NetworkState) -> String {
        switch state {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .other:
            return "Other"
        case .notConnected:
            return "Not Connected"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Notify listeners of a network state change
    /// - Parameter state: The new network state
    private func notifyListeners(state: NetworkState) {
        listenersLock.lock()
        let listenersCopy = listeners
        listenersLock.unlock()
        
        DispatchQueue.main.async {
            for listener in listenersCopy {
                listener.onNetworkStateChanged(state: state)
            }
        }
    }
} 