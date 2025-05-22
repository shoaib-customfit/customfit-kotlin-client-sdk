import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Background task definition
public class BackgroundTask {
    /// Unique identifier
    public let identifier: String
    
    /// Minimum interval between executions in milliseconds
    public let intervalMs: Int64
    
    /// Whether the task requires connectivity
    public let requiresConnectivity: Bool
    
    /// Whether the task should run even when battery is low
    public let runWhenLowBattery: Bool
    
    /// Time when the task was last executed
    public var lastExecutionTime: Date?
    
    /// Task execution block
    private let executionBlock: (@escaping (Bool) -> Void) -> Void
    
    /// Initialize a new background task
    /// - Parameters:
    ///   - identifier: Unique identifier for the task
    ///   - intervalMs: Minimum interval between executions in milliseconds
    ///   - requiresConnectivity: Whether the task requires connectivity
    ///   - runWhenLowBattery: Whether the task should run even when battery is low
    ///   - executionBlock: Task execution block
    public init(
        identifier: String,
        intervalMs: Int64,
        requiresConnectivity: Bool = true,
        runWhenLowBattery: Bool = false,
        executionBlock: @escaping (@escaping (Bool) -> Void) -> Void
    ) {
        self.identifier = identifier
        self.intervalMs = intervalMs
        self.requiresConnectivity = requiresConnectivity
        self.runWhenLowBattery = runWhenLowBattery
        self.executionBlock = executionBlock
    }
    
    /// Execute the task
    /// - Parameter completion: Completion handler called when the task is complete
    public func execute(completion: @escaping (Bool) -> Void) {
        executionBlock { success in
            self.lastExecutionTime = Date()
            completion(success)
        }
    }
}

/// Protocol for managing background tasks
public protocol BackgroundTaskManager {
    /// Schedule a task
    /// - Parameter task: The task to schedule
    /// - Returns: Whether the task was scheduled
    func scheduleTask(task: BackgroundTask) -> Bool
    
    /// Cancel a task
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task was cancelled
    func cancelTask(identifier: String) -> Bool
    
    /// Execute a task now, ignoring constraints
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task was executed
    func executeTaskNow(identifier: String) -> Bool
    
    /// Check if a task is scheduled
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task is scheduled
    func isTaskScheduled(identifier: String) -> Bool
    
    /// Get the next execution time for a task
    /// - Parameter identifier: The task identifier
    /// - Returns: The next execution time
    func getNextExecutionTime(identifier: String) -> Date?
    
    /// Start background task manager
    func start()
    
    /// Stop background task manager
    func stop()
}

/// Default implementation of BackgroundTaskManager
public class DefaultBackgroundTaskManager: BackgroundTaskManager, AppStateListener, BatteryStateListener, NetworkConnectivityObserver {
    
    // MARK: - Properties
    
    /// Registry of background tasks
    private var tasks = [String: BackgroundTask]()
    
    /// Task executions
    private var taskExecutions = [String: Date]()
    
    /// Task execution locks
    private var locks = [String: NSLock]()
    
    /// Timers mapped by task identifier
    private var timers = [String: Timer]()
    
    /// Background state monitor
    private let backgroundStateMonitor: BackgroundStateMonitor
    
    /// Network connectivity monitor
    private let networkConnectivityMonitor: NetworkConnectivityMonitor
    
    /// Thread-safe operations on task registry
    private let tasksLock = NSLock()
    
    /// General lock for other synchronized operations
    private let lock = NSLock()
    
    /// Current app state
    private var appState: AppState = .foreground
    
    /// Current battery state
    private var batteryState: CFBatteryState
    
    /// Current network state
    private var networkState: ConnectionNetworkState = .unknown
    
    #if os(iOS) || os(tvOS)
    /// Background task identifiers
    private var backgroundTaskIds = [String: UIBackgroundTaskIdentifier]()
    #endif
    
    // MARK: - Initialization
    
    /// Initialize a new background task manager
    /// - Parameters:
    ///   - backgroundStateMonitor: Background state monitor
    ///   - networkConnectivityMonitor: Network connectivity monitor
    public init(
        backgroundStateMonitor: BackgroundStateMonitor,
        networkConnectivityMonitor: NetworkConnectivityMonitor
    ) {
        self.backgroundStateMonitor = backgroundStateMonitor
        self.networkConnectivityMonitor = networkConnectivityMonitor
        self.batteryState = CFBatteryState(isLow: false, isCharging: false, level: 1.0)
    }
    
    /// Set up state monitoring
    public func setupStateMonitoring() {
        backgroundStateMonitor.addAppStateListener(listener: self)
        backgroundStateMonitor.addBatteryStateListener(listener: self)
        networkConnectivityMonitor.addObserver(observer: self)
        
        // Set initial states
        appState = backgroundStateMonitor.getCurrentAppState()
        batteryState = backgroundStateMonitor.getCurrentBatteryState()
        networkState = networkConnectivityMonitor.getCurrentNetworkState()
        
        // Start network monitoring
        networkConnectivityMonitor.startMonitoring()
    }
    
