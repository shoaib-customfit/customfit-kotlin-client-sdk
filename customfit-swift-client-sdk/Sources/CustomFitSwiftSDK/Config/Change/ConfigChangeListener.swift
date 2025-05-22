import Foundation

/// Protocol for objects that want to listen for configuration changes
public protocol ConfigChangeListener {
    /// Unique identifier for the listener
    var id: String { get }
    
    /// Called when a configuration value changes
    /// - Parameter key: The configuration key that changed
    func onConfigChanged(key: String)
} 