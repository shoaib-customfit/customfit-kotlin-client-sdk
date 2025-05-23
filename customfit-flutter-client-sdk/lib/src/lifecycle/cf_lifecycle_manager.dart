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

  /// Whether the lifecycle manager has been initialized
  bool _isInitialized = false;

  /// Lock for initialization and shutdown
  final Object _initLock = Object();

  /// Singleton instance
  static CFLifecycleManager? _instance;

  /// Create a new lifecycle manager (private constructor)
  CFLifecycleManager._();

  /// Initialize the lifecycle manager with configuration and user.
  /// This should be called when your application starts.
  Future<void> initialize(CFConfig config, CFUser user) async {
    return synchronizedAsync(_initLock, () async {
      try {
        if (!_isInitialized) {
          Logger.i('Initializing CFClient singleton through lifecycle manager');
          await CFClient.init(config, user);
          _isInitialized = true;
          Logger.i('CFClient singleton initialized through lifecycle manager');
        }
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Failed to initialize CFClient singleton",
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
      final client = CFClient.getInstance();
      client?.setOffline(true);
      Logger.d('CFClient paused through lifecycle manager');
    }
  }

  /// Restores the client to online mode and increments app launch count.
  /// This should be called when your application comes to the foreground.
  void resume() {
    if (_isInitialized) {
      final client = CFClient.getInstance();
      client?.setOffline(false);
      client?.incrementAppLaunchCount();
      Logger.d('CFClient resumed through lifecycle manager');
    }
  }

  /// Clean up resources and shut down the client.
  /// This is automatically called when the app is terminating.
  Future<void> cleanup() async {
    return synchronizedAsync(_initLock, () async {
      if (_isInitialized) {
        Logger.i('Cleaning up CFClient singleton through lifecycle manager');
        try {
          await CFClient.shutdownSingleton();
          _isInitialized = false;
          Logger.i('CFClient singleton cleaned up through lifecycle manager');
        } catch (e) {
          ErrorHandler.handleException(
            e,
            "Error during CFClient singleton cleanup",
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      }
    });
  }

  /// Get the current CFClient instance
  CFClient? getClient() => CFClient.getInstance();

  /// Returns whether the lifecycle manager has been initialized
  bool isInitialized() => _isInitialized;

  /// Initialize the CFClient with lifecycle management using singleton pattern.
  /// This should be called when your application starts.
  static Future<void> initializeInstance(CFConfig config, CFUser user) async {
    _instance ??= CFLifecycleManager._();
    await _instance!.initialize(config, user);
    Logger.i('CFLifecycleManager initialized with singleton pattern');
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
  /// Returns the singleton instance if initialized, null otherwise.
  static CFClient? getInstanceClient() => CFClient.getInstance();

  /// Check if the CFClient singleton is initialized.
  static bool isClientInitialized() => CFClient.isInitialized();
}
