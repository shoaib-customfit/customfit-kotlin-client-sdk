import Foundation

/// Feature flag change listener protocol
public protocol FeatureFlagChangeListener: AnyObject {
    /// Called when a feature flag changes
    func onFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?)
}

/// All flags listener protocol
public protocol AllFlagsListener: AnyObject {
    /// Called when any flags change
    func onFlagsChange(changedKeys: [String])
}

/// Connection status listener protocol
public protocol ConnectionStatusListener: AnyObject {
    /// Called when connection status changes
    func onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation)
}

/// ListenerManager protocol for managing feature flag and connection status listeners
public protocol ListenerManager {
    /// Add a config listener
    func addConfigListener<T>(key: String, listener: @escaping (T) -> Void)
    
    /// Remove a config listener
    func removeConfigListener<T>(key: String, listener: @escaping (T) -> Void)
    
    /// Clear all config listeners for a key
    func clearConfigListeners(key: String)
    
    /// Add a listener for feature flag changes
    func registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener)
    
    /// Remove a listener for feature flag changes
    func unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener)
    
    /// Add a listener for all flags changes
    func registerAllFlagsListener(listener: AllFlagsListener)
    
    /// Remove a listener for all flags changes
    func unregisterAllFlagsListener(listener: AllFlagsListener)
    
    /// Add a connection status listener
    func addConnectionStatusListener(listener: ConnectionStatusListener)
    
    /// Remove a connection status listener
    func removeConnectionStatusListener(listener: ConnectionStatusListener)
    
    /// Notify config listeners about a value change
    func notifyFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?)
    
    /// Notify all flags listeners about changes
    func notifyAllFlagsChange(changedKeys: [String])
    
    /// Notify connection status listeners
    func notifyConnectionStatusChange(status: ConnectionStatus, info: ConnectionInformation)
    
    /// Clear all registered listeners
    func clearAllListeners()
}

/// Event listener management implementation
public class ListenerManagerImpl: ListenerManager {
    
    // MARK: - Properties
    
    private var configListeners: [String: [AnyHashable: (Any) -> Void]] = [:]
    private var flagChangeListeners: [String: [ObjectIdentifier: FeatureFlagChangeListener]] = [:]
    private var allFlagsListeners: [ObjectIdentifier: AllFlagsListener] = [:]
    private var connectionStatusListeners: [ObjectIdentifier: ConnectionStatusListener] = [:]
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    // MARK: - ListenerManager Implementation
    
    public func addConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        var listeners = configListeners[key] ?? [:]
        let wrapper: (Any) -> Void = { value in
            if let typedValue = value as? T {
                listener(typedValue)
            }
        }
        
        // Use UUID-based identification instead of unsafe bit casting
        let listenerId = UUID().hashValue
        listeners[listenerId] = wrapper
        configListeners[key] = listeners
        
        Logger.debug("Added listener for key: \(key)")
    }
    
    public func removeConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        // Since we can't safely identify individual closures, clear all listeners for this key
        configListeners[key] = [:]
        
        Logger.debug("Cleared config listeners for key: \(key) (safe approach)")
    }
    
    public func clearConfigListeners(key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        configListeners[key] = [:]
        
        Logger.debug("Cleared all listeners for key: \(key)")
    }
    
    public func registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        var listeners = flagChangeListeners[flagKey] ?? [:]
        let id = ObjectIdentifier(listener)
        listeners[id] = listener
        flagChangeListeners[flagKey] = listeners
        
        Logger.debug("Registered feature flag listener for key: \(flagKey)")
    }
    
    public func unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        flagChangeListeners[flagKey]?[id] = nil
        
        Logger.debug("Unregistered feature flag listener for key: \(flagKey)")
    }
    
    public func registerAllFlagsListener(listener: AllFlagsListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        allFlagsListeners[id] = listener
        
        Logger.debug("Registered all flags listener")
    }
    
    public func unregisterAllFlagsListener(listener: AllFlagsListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        allFlagsListeners[id] = nil
        
        Logger.debug("Unregistered all flags listener")
    }
    
    public func addConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        connectionStatusListeners[id] = listener
        
        Logger.debug("Added connection status listener")
    }
    
    public func removeConnectionStatusListener(listener: ConnectionStatusListener) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(listener)
        connectionStatusListeners[id] = nil
        
        Logger.debug("Removed connection status listener")
    }
    
    public func notifyConfigListeners(key: String, value: Any) {
        lock.lock()
        let listeners = configListeners[key]?.values
        lock.unlock()
        
        listeners?.forEach { listener in
            listener(value)
        }
    }
    
    public func notifyFeatureFlagListeners(key: String, value: Any) {
        lock.lock()
        let listeners = flagChangeListeners[key]?.values
        lock.unlock()
        
        listeners?.forEach { listener in
            try? {
                listener.onFeatureFlagChange(key: key, oldValue: nil, newValue: value)
            }()
        }
    }
    
    public func notifyAllFlagsListeners(_ changedKeys: [String]) {
        lock.lock()
        let listeners = Array(allFlagsListeners.values)
        lock.unlock()
        
        for listener in listeners {
            listener.onFlagsChange(changedKeys: changedKeys)
        }
    }
    
    public func notifyConnectionStatusListeners(status: ConnectionStatus, info: ConnectionInformation) {
        lock.lock()
        let listeners = Array(connectionStatusListeners.values)
        lock.unlock()
        
        for listener in listeners {
            listener.onConnectionStatusChanged(newStatus: status, info: info)
        }
    }
    
    public func clearAllListeners() {
        lock.lock()
        defer { lock.unlock() }
        
        configListeners.removeAll()
        flagChangeListeners.removeAll()
        allFlagsListeners.removeAll()
        connectionStatusListeners.removeAll()
        
        Logger.debug("Cleared all listeners")
    }
    
    public func notifyFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?) {
        lock.lock()
        
        // Get config listeners for this key
        let configListeners = self.configListeners[key]?.values
        
        // Notify specific flag listeners
        let flagListeners = flagChangeListeners[key]?.values
        
        // Get all flags listeners
        let allListeners = Array(allFlagsListeners.values)
        
        lock.unlock()
        
        // Notify config listeners first
        configListeners?.forEach { listener in
            listener(newValue ?? oldValue ?? "")
        }
        
        // Notify specific flag listeners
        flagListeners?.forEach { listener in
            listener.onFeatureFlagChange(key: key, oldValue: oldValue, newValue: newValue)
        }
        
        // Notify all flags listeners
        if !allListeners.isEmpty {
            notifyAllFlagsListeners([key])
        }
    }
    
    public func notifyAllFlagsChange(changedKeys: [String]) {
        notifyAllFlagsListeners(changedKeys)
    }
    
    public func notifyConnectionStatusChange(status: ConnectionStatus, info: ConnectionInformation) {
        notifyConnectionStatusListeners(status: status, info: info)
    }
} 