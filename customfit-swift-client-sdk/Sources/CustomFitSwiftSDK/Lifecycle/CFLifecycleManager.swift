import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Manages app lifecycle events
public class CFLifecycleManager {
    
    // MARK: - Properties
    
    private var observers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring lifecycle events
    public func start() {
        #if os(iOS) || os(tvOS)
        setupLifecycleObservers()
        #endif
    }
    
    /// Stop monitoring lifecycle events
    public func stop() {
        removeLifecycleObservers()
    }
    
    // MARK: - Private Methods
    
    #if os(iOS) || os(tvOS)
    private func setupLifecycleObservers() {
        let notificationCenter = NotificationCenter.default
        
        // App did become active
        let activeObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
        
        // App will resign active
        let inactiveObserver = notificationCenter.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        // App did enter background
        let backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        
        // App will enter foreground
        let foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
        
        // App will terminate
        let terminateObserver = notificationCenter.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillTerminate()
        }
        
        observers = [activeObserver, inactiveObserver, backgroundObserver, foregroundObserver, terminateObserver]
    }
    #endif
    
    private func removeLifecycleObservers() {
        let notificationCenter = NotificationCenter.default
        
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        
        observers.removeAll()
    }
    
    private func handleAppDidBecomeActive() {
        // Handle app becoming active
        NotificationCenter.default.post(name: .cfAppDidBecomeActive, object: nil)
    }
    
    private func handleAppWillResignActive() {
        // Handle app resigning active
        NotificationCenter.default.post(name: .cfAppWillResignActive, object: nil)
    }
    
    private func handleAppDidEnterBackground() {
        // Handle app entering background
        NotificationCenter.default.post(name: .cfAppDidEnterBackground, object: nil)
    }
    
    private func handleAppWillEnterForeground() {
        // Handle app entering foreground
        NotificationCenter.default.post(name: .cfAppWillEnterForeground, object: nil)
    }
    
    private func handleAppWillTerminate() {
        // Handle app terminating
        NotificationCenter.default.post(name: .cfAppWillTerminate, object: nil)
    }
}

// MARK: - Custom Notification Names

public extension Notification.Name {
    /// App did become active
    static let cfAppDidBecomeActive = Notification.Name("ai.customfit.appDidBecomeActive")
    
    /// App will resign active
    static let cfAppWillResignActive = Notification.Name("ai.customfit.appWillResignActive")
    
    /// App did enter background
    static let cfAppDidEnterBackground = Notification.Name("ai.customfit.appDidEnterBackground")
    
    /// App will enter foreground
    static let cfAppWillEnterForeground = Notification.Name("ai.customfit.appWillEnterForeground")
    
    /// App will terminate
    static let cfAppWillTerminate = Notification.Name("ai.customfit.appWillTerminate")
} 