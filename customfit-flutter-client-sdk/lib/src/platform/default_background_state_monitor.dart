import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart' as battery_plus;

import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import 'app_state.dart';
import 'app_state_listener.dart';
import 'background_state_monitor.dart';
import 'battery_state.dart';
import 'battery_state_listener.dart';

/// Default implementation of background state monitoring.
class DefaultBackgroundStateMonitor
    with WidgetsBindingObserver
    implements BackgroundStateMonitor {
  // App state
  AppState _currentAppState = AppState.foreground;

  // Battery state
  BatteryState _currentBatteryState = BatteryState.unknown;
  int _currentBatteryLevel = 100;

  // Listeners
  final List<AppStateListener> _appStateListeners = [];
  final List<BatteryStateListener> _batteryStateListeners = [];

  // Battery plugin
  final battery_plus.Battery _battery = battery_plus.Battery();
  StreamSubscription<battery_plus.BatteryState>? _batteryStateSubscription;

  // Constants
  static const String _source = "DefaultBackgroundStateMonitor";

  DefaultBackgroundStateMonitor() {
    _initialize();
  }

  // Initialize monitoring
  void _initialize() {
    // Register with WidgetsBinding for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Initialize battery monitoring
    _initializeBatteryMonitoring();
  }

  // Initialize battery monitoring
  Future<void> _initializeBatteryMonitoring() async {
    try {
      // Get initial battery level
      _currentBatteryLevel = await _battery.batteryLevel;

      // Get initial battery state
      final batteryState = await _battery.batteryState;
      _updateBatteryState(batteryState);

      // Listen for battery state changes
      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen(_updateBatteryState);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to initialize battery monitoring",
        source: _source,
        severity: ErrorSeverity.low,
      );
    }
  }

  // Update battery state
  void _updateBatteryState(battery_plus.BatteryState batteryState) async {
    try {
      // Get current battery level
      _currentBatteryLevel = await _battery.batteryLevel;

      // Map to our battery state enum
      final newState = BatteryStateExtension.fromBatteryPlusState(
          batteryState, _currentBatteryLevel);

      if (newState != _currentBatteryState) {
        _currentBatteryState = newState;
        _notifyBatteryStateListeners();
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update battery state",
        source: _source,
        severity: ErrorSeverity.low,
      );
    }
  }

  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final newAppState = AppStateExtension.fromAppLifecycleState(state);

    if (newAppState != _currentAppState) {
      _currentAppState = newAppState;
      _notifyAppStateListeners();
    }
  }

  // Notify app state listeners
  void _notifyAppStateListeners() {
    for (final listener in _appStateListeners) {
      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying app state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Notify battery state listeners
  void _notifyBatteryStateListeners() {
    for (final listener in _batteryStateListeners) {
      try {
        listener.onBatteryStateChanged(
            _currentBatteryState, _currentBatteryLevel);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying battery state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Add app state listener
  @override
  void addAppStateListener(AppStateListener listener) {
    if (!_appStateListeners.contains(listener)) {
      _appStateListeners.add(listener);

      // Immediately notify with current state
      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new app state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Remove app state listener
  @override
  void removeAppStateListener(AppStateListener listener) {
    _appStateListeners.remove(listener);
  }

  // Add battery state listener
  @override
  void addBatteryStateListener(BatteryStateListener listener) {
    if (!_batteryStateListeners.contains(listener)) {
      _batteryStateListeners.add(listener);

      // Immediately notify with current state
      try {
        listener.onBatteryStateChanged(
            _currentBatteryState, _currentBatteryLevel);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new battery state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Remove battery state listener
  @override
  void removeBatteryStateListener(BatteryStateListener listener) {
    _batteryStateListeners.remove(listener);
  }

  // Get current app state
  @override
  AppState getCurrentAppState() => _currentAppState;

  // Get current battery state
  @override
  BatteryState getCurrentBatteryState() => _currentBatteryState;

  // Get current battery level
  @override
  int getCurrentBatteryLevel() => _currentBatteryLevel;

  // Clean up resources
  @override
  void shutdown() {
    WidgetsBinding.instance.removeObserver(this);
    _batteryStateSubscription?.cancel();
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
}
