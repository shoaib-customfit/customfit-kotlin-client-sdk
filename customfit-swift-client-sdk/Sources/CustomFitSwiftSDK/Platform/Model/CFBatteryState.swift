import Foundation

/// Battery state data structure
public struct CFBatteryState {
    /// Whether the battery is low
    public let isLow: Bool
    
    /// Whether the device is charging
    public let isCharging: Bool
    
    /// Battery level (0.0 to 1.0)
    public let level: Float
    
    /// Initialize a new battery state
    /// - Parameters:
    ///   - isLow: Whether the battery is low
    ///   - isCharging: Whether the device is charging
    ///   - level: Battery level
    public init(isLow: Bool, isCharging: Bool, level: Float) {
        self.isLow = isLow
        self.isCharging = isCharging
        self.level = level
    }
} 