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
        setupLifecycleObservers()
    }
    
    /// Stop monitoring lifecycle events
    public func stop() {
        removeLifecycleObservers()
    }
    
    // MARK: - Private Methods
    
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
    
    private func removeLifecycleObservers() {
        let notificationCenter = NotificationCenter.default
        
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        
        observers.removeAll()
    }
    
    private func handleAppDidBecomeActive() {
        // Handle app becoming active
    }
    
    private func handleAppWillResignActive() {
        // Handle app resigning active
    }
    
    private func handleAppDidEnterBackground() {
        // Handle app entering background
    }
    
    private func handleAppWillEnterForeground() {
        // Handle app entering foreground
    }
    
    private func handleAppWillTerminate() {
        // Handle app terminating
    }
} 