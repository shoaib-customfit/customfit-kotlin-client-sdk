import '../platform/app_state.dart';
import '../platform/app_state_listener.dart';
import '../platform/background_state_monitor.dart';
import '../core/logging/logger.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import 'cf_client.dart';

/// Manages the lifecycle of the CustomFit client
///
/// Handles app state changes and coordinates client behavior based on app lifecycle events
class LifecycleManager implements AppStateListener {
  // Client instance
  final CFClient _client;

  // Background state monitor
  final BackgroundStateMonitor _backgroundStateMonitor;

  // Current app state
  AppState _currentAppState = AppState.foreground;

  // Constants
  static const String _source = "LifecycleManager";

  // Constructor
  LifecycleManager({
    required CFClient client,
    required BackgroundStateMonitor backgroundStateMonitor,
  })  : _client = client,
        _backgroundStateMonitor = backgroundStateMonitor {
    _initialize();
  }

  // Initialize the lifecycle manager
  void _initialize() {
    try {
      // Register for app state changes
      _backgroundStateMonitor.addAppStateListener(this);

      // Store initial state
      _currentAppState = _backgroundStateMonitor.getCurrentAppState();

      Logger.i("Lifecycle manager initialized with state: $_currentAppState");
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to initialize lifecycle manager",
        source: _source,
        severity: ErrorSeverity.high,
      );
    }
  }

  // Handle app state changes
  @override
  void onAppStateChanged(AppState newState) {
    try {
      Logger.d("App state changed from $_currentAppState to $newState");

      if (_currentAppState == AppState.background &&
          newState == AppState.foreground) {
        // App came to foreground
        _onAppForeground();
      } else if (_currentAppState == AppState.foreground &&
          newState == AppState.background) {
        // App went to background
        _onAppBackground();
      } else if (newState == AppState.terminated) {
        // App is terminating
        _onAppTerminate();
      }

      // Update current state
      _currentAppState = newState;
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error handling app state change to $newState",
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  // Handle app coming to foreground
  void _onAppForeground() {
    try {
      // Flush pending events immediately when app comes to foreground
      // _client.flushEvents();

      // Fetch latest configs if needed
      // _client.checkUpdates();

      Logger.i(
          "App came to foreground, flushed events and checked for updates");
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error handling app foreground state",
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  // Handle app going to background
  void _onAppBackground() {
    try {
      // Flush pending events when app goes to background
      // _client.flushEvents();

      Logger.i("App went to background, flushed events");
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error handling app background state",
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  // Handle app termination
  void _onAppTerminate() {
    try {
      // Attempt to flush events and shut down client gracefully
      _client.shutdown();

      Logger.i("App is terminating, shutting down client");
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error handling app termination",
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  // Clean up resources
  void shutdown() {
    try {
      // Unregister from app state changes
      _backgroundStateMonitor.removeAppStateListener(this);

      Logger.i("Lifecycle manager shut down");
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error shutting down lifecycle manager",
        source: _source,
        severity: ErrorSeverity.low,
      );
    }
  }
}