    /// Clean up state monitoring
    public func cleanupStateMonitoring() {
        backgroundStateMonitor.removeAppStateListener(listener: self)
        backgroundStateMonitor.removeBatteryStateListener(listener: self)
        networkConnectivityMonitor.removeObserver(observer: self)
    }
    
    // MARK: - AppStateListener Implementation
    
    /// Handle app state changes - implementation of AppStateListener
    /// - Parameter state: The new app state
    public func onAppStateChange(state: AppState) {
        Logger.debug("App state changed: \(state)")
        
        appState = state
        
        // Check if tasks should run based on new state
        if state == .foreground || state == .background {
            checkForDelayedTasks()
        }
    }
    
    // MARK: - BatteryStateListener Implementation
    
    /// Handle battery state changes - implementation of BatteryStateListener
    /// - Parameter state: The new battery state
    public func onBatteryStateChange(state: CFBatteryState) {
        Logger.debug("Battery state changed: \(state)")
        
        batteryState = state
    }
    
    // MARK: - NetworkConnectivityObserver Implementation
    
    /// Handle network state changes - implementation of NetworkConnectivityObserver
    /// - Parameter state: The new network state
    public func onNetworkStateChanged(state: ConnectionNetworkState) {
        Logger.debug("Network state changed: \(state)")
        
        networkState = state
        
        // If network is now connected, check for delayed tasks
        if state == .wifi || state == .cellular || state == .ethernet {
            checkForDelayedTasks()
        }
    }
    
    // MARK: - BackgroundTaskManager Protocol
    
    /// Schedule a task
    /// - Parameter task: The task to schedule
    /// - Returns: Whether the task was scheduled
    public func scheduleTask(task: BackgroundTask) -> Bool {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        
        // Check if task is already scheduled
        if tasks[task.identifier] != nil {
            // Cancel existing task first
            _ = cancelTaskInternal(identifier: task.identifier)
        }
        
        // Add task to scheduled tasks
        tasks[task.identifier] = task
        
        // Schedule timer for the task
        scheduleTimer(for: task)
        
        Logger.debug("Scheduled task: \(task.identifier) with interval \(task.intervalMs)ms")
        
        return true
    }
    
    /// Cancel a task
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task was cancelled
    public func cancelTask(identifier: String) -> Bool {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        
        return cancelTaskInternal(identifier: identifier)
    }
    
    /// Execute a task now, ignoring constraints
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task was executed
    public func executeTaskNow(identifier: String) -> Bool {
        tasksLock.lock()
        let task = tasks[identifier]
        tasksLock.unlock()
        
        guard let task = task else {
            Logger.warning("Task not found: \(identifier)")
            return false
        }
        
        executeTask(task: task, ignoreConstraints: true)
        
        return true
    }
    
    /// Check if a task is scheduled
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task is scheduled
    public func isTaskScheduled(identifier: String) -> Bool {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        
        return tasks[identifier] != nil
    }
    
    /// Get the next execution time for a task
    /// - Parameter identifier: The task identifier
    /// - Returns: The next execution time
    public func getNextExecutionTime(identifier: String) -> Date? {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        
        guard let task = tasks[identifier],
              let lastExecution = task.lastExecutionTime else {
            return nil
        }
        
        return Date(timeIntervalSince1970: lastExecution.timeIntervalSince1970 + Double(task.intervalMs) / 1000.0)
    }
    
    /// Start background task manager
    public func start() {
        // Setup monitoring
        setupStateMonitoring()
    }
    
    /// Stop background task manager
    public func stop() {
        cancelAllTasks()
        cleanupStateMonitoring()
    }
    
    // MARK: - Private Methods
    
    /// Schedule a timer for a task
    /// - Parameter task: The task to schedule
    private func scheduleTimer(for task: BackgroundTask) {
        // Cancel existing timer
        if let existingTimer = timers[task.identifier] {
            existingTimer.invalidate()
            timers[task.identifier] = nil
        }
        
        // Calculate initial delay
        let initialDelay: TimeInterval
        if let lastExecution = task.lastExecutionTime {
            let elapsedMs = Date().timeIntervalSince(lastExecution) * 1000.0
            let remainingMs = Double(task.intervalMs) - elapsedMs
            
            initialDelay = max(0.1, remainingMs / 1000.0) // At least 0.1 seconds
        } else {
            initialDelay = 0.1 // Schedule almost immediately for first execution
        }
        
        // Create and schedule timer
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: initialDelay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                // Get the task from current tasks
                self.tasksLock.lock()
                let task = self.tasks[task.identifier]
                self.tasksLock.unlock()
                
                if let task = task {
                    self.executeTask(task: task)
                }
            }
            
            // Add to common run loop modes to ensure timer fires during scrolling, etc.
            RunLoop.current.add(timer, forMode: .common)
            
