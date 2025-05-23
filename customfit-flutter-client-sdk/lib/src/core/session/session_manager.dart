import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../../logging/logger.dart';

// MARK: - Session Configuration

/// Configuration for session management
class SessionConfig {
  /// Maximum session duration in milliseconds (default: 60 minutes)
  final int maxSessionDurationMs;
  
  /// Minimum session duration in milliseconds (default: 5 minutes)
  final int minSessionDurationMs;
  
  /// Background threshold - rotate if app was in background longer than this (default: 15 minutes)
  final int backgroundThresholdMs;
  
  /// Force rotation on app restart
  final bool rotateOnAppRestart;
  
  /// Force rotation on user authentication changes
  final bool rotateOnAuthChange;
  
  /// Session ID prefix for identification
  final String sessionIdPrefix;
  
  /// Enable automatic rotation based on time
  final bool enableTimeBasedRotation;
  
  const SessionConfig({
    this.maxSessionDurationMs = 60 * 60 * 1000, // 60 minutes
    this.minSessionDurationMs = 5 * 60 * 1000,  // 5 minutes
    this.backgroundThresholdMs = 15 * 60 * 1000, // 15 minutes
    this.rotateOnAppRestart = true,
    this.rotateOnAuthChange = true,
    this.sessionIdPrefix = 'cf_session',
    this.enableTimeBasedRotation = true,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'maxSessionDurationMs': maxSessionDurationMs,
      'minSessionDurationMs': minSessionDurationMs,
      'backgroundThresholdMs': backgroundThresholdMs,
      'rotateOnAppRestart': rotateOnAppRestart,
      'rotateOnAuthChange': rotateOnAuthChange,
      'sessionIdPrefix': sessionIdPrefix,
      'enableTimeBasedRotation': enableTimeBasedRotation,
    };
  }
}

// MARK: - Session Data

/// Represents a session with metadata
class SessionData {
  final String sessionId;
  final int createdAt;
  final int lastActiveAt;
  final int appStartTime;
  final String? rotationReason;
  
  const SessionData({
    required this.sessionId,
    required this.createdAt,
    required this.lastActiveAt,
    required this.appStartTime,
    this.rotationReason,
  });
  
  SessionData copyWith({
    String? sessionId,
    int? createdAt,
    int? lastActiveAt,
    int? appStartTime,
    String? rotationReason,
  }) {
    return SessionData(
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      appStartTime: appStartTime ?? this.appStartTime,
      rotationReason: rotationReason ?? this.rotationReason,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
      'appStartTime': appStartTime,
      'rotationReason': rotationReason,
    };
  }
  
  factory SessionData.fromMap(Map<String, dynamic> map) {
    return SessionData(
      sessionId: map['sessionId'] as String,
      createdAt: map['createdAt'] as int,
      lastActiveAt: map['lastActiveAt'] as int,
      appStartTime: map['appStartTime'] as int,
      rotationReason: map['rotationReason'] as String?,
    );
  }
  
  String toJson() => json.encode(toMap());
  
  factory SessionData.fromJson(String source) =>
      SessionData.fromMap(json.decode(source) as Map<String, dynamic>);
}

// MARK: - Rotation Reason

/// Reasons for session rotation
enum RotationReason {
  appStart('Application started'),
  maxDurationExceeded('Maximum session duration exceeded'),
  backgroundTimeout('App was in background too long'),
  authChange('User authentication changed'),
  manualRotation('Manually triggered rotation'),
  networkChange('Network connectivity changed'),
  storageError('Session storage error occurred');
  
  const RotationReason(this.description);
  
  final String description;
}

// MARK: - Session Rotation Listener

/// Session rotation listener interface
abstract class SessionRotationListener {
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason);
  void onSessionRestored(String sessionId);
  void onSessionError(String error);
}

// MARK: - Session Manager

/// Manages session IDs with time-based rotation strategy
///
/// Strategy 1: Time-Based Rotation
/// - Rotates every 30-60 minutes of active use
/// - Rotates on app restart/cold start
/// - Rotates when app returns from background after >15 minutes
/// - Rotates on user authentication changes
class SessionManager {
  
  // MARK: - Constants
  
  static const String _sessionStorageKey = 'cf_current_session';
  static const String _lastAppStartKey = 'cf_last_app_start';
  static const String _backgroundTimestampKey = 'cf_background_timestamp';
  
  // MARK: - Singleton
  
  static SessionManager? _instance;
  static bool _isInitializing = false;
  static Completer<SessionManager>? _initCompleter;
  
