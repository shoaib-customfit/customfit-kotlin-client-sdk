import Foundation

/// Listener for all flag changes
public protocol AllFlagsListener {
    /// Called when any feature flag changes
    func onFlagsChange(changedKeys: [String])
} 