            self.lock.lock()
            self.timers[task.identifier] = timer
            self.lock.unlock()
        }
    }
    
    /// Execute a task if constraints are met
    /// - Parameters:
    ///   - task: The task to execute
    ///   - ignoreConstraints: Whether to ignore execution constraints
    private func executeTask(task: BackgroundTask, ignoreConstraints: Bool = false) {
        // Check constraints unless ignoring
        if !ignoreConstraints {
            // Check if task can run with current battery state
            if batteryState.isLow && !batteryState.isCharging && !task.runWhenLowBattery {
                Logger.debug("Skipping task \(task.identifier) due to low battery")
                scheduleTimer(for: task) // Reschedule for later
                return
            }
            
            // Check if task can run with current network state
            let networkConnected = networkState == .wifi || networkState == .cellular || networkState == .ethernet
            if task.requiresConnectivity && !networkConnected {
                Logger.debug("Skipping task \(task.identifier) due to no network connectivity")
                scheduleTimer(for: task) // Reschedule for later
                return
            }
        }
        
        Logger.debug("Executing task: \(task.identifier)")
        
        // Begin background task for iOS
        #if os(iOS) || os(tvOS)
        let bgTaskId = beginBackgroundTask(for: task.identifier)
        #endif
        
        // Execute the task
        task.execute { [weak self] success in
            guard let self = self else { return }
            
            Logger.debug("Task \(task.identifier) completed with success: \(success)")
            
            // Reschedule the task
            self.lock.lock()
            if self.tasks[task.identifier] != nil {
                self.scheduleTimer(for: task)
            }
            self.lock.unlock()
            
            // End background task for iOS
            #if os(iOS) || os(tvOS)
            self.endBackgroundTask(identifier: task.identifier, taskId: bgTaskId)
            #endif
        }
    }
    
    /// Check for tasks that were delayed due to constraints
    private func checkForDelayedTasks() {
        lock.lock()
        let currentTasks = tasks.values
        lock.unlock()
        
        // Check each task for delayed execution
        for task in currentTasks {
            if let lastExecution = task.lastExecutionTime {
                let elapsedMs = Date().timeIntervalSince(lastExecution) * 1000.0
                
                // If the task should have executed already, execute it now
                if elapsedMs >= Double(task.intervalMs) {
                    Logger.debug("Executing delayed task: \(task.identifier)")
                    executeTask(task: task)
                }
            } else {
                // Task has never executed, schedule it now
                scheduleTimer(for: task)
            }
        }
    }
    
    /// Cancel a task internally
    /// - Parameter identifier: The task identifier
    /// - Returns: Whether the task was cancelled
    private func cancelTaskInternal(identifier: String) -> Bool {
        // Cancel timer
        if let timer = timers[identifier] {
            timer.invalidate()
            timers[identifier] = nil
        }
        
        // Remove task
        let taskRemoved = tasks.removeValue(forKey: identifier) != nil
        
        // End any background task (iOS)
        #if os(iOS) || os(tvOS)
        if let bgTaskId = backgroundTaskIds[identifier] {
            UIApplication.shared.endBackgroundTask(bgTaskId)
            backgroundTaskIds[identifier] = nil
        }
        #endif
        
        if taskRemoved {
            Logger.debug("Cancelled task: \(identifier)")
        }
        
        return taskRemoved
    }
    
    /// Cancel all tasks
    private func cancelAllTasks() {
        lock.lock()
        defer { lock.unlock() }
        
        // Cancel all timers
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        
        // Remove all tasks
        tasks.removeAll()
        
        // End all background tasks (iOS)
        #if os(iOS) || os(tvOS)
        for (identifier, bgTaskId) in backgroundTaskIds {
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }
        backgroundTaskIds.removeAll()
        #endif
        
        Logger.debug("Cancelled all tasks")
    }
    
    // MARK: - iOS Background Task Handling
    
    #if os(iOS) || os(tvOS)
    /// Begin a background task
    /// - Parameter identifier: The task identifier
    /// - Returns: The background task identifier
    private func beginBackgroundTask(for identifier: String) -> UIBackgroundTaskIdentifier {
        lock.lock()
        defer { lock.unlock() }
        
        // End existing background task if any
        if let existingTaskId = backgroundTaskIds[identifier] {
            UIApplication.shared.endBackgroundTask(existingTaskId)
            backgroundTaskIds[identifier] = nil
        }
        
        // Begin new background task
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "CFTask_\(identifier)") { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            if let taskId = self.backgroundTaskIds[identifier] {
                UIApplication.shared.endBackgroundTask(taskId)
                self.backgroundTaskIds[identifier] = nil
            }
            self.lock.unlock()
        }
        
        backgroundTaskIds[identifier] = taskId
        
        return taskId
    }
    
    /// End a background task
    /// - Parameters:
    ///   - identifier: The task identifier
    ///   - taskId: The background task identifier
    private func endBackgroundTask(identifier: String, taskId: UIBackgroundTaskIdentifier) {
        lock.lock()
        defer { lock.unlock() }
        
        if let currentTaskId = backgroundTaskIds[identifier], currentTaskId == taskId {
            UIApplication.shared.endBackgroundTask(taskId)
            backgroundTaskIds[identifier] = nil
        }
    }
    #endif
} 