  /// Initialize the SessionManager singleton
  static Future<CFResult<SessionManager>> initialize({
    SessionConfig config = const SessionConfig(),
  }) async {
    if (_instance != null) {
      Logger.i('🔄 SessionManager already initialized, returning existing instance');
      return CFResult.success(_instance!);
    }
    
    if (_isInitializing) {
      Logger.i('🔄 SessionManager initialization in progress, waiting...');
      if (_initCompleter != null) {
        try {
          final manager = await _initCompleter!.future;
          return CFResult.success(manager);
        } catch (e) {
          return CFResult.error('SessionManager initialization failed: $e', exception: e);
        }
      }
    }
    
    _isInitializing = true;
    _initCompleter = Completer<SessionManager>();
    
    try {
      final manager = SessionManager._(config);
      await manager._initializeSession();
      
      _instance = manager;
      _isInitializing = false;
      
      Logger.i('🔄 SessionManager initialized with config: ${config.toMap()}');
      
      _initCompleter!.complete(manager);
      return CFResult.success(manager);
    } catch (e) {
      _isInitializing = false;
      _initCompleter = null;
      
      Logger.e('Failed to initialize SessionManager: $e');
      return CFResult.error(
        'Failed to initialize SessionManager: $e',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }
  
  /// Get the current SessionManager instance
  static SessionManager? getInstance() {
    return _instance;
  }
  
  /// Shutdown the SessionManager
  static void shutdown() {
    if (_instance != null) {
      _instance!._listeners.clear();
      Logger.i('🔄 SessionManager shutdown');
    }
    _instance = null;
    _isInitializing = false;
    _initCompleter = null;
  }
  
  // MARK: - Properties
  
  final SessionConfig _config;
  SessionData? _currentSession;
  final List<SessionRotationListener> _listeners = [];
  int _lastBackgroundTime = 0;
  
  // MARK: - Initialization
  
  SessionManager._(this._config);
  
  /// Initialize session on startup
  Future<void> _initializeSession() async {
    final currentAppStart = _getCurrentTimeMs();
    final lastAppStart = await _getLastAppStartTime();
    
    // Check if this is a new app start
    final isNewAppStart = lastAppStart == 0 || 
        (currentAppStart - lastAppStart) > _config.minSessionDurationMs;
    
    if (isNewAppStart && _config.rotateOnAppRestart) {
      // App restart - force new session
      await _rotateSession(RotationReason.appStart);
      await _storeLastAppStartTime(currentAppStart);
    } else {
      // Try to restore existing session
      await _restoreOrCreateSession();
    }
  }
  
  // MARK: - Public Methods
  
  /// Get the current session ID
  String getCurrentSessionId() {
    if (_currentSession != null) {
      return _currentSession!.sessionId;
    } else {
      // No current session, create one
      _rotateSession(RotationReason.appStart);
      return _currentSession!.sessionId;
    }
  }
  
  /// Get current session data
  SessionData? getCurrentSession() {
    return _currentSession;
  }
  
  /// Update session activity (call this on user interactions)
  Future<void> updateActivity() async {
    final session = _currentSession;
    if (session == null) return;
    
    final now = _getCurrentTimeMs();
    
    // Check if session needs rotation due to max duration
    if (_config.enableTimeBasedRotation && 
        _shouldRotateForMaxDuration(session, now)) {
      await _rotateSession(RotationReason.maxDurationExceeded);
    } else {
      // Update last active time
      _currentSession = session.copyWith(lastActiveAt: now);
      await _storeCurrentSession();
    }
  }
  
  /// Handle app going to background
  Future<void> onAppBackground() async {
    _lastBackgroundTime = _getCurrentTimeMs();
    await _storeBackgroundTime(_lastBackgroundTime);
    Logger.d('🔄 App went to background at: $_lastBackgroundTime');
  }
  
  /// Handle app coming to foreground
  Future<void> onAppForeground() async {
    final now = _getCurrentTimeMs();
    final backgroundDuration = _lastBackgroundTime > 0 ? now - _lastBackgroundTime : 0;
    
    Logger.d('🔄 App came to foreground after ${backgroundDuration}ms in background');
    
    // Check if we need to rotate due to background timeout
    if (backgroundDuration > _config.backgroundThresholdMs) {
      await _rotateSession(RotationReason.backgroundTimeout);
    } else {
      // Just update activity
      await _updateActivityInternal();
    }
    
    _lastBackgroundTime = 0;
  }
  
  /// Handle user authentication changes
  Future<void> onAuthenticationChange(String? userId) async {
    if (_config.rotateOnAuthChange) {
      Logger.i('🔄 Authentication changed for user: ${userId ?? "null"}');
      await _rotateSession(RotationReason.authChange);
    }
  }
  
  /// Handle network connectivity changes
  Future<void> onNetworkChange() async {
    Logger.d('🔄 Network connectivity changed');
    // Optional: rotate on network change for high-security scenarios
    // await _rotateSession(RotationReason.networkChange);
  }
  
  /// Manually force session rotation
  Future<String> forceRotation() async {
    await _rotateSession(RotationReason.manualRotation);
    return _currentSession!.sessionId;
  }
  
  /// Add a session rotation listener
  void addListener(SessionRotationListener listener) {
    _listeners.add(listener);
  }
  
  /// Remove a session rotation listener
  void removeListener(SessionRotationListener listener) {
    _listeners.remove(listener);
  }
  
  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    final session = _currentSession;
    final now = _getCurrentTimeMs();
    
    return {
      'hasActiveSession': session != null,
      'sessionId': session?.sessionId ?? 'none',
      'sessionAge': session != null ? now - session.createdAt : 0,
      'lastActiveAge': session != null ? now - session.lastActiveAt : 0,
      'backgroundTime': _lastBackgroundTime,
      'config': _config.toMap(),
      'listenersCount': _listeners.length,
    };
  }
  
  // MARK: - Private Helper Methods
  
  Future<void> _restoreOrCreateSession() async {
    final storedSession = await _loadStoredSession();
    final now = _getCurrentTimeMs();
    
    if (storedSession != null && _isSessionValid(storedSession, now)) {
      _currentSession = storedSession.copyWith(lastActiveAt: now);
      await _storeCurrentSession();
      _notifySessionRestored(storedSession.sessionId);
      Logger.i('🔄 Restored existing session: ${storedSession.sessionId}');
    } else {
      await _rotateSession(RotationReason.appStart);
    }
  }
  
  Future<void> _rotateSession(RotationReason reason) async {
    final oldSessionId = _currentSession?.sessionId;
    final newSessionId = _generateSessionId();
    final now = _getCurrentTimeMs();
    
    _currentSession = SessionData(
      sessionId: newSessionId,
      createdAt: now,
      lastActiveAt: now,
      appStartTime: now,
      rotationReason: reason.description,
    );
    
    await _storeCurrentSession();
    _notifySessionRotated(oldSessionId, newSessionId, reason);
    
    Logger.i('🔄 Session rotated: ${oldSessionId ?? "null"} -> $newSessionId (${reason.description})');
  }
  
  String _generateSessionId() {
    const uuid = Uuid();
    final uuidStr = uuid.v4().replaceAll('-', '');
    final timestamp = _getCurrentTimeMs();
    final shortUuid = uuidStr.substring(0, 8);
    return '${_config.sessionIdPrefix}_${timestamp}_$shortUuid';
  }
  
  bool _shouldRotateForMaxDuration(SessionData session, int currentTime) {
    final sessionAge = currentTime - session.createdAt;
    return sessionAge >= _config.maxSessionDurationMs;
  }
  
  bool _isSessionValid(SessionData session, int currentTime) {
    final sessionAge = currentTime - session.createdAt;
    final inactiveTime = currentTime - session.lastActiveAt;
    
    // Session is valid if:
    // 1. Not older than max duration
    // 2. Has been active recently (within background threshold)
    return sessionAge < _config.maxSessionDurationMs &&
           inactiveTime < _config.backgroundThresholdMs;
  }
  
  Future<void> _updateActivityInternal() async {
    final session = _currentSession;
    if (session == null) return;
    
    final now = _getCurrentTimeMs();
    
    // Check if session needs rotation due to max duration
    if (_config.enableTimeBasedRotation && 
        _shouldRotateForMaxDuration(session, now)) {
      await _rotateSession(RotationReason.maxDurationExceeded);
    } else {
      // Update last active time
      _currentSession = session.copyWith(lastActiveAt: now);
      await _storeCurrentSession();
    }
  }
  
  // MARK: - Storage Operations
  
  Future<void> _storeCurrentSession() async {
    final session = _currentSession;
    if (session == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStorageKey, session.toJson());
    } catch (e) {
      Logger.e('Failed to store session: $e');
      _notifySessionError('Failed to store session: $e');
    }
  }
  
