package customfit.ai.kotlinclient.core.session

import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.utils.CacheManager
import customfit.ai.kotlinclient.utils.CachePolicy
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * Configuration for session management
 */
data class SessionConfig(
    /** Maximum session duration in milliseconds (default: 60 minutes) */
    val maxSessionDurationMs: Long = TimeUnit.MINUTES.toMillis(60),
    
    /** Minimum session duration in milliseconds (default: 5 minutes) */
    val minSessionDurationMs: Long = TimeUnit.MINUTES.toMillis(5),
    
    /** Background threshold - rotate if app was in background longer than this (default: 15 minutes) */
    val backgroundThresholdMs: Long = TimeUnit.MINUTES.toMillis(15),
    
    /** Force rotation on app restart */
    val rotateOnAppRestart: Boolean = true,
    
    /** Force rotation on user authentication changes */
    val rotateOnAuthChange: Boolean = true,
    
    /** Session ID prefix for identification */
    val sessionIdPrefix: String = "cf_session",
    
    /** Enable automatic rotation based on time */
    val enableTimeBasedRotation: Boolean = true
)

/**
 * Represents a session with metadata
 */
data class SessionData(
    val sessionId: String,
    val createdAt: Long,
    val lastActiveAt: Long,
    val appStartTime: Long,
    val rotationReason: String? = null
)

/**
 * Reasons for session rotation
 */
enum class RotationReason(val description: String) {
    APP_START("Application started"),
    MAX_DURATION_EXCEEDED("Maximum session duration exceeded"),
    BACKGROUND_TIMEOUT("App was in background too long"),
    AUTH_CHANGE("User authentication changed"),
    MANUAL_ROTATION("Manually triggered rotation"),
    NETWORK_CHANGE("Network connectivity changed"),
    STORAGE_ERROR("Session storage error occurred")
}

/**
 * Session rotation listener interface
 */
interface SessionRotationListener {
    fun onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason)
    fun onSessionRestored(sessionId: String)
    fun onSessionError(error: String)
}

/**
 * Manages session IDs with time-based rotation strategy
 * 
 * Strategy 1: Time-Based Rotation
 * - Rotates every 30-60 minutes of active use
 * - Rotates on app restart/cold start
 * - Rotates when app returns from background after >15 minutes
 * - Rotates on user authentication changes
 */
