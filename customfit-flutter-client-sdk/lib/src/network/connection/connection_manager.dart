import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../config/core/cf_config.dart';
import 'connection_status.dart';
import 'connection_information.dart';
import 'connection_status_listener.dart';

/// Interface for managing network connection state and listeners
abstract class ConnectionManager {
  /// Check if the manager is in offline mode
  bool isOffline();

  /// Get the current connection status
  ConnectionStatus getConnectionStatus();

  /// Get detailed connection information
  ConnectionInformation getConnectionInformation();

  /// Add a listener for connection status changes
  void addConnectionStatusListener(ConnectionStatusListener listener);

  /// Remove a previously added connection status listener
  void removeConnectionStatusListener(ConnectionStatusListener listener);

  /// Set offline mode to enable/disable network operations
  void setOfflineMode(bool offline);

  /// Record a successful connection attempt
  void recordConnectionSuccess();

  /// Record a failed connection attempt with an error message
  void recordConnectionFailure(String error);

  /// Check the current connection status and attempt to reconnect if needed
  void checkConnection();

  /// Shutdown the connection manager and release resources
  void shutdown();
}

/// Manages reconnect logic and notifies listeners mirroring Kotlin's ConnectionManager
class ConnectionManagerImpl implements ConnectionManager {
  // ignore: unused_field
  final CFConfig _config;
  final List<ConnectionStatusListener> _listeners = [];
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  bool _offlineMode = false;
  int _failureCount = 0;
  int _lastSuccessMs = 0;
  int _nextReconnectMs = 0;
  String? _lastError;

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  static const _heartbeatInterval = Duration(seconds: 15);
  static const _baseDelayMs = 1000;
  static const _maxDelayMs = 30000;

  ConnectionManagerImpl(this._config) {
    if (!_offlineMode) _updateStatus(ConnectionStatus.connecting);
    _startHeartbeat();
  }

  @override
  bool isOffline() => _offlineMode;

  @override
  ConnectionStatus getConnectionStatus() => _currentStatus;

  @override
  ConnectionInformation getConnectionInformation() => ConnectionInformation(
        status: _currentStatus,
        isOfflineMode: _offlineMode,
        lastError: _lastError,
        lastSuccessfulConnectionTimeMs: _lastSuccessMs,
        failureCount: _failureCount,
        nextReconnectTimeMs: _nextReconnectMs,
      );

  @override
  void addConnectionStatusListener(ConnectionStatusListener l) {
    _listeners.add(l);
    // immediate callback
    scheduleMicrotask(() => l.onConnectionStatusChanged(
        _currentStatus, getConnectionInformation()));
  }

  @override
  void removeConnectionStatusListener(ConnectionStatusListener l) {
    _listeners.remove(l);
  }

  @override
  void setOfflineMode(bool offline) {
    _offlineMode = offline;
    _cancelReconnect();
    _updateStatus(
        offline ? ConnectionStatus.offline : ConnectionStatus.connecting);
    if (!offline) _scheduleReconnect(Duration.zero);
  }

  @override
  void recordConnectionSuccess() {
    _failureCount = 0;
    _lastError = null;
    _lastSuccessMs = DateTime.now().millisecondsSinceEpoch;
    _updateStatus(ConnectionStatus.connected);
  }

  @override
  void recordConnectionFailure(String error) {
    _failureCount++;
    _lastError = error;
    if (!_offlineMode) {
      _updateStatus(ConnectionStatus.connecting);
      final delay = _calculateBackoff(_failureCount);
      _scheduleReconnect(Duration(milliseconds: delay));
    }
  }

  @override
  void checkConnection() {
    if (_offlineMode) return;
    if (_currentStatus == ConnectionStatus.connected) {
      _updateStatus(ConnectionStatus.connecting);
    }
    _scheduleReconnect(Duration.zero);
  }

  int _calculateBackoff(int failures) {
    final exp = (_baseDelayMs * (1 << failures)).clamp(0, _maxDelayMs);
    final jitter = (0.8 + (Random().nextDouble() * 0.4));
    return (exp * jitter).toInt();
  }

  void _scheduleReconnect(Duration delay) {
    _cancelReconnect();
    if (delay > Duration.zero) {
      _nextReconnectMs =
          DateTime.now().millisecondsSinceEpoch + delay.inMilliseconds;
      debugPrint('Scheduling reconnect in ${delay.inMilliseconds}ms');
    }
    _reconnectTimer = Timer(delay, () {
      if (!_offlineMode) {
        debugPrint('Attempting reconnect');
        _nextReconnectMs = 0;
        for (final l in _listeners) {
          l.onConnectionStatusChanged(
              _currentStatus, getConnectionInformation());
        }
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _nextReconnectMs = 0;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_offlineMode &&
          (_currentStatus == ConnectionStatus.disconnected ||
              DateTime.now().millisecondsSinceEpoch - _lastSuccessMs > 60000)) {
        checkConnection();
      }
    });
  }

  @override
  void shutdown() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _listeners.clear();
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      final info = getConnectionInformation();
      debugPrint('Connection status: $newStatus');
      for (final l in List.of(_listeners)) {
        l.onConnectionStatusChanged(newStatus, info);
      }
    }
  }
}
