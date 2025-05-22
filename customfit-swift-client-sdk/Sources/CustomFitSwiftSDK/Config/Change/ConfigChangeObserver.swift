import Foundation

/// Protocol for observing configuration changes
public protocol ConfigChangeObserver: AnyObject {
    /// Called when a configuration flag changes
    /// - Parameters:
    ///   - key: Flag key
    ///   - oldValue: Old value
    ///   - newValue: New value
    func onFlagChanged(key: String, oldValue: Any?, newValue: Any?)
    
    /// Called when multiple configuration flags change
    /// - Parameter changedKeys: Changed flag keys
    func onConfigChanged(changedKeys: [String])
} 