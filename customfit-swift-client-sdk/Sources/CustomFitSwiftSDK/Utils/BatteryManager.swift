import Foundation
#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

/// Battery state enumeration
public enum BatteryState {
    /// The device is plugged in and charging
    case charging
    
    /// The device is unplugged and discharging
    case discharging
    
    /// The device is fully charged
    case full
    
    /// The battery state is unknown
    case unknown
}

/// Singleton class to monitor device battery state
public class BatteryManager {
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = BatteryManager()
    
    // MARK: - Properties
    
    /// Current battery level (0.0 to 1.0)
    private(set) public var batteryLevel: Float = 1.0
    
    /// Current battery state
    private(set) public var batteryState: BatteryState = .unknown
    
    /// Whether the device is in low power mode
    private(set) public var isLowPowerModeEnabled: Bool = false
    
    /// Whether the battery level is considered low (below 20%)
    public var isBatteryLow: Bool {
        return batteryLevel < 0.2
    }
    
    /// Whether battery monitoring is enabled
    public var isMonitoringEnabled: Bool {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return UIDevice.current.isBatteryMonitoringEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Battery Monitoring
    
    /// Start monitoring battery state
    public func startMonitoring() {
        #if os(iOS) || os(watchOS) || os(tvOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Get initial values
        updateBatteryLevel()
        updateBatteryState()
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        if #available(iOS 9.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(lowPowerModeChanged),
                name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil
            )
            updateLowPowerMode()
        }
        #endif
    }
    
    /// Stop monitoring battery state
    public func stopMonitoring() {
        #if os(iOS) || os(watchOS) || os(tvOS)
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    // MARK: - Notification Handlers
    
    @objc private func batteryLevelChanged() {
        updateBatteryLevel()
        Logger.debug("Battery level changed: \(Int(batteryLevel * 100))%")
    }
    
    @objc private func batteryStateChanged() {
        updateBatteryState()
        Logger.debug("Battery state changed: \(batteryState)")
    }
    
    @objc private func lowPowerModeChanged() {
        updateLowPowerMode()
        Logger.debug("Low power mode changed: \(isLowPowerModeEnabled)")
    }
    
    // MARK: - Update Methods
    
    private func updateBatteryLevel() {
        #if os(iOS) || os(watchOS) || os(tvOS)
        batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel < 0 {
            batteryLevel = 1.0 // Unknown or simulator
        }
        #elseif os(macOS)
        // Get battery level from IOKit - simplified implementation
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        if let powerSource = sources.first,
           let description = IOPSGetPowerSourceDescription(snapshot, powerSource).takeUnretainedValue() as? [String: Any],
           let currentCapacity = description["Current Capacity"] as? Int,
           let maxCapacity = description["Max Capacity"] as? Int {
            batteryLevel = Float(currentCapacity) / Float(maxCapacity)
        } else {
            batteryLevel = 1.0 // Unknown or desktop Mac
        }
        #else
        batteryLevel = 1.0 // Unknown platform
        #endif
    }
    
    private func updateBatteryState() {
        #if os(iOS) || os(watchOS) || os(tvOS)
        switch UIDevice.current.batteryState {
        case .charging:
            batteryState = .charging
        case .full:
            batteryState = .full
        case .unplugged:
            batteryState = .discharging
        case .unknown:
            batteryState = .unknown
        @unknown default:
            batteryState = .unknown
        }
        #else
        batteryState = .unknown
        #endif
    }
    
    private func updateLowPowerMode() {
        #if os(iOS)
        if #available(iOS 9.0, *) {
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            isLowPowerModeEnabled = false
        }
        #else
        isLowPowerModeEnabled = false
        #endif
    }
    
    // MARK: - Polling Interval Adjustment
    
    /// Gets the battery-aware polling interval
    /// - Parameters:
    ///   - normalInterval: Regular polling interval in milliseconds
    ///   - reducedInterval: Reduced polling interval for low battery in milliseconds
    ///   - useReducedWhenLow: Whether to use reduced interval when battery is low
    /// - Returns: The appropriate polling interval in milliseconds
    public func getPollingInterval(
        normalInterval: Int64,
        reducedInterval: Int64,
        useReducedWhenLow: Bool
    ) -> Int64 {
        // If reduced polling is enabled and battery is low or in low power mode
        if useReducedWhenLow && (isBatteryLow || isLowPowerModeEnabled) {
            Logger.info("Using reduced polling interval (\(reducedInterval) ms) due to low battery or power saving mode")
            return reducedInterval
        }
        
        return normalInterval
    }
} 