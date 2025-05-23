import Foundation

// MARK: - Session Configuration

/// Configuration for session management
public struct SessionConfig {
    /// Maximum session duration in milliseconds (default: 60 minutes)
    public let maxSessionDurationMs: Int64
    
    /// Minimum session duration in milliseconds (default: 5 minutes)
    public let minSessionDurationMs: Int64
    
    /// Background threshold - rotate if app was in background longer than this (default: 15 minutes)
    public let backgroundThresholdMs: Int64
    
    /// Force rotation on app restart
    public let rotateOnAppRestart: Bool
    
    /// Force rotation on user authentication changes
    public let rotateOnAuthChange: Bool
    
    /// Session ID prefix for identification
    public let sessionIdPrefix: String
    
    /// Enable automatic rotation based on time
    public let enableTimeBasedRotation: Bool
    
    public init(
        maxSessionDurationMs: Int64 = 60 * 60 * 1000, // 60 minutes
        minSessionDurationMs: Int64 = 5 * 60 * 1000,  // 5 minutes
        backgroundThresholdMs: Int64 = 15 * 60 * 1000, // 15 minutes
        rotateOnAppRestart: Bool = true,
        rotateOnAuthChange: Bool = true,
        sessionIdPrefix: String = "cf_session",
        enableTimeBasedRotation: Bool = true
    ) {
        self.maxSessionDurationMs = maxSessionDurationMs
        self.minSessionDurationMs = minSessionDurationMs
        self.backgroundThresholdMs = backgroundThresholdMs
        self.rotateOnAppRestart = rotateOnAppRestart
        self.rotateOnAuthChange = rotateOnAuthChange
        self.sessionIdPrefix = sessionIdPrefix
        self.enableTimeBasedRotation = enableTimeBasedRotation
    }
}

// MARK: - Session Data

/// Represents a session with metadata
public struct SessionData {
    public let sessionId: String
    public let createdAt: Int64
    public let lastActiveAt: Int64
    public let appStartTime: Int64
    public let rotationReason: String?
    
    public init(sessionId: String, createdAt: Int64, lastActiveAt: Int64, appStartTime: Int64, rotationReason: String? = nil) {
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.appStartTime = appStartTime
        self.rotationReason = rotationReason
    }
}

// MARK: - Rotation Reason

/// Reasons for session rotation
public enum RotationReason: String, CaseIterable {
    case appStart = "Application started"
    case maxDurationExceeded = "Maximum session duration exceeded"
    case backgroundTimeout = "App was in background too long"
    case authChange = "User authentication changed"
    case manualRotation = "Manually triggered rotation"
    case networkChange = "Network connectivity changed"
    case storageError = "Session storage error occurred"
    
    public var description: String {
        return self.rawValue
    }
}

// MARK: - Session Rotation Listener

/// Session rotation listener protocol
public protocol SessionRotationListener: AnyObject {
    func onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason)
    func onSessionRestored(sessionId: String)
    func onSessionError(error: String)
}

// MARK: - Session Manager

/// Manages session IDs with time-based rotation strategy
///
/// Strategy 1: Time-Based Rotation
/// - Rotates every 30-60 minutes of active use
/// - Rotates on app restart/cold start
/// - Rotates when app returns from background after >15 minutes
/// - Rotates on user authentication changes
public class SessionManager {
    
    // MARK: - Constants
    
    private static let SESSION_STORAGE_KEY = "cf_current_session"
    private static let LAST_APP_START_KEY = "cf_last_app_start"
    private static let BACKGROUND_TIMESTAMP_KEY = "cf_background_timestamp"
    
    // MARK: - Singleton
    
    private static var _instance: SessionManager?
    private static let instanceLock = NSLock()
    
    /// Initialize the SessionManager singleton
    /// - Parameter config: Session configuration
    /// - Returns: CFResult containing SessionManager or error
    public static func initialize(config: SessionConfig = SessionConfig()) -> CFResult<SessionManager> {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        
        if let existingInstance = _instance {
            Logger.info("🔄 SessionManager already initialized, returning existing instance")
            return .success(value: existingInstance)
        }
        
        do {
            let manager = SessionManager(config: config)
            try manager.initializeSession()
            _instance = manager
            Logger.info("🔄 SessionManager initialized with config: \(config)")
            return .success(value: manager)
        } catch {
            Logger.error("Failed to initialize SessionManager: \(error.localizedDescription)")
            return .error(message: "Failed to initialize SessionManager: \(error.localizedDescription)", error: error, category: .state)
        }
    }
    