class SessionManager private constructor(
    private val config: SessionConfig
) {
    companion object {
        private const val SESSION_STORAGE_KEY = "cf_current_session"
        private const val LAST_APP_START_KEY = "cf_last_app_start"
        private const val BACKGROUND_TIMESTAMP_KEY = "cf_background_timestamp"
        
        @Volatile
        private var instance: SessionManager? = null
        private val mutex = Mutex()
        
        /**
         * Initialize the SessionManager singleton
         */
        suspend fun initialize(config: SessionConfig = SessionConfig()): CFResult<SessionManager> {
            return mutex.withLock {
                if (instance == null) {
                    try {
                        val manager = SessionManager(config)
                        manager.initializeSession()
                        instance = manager
                        Timber.i("🔄 SessionManager initialized with config: $config")
                        CFResult.success(manager)
                    } catch (e: Exception) {
                        Timber.e("Failed to initialize SessionManager: ${e.message}")
                        CFResult.error("Failed to initialize SessionManager: ${e.message}", e, category = ErrorHandler.ErrorCategory.INTERNAL)
                    }
                } else {
                    CFResult.success(instance!!)
                }
            }
        }
        
        /**
         * Get the current SessionManager instance
         */
        fun getInstance(): SessionManager? = instance
        
        /**
         * Shutdown the SessionManager
         */
        suspend fun shutdown() {
            mutex.withLock {
                instance?.let { manager ->
                    manager.listeners.clear()
                    Timber.i("🔄 SessionManager shutdown")
                }
                instance = null
            }
        }
    }
    
    private var currentSession: SessionData? = null
    private val sessionMutex = Mutex()
    private val listeners = mutableListOf<SessionRotationListener>()
    private var lastBackgroundTime: Long = 0L
    private val cacheManager = CacheManager.getInstance()
    
    /**
     * Initialize session on startup
     */
    private suspend fun initializeSession() {
        sessionMutex.withLock {
            val currentAppStart = System.currentTimeMillis()
            val lastAppStart = getLastAppStartTime()
            
            // Check if this is a new app start
            val isNewAppStart = lastAppStart == 0L || (currentAppStart - lastAppStart) > config.minSessionDurationMs
            
            if (isNewAppStart && config.rotateOnAppRestart) {
                // App restart - force new session
                rotateSession(RotationReason.APP_START)
                storeLastAppStartTime(currentAppStart)
            } else {
                // Try to restore existing session
                restoreOrCreateSession()
            }
        }
    }
    
    /**
     * Get the current session ID
     */
    suspend fun getCurrentSessionId(): String {
        return sessionMutex.withLock {
            currentSession?.sessionId ?: run {
                // No current session, create one
                rotateSession(RotationReason.APP_START)
                currentSession!!.sessionId
            }
        }
    }
    
    /**
     * Get current session data
     */
    suspend fun getCurrentSession(): SessionData? {
        return sessionMutex.withLock {
            currentSession?.copy()
        }
    }
    
    /**
     * Update session activity (call this on user interactions)
     */
    suspend fun updateActivity() {
        sessionMutex.withLock {
            currentSession?.let { session ->
                val now = System.currentTimeMillis()
                
                // Check if session needs rotation due to max duration
                if (config.enableTimeBasedRotation && shouldRotateForMaxDuration(session, now)) {
                    rotateSession(RotationReason.MAX_DURATION_EXCEEDED)
                } else {
                    // Update last active time
                    currentSession = session.copy(lastActiveAt = now)
                    storeCurrentSession()
                }
            }
        }
    }
    
    /**
     * Handle app going to background
     */
    suspend fun onAppBackground() {
        sessionMutex.withLock {
            lastBackgroundTime = System.currentTimeMillis()
            storeBackgroundTime(lastBackgroundTime)
            Timber.d("🔄 App went to background at: $lastBackgroundTime")
        }
    }
    
    /**
     * Handle app coming to foreground
     */
    suspend fun onAppForeground() {
        sessionMutex.withLock {
            val now = System.currentTimeMillis()
            val backgroundDuration = if (lastBackgroundTime > 0) now - lastBackgroundTime else 0
            
            Timber.d("🔄 App came to foreground after ${backgroundDuration}ms in background")
            
            // Check if we need to rotate due to background timeout
            if (backgroundDuration > config.backgroundThresholdMs) {
                rotateSession(RotationReason.BACKGROUND_TIMEOUT)
            } else {
                // Just update activity
                updateActivity()
            }
            
            lastBackgroundTime = 0L
        }
    }
    
    /**
     * Handle user authentication changes
     */
    suspend fun onAuthenticationChange(userId: String?) {
        if (config.rotateOnAuthChange) {
            sessionMutex.withLock {
                Timber.i("🔄 Authentication changed for user: $userId")
                rotateSession(RotationReason.AUTH_CHANGE)
            }
        }
    }
    
    /**
     * Handle network connectivity changes
     */
    suspend fun onNetworkChange() {
        sessionMutex.withLock {
            Timber.d("🔄 Network connectivity changed")
            // Optional: rotate on network change for high-security scenarios
            // rotateSession(RotationReason.NETWORK_CHANGE)
        }
    }
    
    /**
     * Manually force session rotation
     */
    suspend fun forceRotation(): String {
        return sessionMutex.withLock {
            rotateSession(RotationReason.MANUAL_ROTATION)
            currentSession!!.sessionId
        }
    }
    
    /**
     * Add a session rotation listener
     */
    fun addListener(listener: SessionRotationListener) {
        listeners.add(listener)
    }
    
    /**
     * Remove a session rotation listener
     */
    fun removeListener(listener: SessionRotationListener) {
        listeners.remove(listener)
    }
    
    /**
     * Get session statistics
     */
    suspend fun getSessionStats(): Map<String, Any> {
        return sessionMutex.withLock {
            val session = currentSession
            mapOf(
                "hasActiveSession" to (session != null),
                "sessionId" to (session?.sessionId ?: "none"),
                "sessionAge" to (session?.let { System.currentTimeMillis() - it.createdAt } ?: 0),
                "lastActiveAge" to (session?.let { System.currentTimeMillis() - it.lastActiveAt } ?: 0),
                "backgroundTime" to lastBackgroundTime,
                "config" to config,
                "listenersCount" to listeners.size
            )
        }
    }
    
    // Private helper methods
    
    private suspend fun restoreOrCreateSession() {
        val storedSession = loadStoredSession()
        val now = System.currentTimeMillis()
        
        if (storedSession != null && isSessionValid(storedSession, now)) {
            currentSession = storedSession.copy(lastActiveAt = now)
            storeCurrentSession()
            notifySessionRestored(storedSession.sessionId)
            Timber.i("🔄 Restored existing session: ${storedSession.sessionId}")
        } else {
            rotateSession(RotationReason.APP_START)
        }
    }
    
    private suspend fun rotateSession(reason: RotationReason) {
        val oldSessionId = currentSession?.sessionId
        val newSessionId = generateSessionId()
        val now = System.currentTimeMillis()
        
        currentSession = SessionData(
            sessionId = newSessionId,
            createdAt = now,
            lastActiveAt = now,
            appStartTime = now,
            rotationReason = reason.description
        )
        
        storeCurrentSession()
        notifySessionRotated(oldSessionId, newSessionId, reason)
        
        Timber.i("🔄 Session rotated: $oldSessionId -> $newSessionId (${reason.description})")
    }
    
    private fun generateSessionId(): String {
        val uuid = UUID.randomUUID().toString().replace("-", "")
        val timestamp = System.currentTimeMillis()
        return "${config.sessionIdPrefix}_${timestamp}_${uuid.substring(0, 8)}"
    }
    
    private fun shouldRotateForMaxDuration(session: SessionData, currentTime: Long): Boolean {
        val sessionAge = currentTime - session.createdAt
        return sessionAge >= config.maxSessionDurationMs
    }
    
    private fun isSessionValid(session: SessionData, currentTime: Long): Boolean {
        val sessionAge = currentTime - session.createdAt
        val inactiveTime = currentTime - session.lastActiveAt
        
        // Session is valid if:
        // 1. Not older than max duration
        // 2. Has been active recently (within background threshold)
        return sessionAge < config.maxSessionDurationMs && 
               inactiveTime < config.backgroundThresholdMs
    }
    
    // Storage operations
    
    private suspend fun storeCurrentSession() {
        currentSession?.let { session ->
            try {
                val success = cacheManager.put(
                    key = SESSION_STORAGE_KEY,
                    value = sessionToJson(session),
                    policy = CachePolicy(ttlSeconds = TimeUnit.DAYS.toSeconds(30).toInt(), persist = true) // 30 days TTL
                )
                if (!success) {
                    Timber.e("Failed to store session in cache")
                    notifySessionError("Failed to store session in cache")
                }
            } catch (e: Exception) {
                Timber.e("Failed to store session: ${e.message}")
                notifySessionError("Failed to store session: ${e.message}")
            }
        }
    }
    
    private suspend fun loadStoredSession(): SessionData? {
        return try {
            val sessionJson = cacheManager.get<String>(SESSION_STORAGE_KEY)
            sessionJson?.let { jsonToSession(it) }
        } catch (e: Exception) {
            Timber.e("Failed to load stored session: ${e.message}")
            null
        }
    }
    
    private suspend fun storeLastAppStartTime(timestamp: Long) {
        try {
            val success = cacheManager.put(
                key = LAST_APP_START_KEY,
                value = timestamp.toString(),
                policy = CachePolicy(ttlSeconds = TimeUnit.DAYS.toSeconds(365).toInt(), persist = true) // 1 year TTL
            )
            if (!success) {
                Timber.e("Failed to store app start time")
            }
        } catch (e: Exception) {
            Timber.e("Failed to store app start time: ${e.message}")
        }
    }
    
    private suspend fun getLastAppStartTime(): Long {
        return try {
            val timestampStr = cacheManager.get<String>(LAST_APP_START_KEY)
            timestampStr?.toLongOrNull() ?: 0L
        } catch (e: Exception) {
            Timber.e("Failed to get last app start time: ${e.message}")
            0L
        }
    }
    
    private suspend fun storeBackgroundTime(timestamp: Long) {
        try {
            val success = cacheManager.put(
                key = BACKGROUND_TIMESTAMP_KEY,
                value = timestamp.toString(),
                policy = CachePolicy(ttlSeconds = TimeUnit.HOURS.toSeconds(24).toInt(), persist = false) // 24 hours TTL, memory only
            )
            if (!success) {
                Timber.e("Failed to store background time")
            }
        } catch (e: Exception) {
            Timber.e("Failed to store background time: ${e.message}")
        }
    }
    
    // JSON serialization helpers
    
    private fun sessionToJson(session: SessionData): String {
        return """
        {
            "sessionId": "${session.sessionId}",
            "createdAt": ${session.createdAt},
            "lastActiveAt": ${session.lastActiveAt},
            "appStartTime": ${session.appStartTime},
            "rotationReason": "${session.rotationReason ?: ""}"
        }
        """.trimIndent()
    }
    
    private fun jsonToSession(json: String): SessionData? {
        return try {
            // Simple JSON parsing - in production, use a proper JSON library
            val sessionIdMatch = Regex(""""sessionId":\s*"([^"]+)"""").find(json)
            val createdAtMatch = Regex(""""createdAt":\s*(\d+)""").find(json)
            val lastActiveAtMatch = Regex(""""lastActiveAt":\s*(\d+)""").find(json)
            val appStartTimeMatch = Regex(""""appStartTime":\s*(\d+)""").find(json)
            val rotationReasonMatch = Regex(""""rotationReason":\s*"([^"]*)"""").find(json)
            
            if (sessionIdMatch != null && createdAtMatch != null && lastActiveAtMatch != null && appStartTimeMatch != null) {
                SessionData(
                    sessionId = sessionIdMatch.groupValues[1],
                    createdAt = createdAtMatch.groupValues[1].toLong(),
                    lastActiveAt = lastActiveAtMatch.groupValues[1].toLong(),
                    appStartTime = appStartTimeMatch.groupValues[1].toLong(),
                    rotationReason = rotationReasonMatch?.groupValues?.get(1)?.takeIf { it.isNotEmpty() }
                )
            } else null
        } catch (e: Exception) {
            Timber.e("Failed to parse session JSON: ${e.message}")
            null
        }
    }
    
    // Notification helpers
    
    private fun notifySessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        listeners.forEach { listener ->
            try {
                listener.onSessionRotated(oldSessionId, newSessionId, reason)
            } catch (e: Exception) {
                Timber.e("Error notifying session rotation listener: ${e.message}")
            }
        }
    }
    
    private fun notifySessionRestored(sessionId: String) {
        listeners.forEach { listener ->
            try {
                listener.onSessionRestored(sessionId)
            } catch (e: Exception) {
                Timber.e("Error notifying session restored listener: ${e.message}")
            }
        }
    }
    
    private fun notifySessionError(error: String) {
        listeners.forEach { listener ->
            try {
                listener.onSessionError(error)
            } catch (e: Exception) {
                Timber.e("Error notifying session error listener: ${e.message}")
            }
        }
    }
} 