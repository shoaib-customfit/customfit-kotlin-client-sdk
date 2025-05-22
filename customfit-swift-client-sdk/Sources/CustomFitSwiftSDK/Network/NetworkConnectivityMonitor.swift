import Foundation
import Network

/// Network connectivity state
public enum ConnectionNetworkState {
    /// Connected to WiFi
    case wifi
    
    /// Connected to mobile data
    case cellular
    
    /// Connected via ethernet
    case ethernet
    
    /// Connected via unknown interface
    case other
    
    /// Not connected
    case disconnected
    
    /// Connection state unknown
    case unknown
}

/// Network connectivity observer
public protocol NetworkConnectivityObserver: AnyObject {
    /// Called when network state changes
    /// - Parameter state: The new network state
    func onNetworkStateChanged(state: ConnectionNetworkState)
}

/// Network connectivity monitor interface
public protocol NetworkConnectivityMonitor {
    /// Add network state observer
    /// - Parameter observer: The observer to add
    func addObserver(observer: NetworkConnectivityObserver)
    
    /// Remove network state observer
    /// - Parameter observer: The observer to remove
    func removeObserver(observer: NetworkConnectivityObserver)
    
    /// Get current network state
    /// - Returns: The current network state
    func getCurrentNetworkState() -> ConnectionNetworkState
    
    /// Check if network is connected
    /// - Returns: True if connected, false otherwise
    func isConnected() -> Bool
    
    /// Start monitoring
    func startMonitoring()
    
    /// Stop monitoring
    func stopMonitoring()
}

/// Network connectivity monitor implementation
public class NetworkConnectivityMonitorImpl: NetworkConnectivityMonitor {
    
    // MARK: - Properties
    
    /// Current network state
    private var currentState: ConnectionNetworkState = .unknown
    
    /// Thread-safe network state
    private let stateLock = NSLock()
    
    /// Network path monitor
    private let monitor = NWPathMonitor()
    
    /// Monitor queue
    private let monitorQueue = DispatchQueue(label: "ai.customfit.networkMonitor", qos: .utility)
    
    /// Main queue for callbacks
    private let callbackQueue = DispatchQueue.main
    
    /// Registered observers
    private var listeners = [ObjectIdentifier: NetworkConnectivityObserver]()
    
    /// Thread-safe observers
    private let listenersLock = NSLock()
    
    /// Whether monitoring is active
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    public init() {
        setupMonitor()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let state = self.mapPathToNetworkState(path)
            
            self.stateLock.lock()
            let oldState = self.currentState
            self.currentState = state
            self.stateLock.unlock()
            
            // Notify listeners only if state changed
            if oldState != state {
                Logger.debug("Network state changed: \(self.stateToString(oldState)) -> \(self.stateToString(state))")
                self.notifyListeners(state: state)
            }
        }
    }
    
    // MARK: - NetworkConnectivityMonitor Implementation
    
    public func addObserver(observer: NetworkConnectivityObserver) {
        listenersLock.lock()
        listeners[ObjectIdentifier(observer)] = observer
        listenersLock.unlock()
        
        // Notify the new observer of the current state
        stateLock.lock()
        let state = currentState
        stateLock.unlock()
        
        callbackQueue.async {
            observer.onNetworkStateChanged(state: state)
        }
        
        Logger.debug("Added network connectivity observer")
    }
    
    public func removeObserver(observer: NetworkConnectivityObserver) {
        listenersLock.lock()
        listeners.removeValue(forKey: ObjectIdentifier(observer))
        listenersLock.unlock()
        
        Logger.debug("Removed network connectivity observer")
    }
    
    public func getCurrentNetworkState() -> ConnectionNetworkState {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState
    }
    
    public func isConnected() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState != .disconnected && currentState != .unknown
    }
    
    public func startMonitoring() {
        if !isMonitoring {
            monitor.start(queue: monitorQueue)
            isMonitoring = true
            
            Logger.debug("Started network connectivity monitoring")
        }
    }
    
    public func stopMonitoring() {
        if isMonitoring {
            monitor.cancel()
            isMonitoring = false
            
            Logger.debug("Stopped network connectivity monitoring")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Map NWPath to NetworkState
    /// - Parameter path: The network path
    /// - Returns: The network state
    private func mapPathToNetworkState(_ path: NWPath) -> ConnectionNetworkState {
        switch path.status {
        case .satisfied:
            // Determine the interface type
            if path.usesInterfaceType(.wifi) {
                return .wifi
            } else if path.usesInterfaceType(.cellular) {
                return .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                return .ethernet
            } else {
                return .other
            }
            
        case .unsatisfied, .requiresConnection:
            return .disconnected
            
        @unknown default:
            return .unknown
        }
    }
    
    /// Convert NetworkState to string for logging
    /// - Parameter state: The network state
    /// - Returns: The string representation
    private func stateToString(_ state: ConnectionNetworkState) -> String {
        switch state {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .other:
            return "Other"
        case .disconnected:
            return "Disconnected"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Notify listeners of a network state change
    /// - Parameter state: The new network state
    private func notifyListeners(state: ConnectionNetworkState) {
        listenersLock.lock()
        let listenersCopy = listeners
        listenersLock.unlock()
        
        callbackQueue.async {
            for (_, listener) in listenersCopy {
                listener.onNetworkStateChanged(state: state)
            }
        }
    }
} 