import Foundation

/// Listener for specific flag changes
public protocol FeatureFlagChangeListener {
    /// Called when a specific feature flag value changes
    func onFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?)
} 