import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// App state enum
public enum AppState {
    /// App is in foreground
    case foreground
    
    /// App is in background
    case background
}

/// Protocol for listening to app state changes
public protocol AppStateListener: AnyObject {
    /// Called when app state changes
    /// - Parameter state: The new app state
    func onAppStateChange(state: AppState)
}

/// Protocol for listening to battery state changes
public protocol BatteryStateListener: AnyObject {
    /// Called when battery state changes
    /// - Parameter state: The new battery state
    func onBatteryStateChange(state: CFBatteryState)
}

/// Protocol for monitoring background state
public protocol BackgroundStateMonitor {
    /// Start monitoring background state
    func startMonitoring()
    
    /// Stop monitoring background state
    func stopMonitoring()
    
    /// Add an app state listener
    /// - Parameter listener: The listener to add
    func addAppStateListener(listener: AppStateListener)
    
    /// Remove an app state listener
    /// - Parameter listener: The listener to remove
    func removeAppStateListener(listener: AppStateListener)
    
    /// Add a battery state listener
    /// - Parameter listener: The listener to add
    func addBatteryStateListener(listener: BatteryStateListener)
    
    /// Remove a battery state listener
    /// - Parameter listener: The listener to remove
    func removeBatteryStateListener(listener: BatteryStateListener)
    
    /// Get current app state
    /// - Returns: The current app state
    func getCurrentAppState() -> AppState
    
    /// Get current battery state
    /// - Returns: The current battery state
    func getCurrentBatteryState() -> CFBatteryState
}

/// Default implementation of BackgroundStateMonitor
public class DefaultBackgroundStateMonitor: BackgroundStateMonitor {
    
    // MARK: - Properties
    
    /// Current app state
    private var appState: AppState = .foreground
    
    /// Current battery state
    private var batteryState: CFBatteryState
    
    /// App state listeners
    private var appStateListeners: [AppStateListener] = []
    
    /// Battery state listeners
    private var batteryStateListeners: [BatteryStateListener] = []
    
    /// Thread-safe access to state and listeners
    private let lock = NSLock()
    
    /// Timer for battery level checking
    private var batteryCheckTimer: Timer?
    
    /// Whether monitoring is active
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    /// Initialize a new background state monitor
    public init() {
        // Set initial battery state
        batteryState = CFBatteryState(isLow: false, isCharging: true, level: 1.0)
        
        #if os(iOS) || os(tvOS)
        // Enable battery monitoring on iOS/tvOS
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Update initial battery state
        updateBatteryState()
        #endif
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - BackgroundStateMonitor Protocol
    
    /// Start monitoring background state
    public func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isMonitoring else { return }
        
        #if os(iOS) || os(tvOS)
        // Register for app state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Register for battery state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Start battery check timer
        DispatchQueue.main.async {
            self.batteryCheckTimer = Timer.scheduledTimer(
                withTimeInterval: 60.0, // Check every minute
                repeats: true
            ) { [weak self] _ in
                self?.updateBatteryState()
            }
            RunLoop.current.add(self.batteryCheckTimer!, forMode: .common)
        }
        #endif
        
        isMonitoring = true
        
        Logger.debug("Background state monitoring started")
    }
    
    /// Stop monitoring background state
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isMonitoring else { return }
        
        #if os(iOS) || os(tvOS)
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Disable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = false
        
        // Stop battery check timer
        batteryCheckTimer?.invalidate()
        batteryCheckTimer = nil
        #endif
        
        isMonitoring = false
        
