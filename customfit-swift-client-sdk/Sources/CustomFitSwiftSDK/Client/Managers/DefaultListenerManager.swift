import Foundation

/// Default implementation for ListenerManager
public class DefaultListenerManager: ListenerManager {
    /// Config listeners by key
    private var configListeners = [String: [AnyHashable: (Any) -> Void]]()
    
    /// Feature flag listeners by key
    private var flagListeners = [String: [ObjectIdentifier: FeatureFlagChangeListener]]()
    
    /// All flags listeners
    private var allFlagsListeners = [ObjectIdentifier: AllFlagsListener]()
    
    /// Connection status listeners
    private var connectionStatusListeners = [ObjectIdentifier: ConnectionStatusListener]()
    
    /// Thread safety lock
    private let lock = NSLock()
    
    /// Initialize a new DefaultListenerManager
    public init() {}
    
    /// Add a config listener
    /// - Parameters:
    ///   - key: Configuration key
    ///   - listener: Listener callback
    public func addConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        var listeners = configListeners[key] ?? [:]
        let wrapper: (Any) -> Void = { value in
            if let typedValue = value as? T {
                listener(typedValue)
            }
        }
        
        let pointer = unsafeBitCast(listener as AnyObject, to: AnyHashable.self)
        listeners[pointer] = wrapper
        configListeners[key] = listeners
        
        Logger.debug("Added config listener for key: \(key)")
    }
    
    /// Remove a config listener
    /// - Parameters:
    ///   - key: Configuration key
    ///   - listener: Listener callback to remove
    public func removeConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        let pointer = unsafeBitCast(listener as AnyObject, to: AnyHashable.self)
        configListeners[key]?[pointer] = nil
        
        Logger.debug("Removed config listener for key: \(key)")
    }
    
    /// Clear all config listeners for a key
    /// - Parameter key: Configuration key
    public func clearConfigListeners(key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        configListeners[key] = nil
        
        Logger.debug("Cleared all config listeners for key: \(key)")
    }
    
    /// Register a feature flag listener
    /// - Parameters:
    ///   - flagKey: Feature flag key
    ///   - listener: Listener to register
    public func registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        var listeners = flagListeners[flagKey] ?? [:]
        let id = ObjectIdentifier(listener)
        listeners[id] = listener
        flagListeners[flagKey] = listeners
        
        Logger.debug("Registered feature flag listener for key: \(flagKey)")
    }
    
    /// Unregister a feature flag listener
    /// - Parameters:
    ///   - flagKey: Feature flag key
    ///   - listener: Listener to unregister
    public func unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        flagListeners[flagKey]?[id] = nil
        
        Logger.debug("Unregistered feature flag listener for key: \(flagKey)")
    }
    
    /// Register a listener for all flag changes
    /// - Parameter listener: Listener to register
    public func registerAllFlagsListener(listener: AllFlagsListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        allFlagsListeners[id] = listener
        
        Logger.debug("Registered all flags listener")
    }
    
    /// Unregister a listener for all flag changes
    /// - Parameter listener: Listener to unregister
    public func unregisterAllFlagsListener(listener: AllFlagsListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        allFlagsListeners[id] = nil
        
        Logger.debug("Unregistered all flags listener")
    }
    
    /// Add a connection status listener
    /// - Parameter listener: Listener to add
    public func addConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        connectionStatusListeners[id] = listener
        
        Logger.debug("Added connection status listener")
    }
    
    /// Remove a connection status listener
    /// - Parameter listener: Listener to remove
    public func removeConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        connectionStatusListeners[id] = nil
        
        Logger.debug("Removed connection status listener")
    }
    
    /// Notify config listeners about a value change
    /// - Parameters:
    ///   - key: Flag key
    ///   - oldValue: Old value
    ///   - newValue: New value
    public func notifyFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?) {
        lock.lock()
        
        // Notify specific flag listeners
        let flagListenersForKey = flagListeners[key]?.values
        
        // Get all flags listeners
        let allListeners = Array(allFlagsListeners.values)
        
        lock.unlock()
        
        // Notify specific flag listeners
        flagListenersForKey?.forEach { listener in
            listener.onFeatureFlagChange(key: key, oldValue: oldValue, newValue: newValue)
        }
        
        // Notify all flags listeners
        if !allListeners.isEmpty {
            notifyAllFlagsChange(changedKeys: [key])
        }
    }
    
    /// Notify all flags listeners about changes
    /// - Parameter changedKeys: Changed flag keys
    public func notifyAllFlagsChange(changedKeys: [String]) {
        lock.lock()
        let listeners = Array(allFlagsListeners.values)
        lock.unlock()
        
        for listener in listeners {
            listener.onFlagsChange(changedKeys: changedKeys)
        }
    }
    
    /// Notify connection status listeners
    /// - Parameters:
    ///   - status: Connection status
    ///   - info: Connection information
    public func notifyConnectionStatusChange(status: ConnectionStatus, info: ConnectionInformation) {
        lock.lock()
        let listeners = Array(connectionStatusListeners.values)
        lock.unlock()
        
        for listener in listeners {
            listener.onConnectionStatusChanged(newStatus: status, info: info)
        }
    }
    
    /// Clear all listeners
    public func clearAllListeners() {
        lock.lock()
        defer { lock.unlock() }
        
        configListeners.removeAll()
        flagListeners.removeAll()
        allFlagsListeners.removeAll()
        connectionStatusListeners.removeAll()
        
        Logger.debug("Cleared all listeners")
    }
} 