    /// Get the current SessionManager instance
    /// - Returns: Current SessionManager instance or nil
    public static func getInstance() -> SessionManager? {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return _instance
    }
    
    /// Shutdown the SessionManager
    public static func shutdown() {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        
        if let manager = _instance {
            manager.listeners.removeAll()
            Logger.info("🔄 SessionManager shutdown")
        }
        _instance = nil
    }
    
    // MARK: - Properties
    
    private let config: SessionConfig
    private var currentSession: SessionData?
    private let sessionLock = NSLock()
    private var listeners: [ListenerWrapper] = []
    private var lastBackgroundTime: Int64 = 0
    
    // MARK: - Initialization
    
    private init(config: SessionConfig) {
        self.config = config
    }
    
    /// Initialize session on startup
    private func initializeSession() throws {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        let currentAppStart = getCurrentTimeMs()
        let lastAppStart = getLastAppStartTime()
        
        // Check if this is a new app start
        let isNewAppStart = lastAppStart == 0 || (currentAppStart - lastAppStart) > config.minSessionDurationMs
        
        if isNewAppStart && config.rotateOnAppRestart {
            // App restart - force new session
            rotateSession(reason: .appStart)
            storeLastAppStartTime(timestamp: currentAppStart)
        } else {
            // Try to restore existing session
            restoreOrCreateSession()
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current session ID
    /// - Returns: Current session ID
    public func getCurrentSessionId() -> String {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        if let session = currentSession {
            return session.sessionId
        } else {
            // No current session, create one
            rotateSession(reason: .appStart)
            return currentSession!.sessionId
        }
    }
    
    /// Get current session data
    /// - Returns: Current session data or nil
    public func getCurrentSession() -> SessionData? {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return currentSession
    }
    
    /// Update session activity (call this on user interactions)
    public func updateActivity() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        guard let session = currentSession else { return }
        
        let now = getCurrentTimeMs()
        
        // Check if session needs rotation due to max duration
        if config.enableTimeBasedRotation && shouldRotateForMaxDuration(session: session, currentTime: now) {
            rotateSession(reason: .maxDurationExceeded)
        } else {
            // Update last active time
            currentSession = SessionData(
                sessionId: session.sessionId,
                createdAt: session.createdAt,
                lastActiveAt: now,
                appStartTime: session.appStartTime,
                rotationReason: session.rotationReason
            )
            storeCurrentSession()
        }
    }
    
    /// Handle app going to background
    public func onAppBackground() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        lastBackgroundTime = getCurrentTimeMs()
        storeBackgroundTime(timestamp: lastBackgroundTime)
        Logger.debug("🔄 App went to background at: \(lastBackgroundTime)")
    }
    
    /// Handle app coming to foreground
    public func onAppForeground() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        let now = getCurrentTimeMs()
        let backgroundDuration = lastBackgroundTime > 0 ? now - lastBackgroundTime : 0
        
        Logger.debug("🔄 App came to foreground after \(backgroundDuration)ms in background")
        
        // Check if we need to rotate due to background timeout
        if backgroundDuration > config.backgroundThresholdMs {
            rotateSession(reason: .backgroundTimeout)
        } else {
            // Just update activity
            updateActivityInternal()
        }
        