        Logger.debug("Background state monitoring stopped")
    }
    
    /// Add an app state listener
    /// - Parameter listener: The listener to add
    public func addAppStateListener(listener: AppStateListener) {
        lock.lock()
        defer { lock.unlock() }
        
        if !appStateListeners.contains(where: { $0 === listener }) {
            appStateListeners.append(listener)
            
            // Notify immediately with current state
            let state = getCurrentAppState()
            DispatchQueue.main.async {
                listener.onAppStateChange(state: state)
            }
        }
    }
    
    /// Remove an app state listener
    /// - Parameter listener: The listener to remove
    public func removeAppStateListener(listener: AppStateListener) {
        lock.lock()
        defer { lock.unlock() }
        
        appStateListeners.removeAll(where: { $0 === listener })
    }
    
    /// Add a battery state listener
    /// - Parameter listener: The listener to add
    public func addBatteryStateListener(listener: BatteryStateListener) {
        lock.lock()
        defer { lock.unlock() }
        
        if !batteryStateListeners.contains(where: { $0 === listener }) {
            batteryStateListeners.append(listener)
            
            // Notify immediately with current state
            let state = getCurrentBatteryState()
            DispatchQueue.main.async {
                listener.onBatteryStateChange(state: state)
            }
        }
    }
    
    /// Remove a battery state listener
    /// - Parameter listener: The listener to remove
    public func removeBatteryStateListener(listener: BatteryStateListener) {
        lock.lock()
        defer { lock.unlock() }
        
        batteryStateListeners.removeAll(where: { $0 === listener })
    }
    
    /// Get current app state
    /// - Returns: The current app state
    public func getCurrentAppState() -> AppState {
        lock.lock()
        defer { lock.unlock() }
        
        return appState
    }
    
    /// Get current battery state
    /// - Returns: The current battery state
    public func getCurrentBatteryState() -> CFBatteryState {
        lock.lock()
        defer { lock.unlock() }
        
        return batteryState
    }
    
    // MARK: - Private Methods
    
    #if os(iOS) || os(tvOS)
    /// Handle app did enter background notification
    @objc private func handleAppDidEnterBackground() {
        setAppState(.background)
    }
    
    /// Handle app will enter foreground notification
    @objc private func handleAppWillEnterForeground() {
        setAppState(.foreground)
    }
    
    /// Handle battery level changed notification
    @objc private func handleBatteryLevelChanged() {
        updateBatteryState()
    }
    
    /// Handle battery state changed notification
    @objc private func handleBatteryStateChanged() {
        updateBatteryState()
    }
    
    /// Update battery state
    private func updateBatteryState() {
        let level = UIDevice.current.batteryLevel
        let batteryLevel = level < 0 ? 1.0 : Float(level) // -1 means unknown, default to 1.0
        
        let isCharging: Bool
        switch UIDevice.current.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged, .unknown:
            isCharging = false
        @unknown default:
            isCharging = false
        }
        
        // Consider battery low if less than 20% and not charging
        let isLow = batteryLevel < 0.2 && !isCharging
        
        // Set new battery state
        setBatteryState(CFBatteryState(isLow: isLow, isCharging: isCharging, level: batteryLevel))
    }
    #endif
    
    /// Set app state
    /// - Parameter state: The new app state
    private func setAppState(_ state: AppState) {
        lock.lock()
        
        let stateChanged = appState != state
        appState = state
        
        // Make a copy of listeners before releasing lock
        let listeners = appStateListeners
        
        lock.unlock()
        
        if stateChanged {
            Logger.info("App state changed to: \(state == .foreground ? "foreground" : "background")")
            
            // Notify listeners
            DispatchQueue.main.async {
                for listener in listeners {
                    listener.onAppStateChange(state: state)
                }
            }
        }
    }
    
    /// Set battery state
    /// - Parameter state: The new battery state
    private func setBatteryState(_ state: CFBatteryState) {
        lock.lock()
        
        let stateChanged = batteryState.isLow != state.isLow ||
                          batteryState.isCharging != state.isCharging ||
                          abs(batteryState.level - state.level) > 0.05
        
        batteryState = state
        
        // Make a copy of listeners before releasing lock
        let listeners = batteryStateListeners
        
        lock.unlock()
        
        if stateChanged {
            Logger.info("Battery state changed: level=\(state.level), isLow=\(state.isLow), isCharging=\(state.isCharging)")
            
            // Notify listeners
            DispatchQueue.main.async {
                for listener in listeners {
                    listener.onBatteryStateChange(state: state)
                }
            }
        }
    }
} 