  Future<SessionData?> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionStorageKey);
      
      if (sessionJson != null) {
        return SessionData.fromJson(sessionJson);
      }
      return null;
    } catch (e) {
      Logger.e('Failed to load stored session: $e');
      return null;
    }
  }
  
  Future<void> _storeLastAppStartTime(int timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastAppStartKey, timestamp);
    } catch (e) {
      Logger.e('Failed to store last app start time: $e');
    }
  }
  
  Future<int> _getLastAppStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastAppStartKey) ?? 0;
    } catch (e) {
      Logger.e('Failed to get last app start time: $e');
      return 0;
    }
  }
  
  Future<void> _storeBackgroundTime(int timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_backgroundTimestampKey, timestamp);
    } catch (e) {
      Logger.e('Failed to store background time: $e');
    }
  }
  
  // MARK: - Notification Helpers
  
  void _notifySessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    for (final listener in _listeners) {
      try {
        listener.onSessionRotated(oldSessionId, newSessionId, reason);
      } catch (e) {
        Logger.e('Error in session rotation listener: $e');
      }
    }
  }
  
  void _notifySessionRestored(String sessionId) {
    for (final listener in _listeners) {
      try {
        listener.onSessionRestored(sessionId);
      } catch (e) {
        Logger.e('Error in session restored listener: $e');
      }
    }
  }
  
  void _notifySessionError(String error) {
    for (final listener in _listeners) {
      try {
        listener.onSessionError(error);
      } catch (e) {
        Logger.e('Error in session error listener: $e');
      }
    }
  }
  
  // MARK: - Utility Methods
  
  int _getCurrentTimeMs() {
    return DateTime.now().millisecondsSinceEpoch;
  }
} 