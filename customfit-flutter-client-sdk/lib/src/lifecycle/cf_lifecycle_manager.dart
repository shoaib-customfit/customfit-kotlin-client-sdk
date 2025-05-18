import 'dart:async';

import '../client/cf_client.dart';
import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../../logging/logger.dart';
import '../core/util/synchronization.dart';

/// Manages the lifecycle of the CFClient instance.
/// Handles initialization, pause/resume, and shutdown.
class CFLifecycleManager {
  static const String _source = "CFLifecycleManager";

  /// The managed CFClient instance
  CFClient? _client;

  /// Whether the lifecycle manager has been initialized
  bool _isInitialized = false;

  /// Lock for initialization and shutdown
  final Object _initLock = Object();

  /// Singleton instance
  static CFLifecycleManager? _instance;

  /// Create a new lifecycle manager (private constructor)
  CFLifecycleManager._(CFConfig config, CFUser user) {
    synchronized(_initLock, () {
      if (!_isInitialized) {
        _client = CFClient.create(config, user);
        _isInitialized = true;
      }
    });
  }

  /// Initialize the lifecycle manager with configuration and user.
  /// This should be called when your application starts.
  Future<void> initialize() async {
    return synchronizedAsync(_initLock, () async {
      try {
        Logger.i('Initializing CFClient through lifecycle manager');
        _isInitialized = true;
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Failed to initialize CFClient",
          source: _source,
          severity: ErrorSeverity.high,
        );
        rethrow;
      }
    });
  }

  /// Puts the client in offline mode when the app is in the background.
  /// This should be called when your application moves to the background.
  void pause() {
    if (_isInitialized) {
      _client?.setOffline(true);
      Logger.d('CFClient paused through lifecycle manager');
    }
  }

  /// Restores the client to online mode and increments app launch count.
  /// This should be called when your application comes to the foreground.
  void resume() {
    if (_isInitialized) {
      _client?.setOffline(false);
      _client?.incrementAppLaunchCount();
      Logger.d('CFClient resumed through lifecycle manager');
    }
  }

  /// Clean up resources and shut down the client.
  /// This is automatically called when the app is terminating.
  Future<void> cleanup() async {
    return synchronizedAsync(_initLock, () async {
      if (_isInitialized) {
        Logger.i('Cleaning up CFClient through lifecycle manager');
        try {
          await _client?.shutdown();
          _client = null;
          _isInitialized = false;
        } catch (e) {
          ErrorHandler.handleException(
            e,
            "Error during CFClient cleanup",
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      }
    });
  }

  /// Get the current CFClient instance
  CFClient? getClient() => _client;

  /// Returns whether the lifecycle manager has been initialized
  bool isInitialized() => _isInitialized;

  /// Initialize the CFClient with lifecycle management.
  /// This should be called when your application starts.
  static Future<void> initializeInstance(CFConfig config, CFUser user) async {
    if (_instance == null) {
      _instance = CFLifecycleManager._(config, user);
      await _instance!.initialize();
      Logger.i('CFLifecycleManager initialized');
    } else {
      Logger.w('CFLifecycleManager already initialized');
    }
  }

  /// Puts the client in offline mode.
  /// This should be called when your application moves to the background.
  static void pauseInstance() {
    _instance?.pause();
  }

  /// Restores the client to online mode.
  /// This should be called when your application comes to the foreground.
  static void resumeInstance() {
    _instance?.resume();
  }

  /// Clean up resources and shut down the client.
  /// This should be called when your application is terminating.
  static Future<void> cleanupInstance() async {
    final instance = _instance;
    if (instance != null) {
      await instance.cleanup();
      _instance = null;
    }
  }

  /// Get the current CFClient instance.
  /// Returns null if the lifecycle manager hasn't been initialized.
  static CFClient? getInstanceClient() => _instance?.getClient();
}
