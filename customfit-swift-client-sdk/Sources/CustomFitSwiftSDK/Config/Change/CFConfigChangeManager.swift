import Foundation

/// Manages config change notifications
public class CFConfigChangeManager {
    /// Singleton instance
    public static let shared = CFConfigChangeManager()
    
    /// Observers registered for config changes
    private var observers = [ObjectIdentifier: ConfigChangeObserver]()
    
    /// Thread safety
    private let lock = NSLock()
    
    /// Private initializer for singleton
    private init() {}
    
    /// Register an observer for config changes
    /// - Parameter observer: Observer to register
    public func registerObserver(_ observer: ConfigChangeObserver) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(observer)
        observers[id] = observer
        
        Logger.debug("Registered config change observer")
    }
    
    /// Unregister an observer
    /// - Parameter observer: Observer to unregister
    public func unregisterObserver(_ observer: ConfigChangeObserver) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(observer)
        observers.removeValue(forKey: id)
        
        Logger.debug("Unregistered config change observer")
    }
    
    /// Notify observers of config changes
    /// - Parameters:
    ///   - newConfigs: New config values
    ///   - oldConfigs: Old config values
    public func notifyObservers(newConfigs: [String: Any], oldConfigs: [String: Any]?) {
        lock.lock()
        let observersCopy = Array(observers.values)
        lock.unlock()
        
        // Find changed keys
        var changedKeys = Set<String>()
        
        // Add all keys from new configs
        for key in newConfigs.keys {
            changedKeys.insert(key)
        }
        
        // Add all keys from old configs
        if let oldConfigs = oldConfigs {
            for key in oldConfigs.keys {
                changedKeys.insert(key)
            }
        }
        
        // Find changes by comparing values
        var realChanges = [String]()
        
        for key in changedKeys {
            let oldValue = oldConfigs?[key]
            let newValue = newConfigs[key]
            
            // Check if the values are different
            if !isEqual(oldValue, newValue) {
                realChanges.append(key)
                
                // Notify about individual flag change
                notifyFlagChange(key: key, oldValue: oldValue, newValue: newValue)
            }
        }
        
        // Only notify if there are actual changes
        if !realChanges.isEmpty {
            for observer in observersCopy {
                observer.onConfigChanged(changedKeys: realChanges)
            }
        }
    }
    
    /// Notify about a specific flag change
    /// - Parameters:
    ///   - key: Flag key
    ///   - oldValue: Old value
    ///   - newValue: New value
    private func notifyFlagChange(key: String, oldValue: Any?, newValue: Any?) {
        lock.lock()
        let observersCopy = Array(observers.values)
        lock.unlock()
        
        for observer in observersCopy {
            observer.onFlagChanged(key: key, oldValue: oldValue, newValue: newValue)
        }
    }
    
    /// Compare two values for equality
    /// - Parameters:
    ///   - a: First value
    ///   - b: Second value
    /// - Returns: Whether the values are equal
    private func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        // Handle nil cases
        if a == nil && b == nil {
            return true
        }
        
        if a == nil || b == nil {
            return false
        }
        
        // Handle different types
        if type(of: a!) != type(of: b!) {
            return false
        }
        
        // Handle number types
        if let a = a as? NSNumber, let b = b as? NSNumber {
            return a.isEqual(to: b)
        }
        
        // Handle string types
        if let a = a as? String, let b = b as? String {
            return a == b
        }
        
        // Handle array types
        if let a = a as? [Any], let b = b as? [Any] {
            guard a.count == b.count else { return false }
            
            for i in 0..<a.count {
                if !isEqual(a[i], b[i]) {
                    return false
                }
            }
            
            return true
        }
        
        // Handle dictionary types
        if let a = a as? [String: Any], let b = b as? [String: Any] {
            guard a.count == b.count else { return false }
            
            for (key, valueA) in a {
                guard let valueB = b[key] else { return false }
                
                if !isEqual(valueA, valueB) {
                    return false
                }
            }
            
            return true
        }
        
        // Handle boolean types
        if let a = a as? Bool, let b = b as? Bool {
            return a == b
        }
        
        // Default comparison using equality
        return (a as AnyObject).isEqual(b as AnyObject)
    }
} 