        lastBackgroundTime = 0
    }
    
    /// Handle user authentication changes
    /// - Parameter userId: New user ID (nil if user logged out)
    public func onAuthenticationChange(userId: String?) {
        if config.rotateOnAuthChange {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            
            Logger.info("🔄 Authentication changed for user: \(userId ?? "nil")")
            rotateSession(reason: .authChange)
        }
    }
    
    /// Handle network connectivity changes
    public func onNetworkChange() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        Logger.debug("🔄 Network connectivity changed")
        // Optional: rotate on network change for high-security scenarios
        // rotateSession(reason: .networkChange)
    }
    
    /// Manually force session rotation
    /// - Returns: New session ID after rotation
    public func forceRotation() -> String {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        rotateSession(reason: .manualRotation)
        return currentSession!.sessionId
    }
    
    /// Add a session rotation listener
    /// - Parameter listener: Listener to add
    public func addListener(_ listener: SessionRotationListener) {
        // Clean up dead weak references while adding
        listeners = listeners.filter { $0.listener != nil }
        listeners.append(ListenerWrapper(listener: listener))
    }
    
    /// Remove a session rotation listener
    /// - Parameter listener: Listener to remove
    public func removeListener(_ listener: SessionRotationListener) {
        listeners = listeners.filter { wrapper in
            guard let value = wrapper.listener else { return false }
            return !areEqual(value, listener)
        }
    }
    
    /// Get session statistics
    /// - Returns: Dictionary containing session statistics
    public func getSessionStats() -> [String: Any] {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        
        let session = currentSession
        let now = getCurrentTimeMs()
        
        return [
            "hasActiveSession": session != nil,
            "sessionId": session?.sessionId ?? "none",
            "sessionAge": session != nil ? now - session!.createdAt : 0,
            "lastActiveAge": session != nil ? now - session!.lastActiveAt : 0,
            "backgroundTime": lastBackgroundTime,
            "config": configToDictionary(),
            "listenersCount": listeners.filter { $0.listener != nil }.count
        ]
    }
    
    // MARK: - Private Helper Methods
    
    private func restoreOrCreateSession() {
        let storedSession = loadStoredSession()
        let now = getCurrentTimeMs()
        
        if let storedSession = storedSession, isSessionValid(session: storedSession, currentTime: now) {
            currentSession = SessionData(
                sessionId: storedSession.sessionId,
                createdAt: storedSession.createdAt,
                lastActiveAt: now,
                appStartTime: storedSession.appStartTime,
                rotationReason: storedSession.rotationReason
            )
            storeCurrentSession()
            notifySessionRestored(sessionId: storedSession.sessionId)
            Logger.info("🔄 Restored existing session: \(storedSession.sessionId)")
        } else {
            rotateSession(reason: .appStart)
        }
    }
    
    private func rotateSession(reason: RotationReason) {
        let oldSessionId = currentSession?.sessionId
        let newSessionId = generateSessionId()
        let now = getCurrentTimeMs()
        
        currentSession = SessionData(
            sessionId: newSessionId,
            createdAt: now,
            lastActiveAt: now,
            appStartTime: now,
            rotationReason: reason.description
        )
        
        storeCurrentSession()
        notifySessionRotated(oldSessionId: oldSessionId, newSessionId: newSessionId, reason: reason)
        
        Logger.info("🔄 Session rotated: \(oldSessionId ?? "nil") -> \(newSessionId) (\(reason.description))")
    }
    
    private func generateSessionId() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = getCurrentTimeMs()
        let shortUuid = String(uuid.prefix(8))
        return "\(config.sessionIdPrefix)_\(timestamp)_\(shortUuid)"
    }
    
    private func shouldRotateForMaxDuration(session: SessionData, currentTime: Int64) -> Bool {
        let sessionAge = currentTime - session.createdAt
        return sessionAge >= config.maxSessionDurationMs
    }
    
    private func isSessionValid(session: SessionData, currentTime: Int64) -> Bool {
        let sessionAge = currentTime - session.createdAt
        let inactiveTime = currentTime - session.lastActiveAt
        
        // Session is valid if:
        // 1. Not older than max duration
        // 2. Has been active recently (within background threshold)
        return sessionAge < config.maxSessionDurationMs &&
               inactiveTime < config.backgroundThresholdMs
    }
    
    private func updateActivityInternal() {
        guard let session = currentSession else { return }
        
        let now = getCurrentTimeMs()
        
        // Check if session needs rotation due to max duration
        if config.enableTimeBasedRotation && shouldRotateForMaxDuration(session: session, currentTime: now) {
            rotateSession(reason: .maxDurationExceeded)
        } else {
            // Update last active time
            currentSession = SessionData(
                sessionId: session.sessionId,
                createdAt: session.createdAt,
                lastActiveAt: now,
                appStartTime: session.appStartTime,
                rotationReason: session.rotationReason
            )
            storeCurrentSession()
        }
    }
    
    // MARK: - Storage Operations
    
    private func storeCurrentSession() {
        guard let session = currentSession else { return }
        
        do {
            let sessionData = try sessionToData(session: session)
            UserDefaults.standard.set(sessionData, forKey: Self.SESSION_STORAGE_KEY)
            UserDefaults.standard.synchronize()
        } catch {
            Logger.error("Failed to store session: \(error.localizedDescription)")
            notifySessionError(error: "Failed to store session: \(error.localizedDescription)")
        }
    }
    
    private func loadStoredSession() -> SessionData? {
        guard let sessionData = UserDefaults.standard.data(forKey: Self.SESSION_STORAGE_KEY) else {
            return nil
        }
        
        do {
            return try dataToSession(data: sessionData)
        } catch {
            Logger.error("Failed to load stored session: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func storeLastAppStartTime(timestamp: Int64) {
        UserDefaults.standard.set(timestamp, forKey: Self.LAST_APP_START_KEY)
        UserDefaults.standard.synchronize()
    }
    
    private func getLastAppStartTime() -> Int64 {
        return UserDefaults.standard.object(forKey: Self.LAST_APP_START_KEY) as? Int64 ?? 0
    }
    
    private func storeBackgroundTime(timestamp: Int64) {
        UserDefaults.standard.set(timestamp, forKey: Self.BACKGROUND_TIMESTAMP_KEY)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - JSON Serialization
    
    private func sessionToData(session: SessionData) throws -> Data {
        let dictionary: [String: Any] = [
            "sessionId": session.sessionId,
            "createdAt": session.createdAt,
            "lastActiveAt": session.lastActiveAt,
            "appStartTime": session.appStartTime,
            "rotationReason": session.rotationReason ?? ""
        ]
        
        return try JSONSerialization.data(withJSONObject: dictionary, options: [])
    }
    
    private func dataToSession(data: Data) throws -> SessionData {
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "SessionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid session data format"])
        }
        
        guard let sessionId = dictionary["sessionId"] as? String,
              let createdAt = dictionary["createdAt"] as? Int64,
              let lastActiveAt = dictionary["lastActiveAt"] as? Int64,
              let appStartTime = dictionary["appStartTime"] as? Int64 else {
            throw NSError(domain: "SessionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing required session data fields"])
        }
        
        let rotationReason = dictionary["rotationReason"] as? String
        let finalRotationReason = (rotationReason?.isEmpty == false) ? rotationReason : nil
        
        return SessionData(
            sessionId: sessionId,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            appStartTime: appStartTime,
            rotationReason: finalRotationReason
        )
    }
    
    // MARK: - Notification Helpers
    
    private func notifySessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        // Clean up dead weak references
        listeners = listeners.filter { $0.listener != nil }
        
        for wrapper in listeners {
            guard let listener = wrapper.listener else { continue }
            listener.onSessionRotated(oldSessionId: oldSessionId, newSessionId: newSessionId, reason: reason)
        }
    }
    
    private func notifySessionRestored(sessionId: String) {
        // Clean up dead weak references
        listeners = listeners.filter { $0.listener != nil }
        
        for wrapper in listeners {
            guard let listener = wrapper.listener else { continue }
            listener.onSessionRestored(sessionId: sessionId)
        }
    }
    
    private func notifySessionError(error: String) {
        // Clean up dead weak references
        listeners = listeners.filter { $0.listener != nil }
        
        for wrapper in listeners {
            guard let listener = wrapper.listener else { continue }
            listener.onSessionError(error: error)
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentTimeMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    private func configToDictionary() -> [String: Any] {
        return [
            "maxSessionDurationMs": config.maxSessionDurationMs,
            "minSessionDurationMs": config.minSessionDurationMs,
            "backgroundThresholdMs": config.backgroundThresholdMs,
            "rotateOnAppRestart": config.rotateOnAppRestart,
            "rotateOnAuthChange": config.rotateOnAuthChange,
            "sessionIdPrefix": config.sessionIdPrefix,
            "enableTimeBasedRotation": config.enableTimeBasedRotation
        ]
    }
    
    private func areEqual(_ lhs: SessionRotationListener, _ rhs: SessionRotationListener) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - ListenerWrapper Helper

/// Weak wrapper for listeners to prevent retain cycles
private class ListenerWrapper {
    weak var listener: SessionRotationListener?
    
    init(listener: SessionRotationListener) {
        self.listener = listener
    }
} 