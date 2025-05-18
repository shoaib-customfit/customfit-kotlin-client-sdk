import 'package:flutter/foundation.dart';

import '../listener/all_flags_listener.dart';
import '../listener/feature_flag_change_listener.dart';
import '../../network/connection/connection_status_listener.dart';
import '../../network/connection/connection_status.dart';
import '../../network/connection/connection_information.dart';

/// Interface for ListenerManager
abstract class ListenerManager {
  /// Register a feature flag change listener
  void registerFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener);

  /// Unregister a feature flag change listener
  void unregisterFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener);

  /// Register an all flags listener
  void registerAllFlagsListener(AllFlagsListener listener);

  /// Unregister an all flags listener
  void unregisterAllFlagsListener(AllFlagsListener listener);

  /// Add a connection status listener
  void addConnectionStatusListener(ConnectionStatusListener listener);

  /// Remove a connection status listener
  void removeConnectionStatusListener(ConnectionStatusListener listener);

  /// Clear all listeners
  void clearAllListeners();
}

/// Implementation of ListenerManager
class ListenerManagerImpl implements ListenerManager {
  // Feature flag listeners
  final Map<String, Set<FeatureFlagChangeListener>> _featureFlagListeners = {};

  // All flags listeners
  final Set<AllFlagsListener> _allFlagsListeners = {};

  // Connection status listeners
  final Set<ConnectionStatusListener> _connectionStatusListeners = {};

  @override
  void registerFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    _featureFlagListeners[flagKey] ??= {};
    _featureFlagListeners[flagKey]!.add(listener);
  }

  @override
  void unregisterFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null) {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _featureFlagListeners.remove(flagKey);
      }
    }
  }

  @override
  void registerAllFlagsListener(AllFlagsListener listener) {
    _allFlagsListeners.add(listener);
  }

  @override
  void unregisterAllFlagsListener(AllFlagsListener listener) {
    _allFlagsListeners.remove(listener);
  }

  @override
  void addConnectionStatusListener(ConnectionStatusListener listener) {
    _connectionStatusListeners.add(listener);
  }

  @override
  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _connectionStatusListeners.remove(listener);
  }

  /// Notify feature flag listeners of a flag change
  void notifyFeatureFlagListeners(
      String flagKey, dynamic oldValue, dynamic newValue) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null) {
      for (final listener in Set<FeatureFlagChangeListener>.from(listeners)) {
        try {
          listener.onFeatureFlagChanged(flagKey, oldValue, newValue);
        } catch (e) {
          debugPrint('Error notifying feature flag listener: $e');
        }
      }
    }
  }

  /// Notify all flags listeners of flag changes
  void notifyAllFlagsListeners(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    for (final listener in Set<AllFlagsListener>.from(_allFlagsListeners)) {
      try {
        listener.onAllFlagsChanged(oldFlags, newFlags);
      } catch (e) {
        debugPrint('Error notifying all flags listener: $e');
      }
    }
  }

  /// Notify connection status listeners of a connection status change
  void notifyConnectionStatusListeners(
      ConnectionStatus status, ConnectionInformation info) {
    for (final listener
        in Set<ConnectionStatusListener>.from(_connectionStatusListeners)) {
      try {
        listener.onConnectionStatusChanged(status, info);
      } catch (e) {
        debugPrint('Error notifying connection status listener: $e');
      }
    }
  }

  @override
  void clearAllListeners() {
    _featureFlagListeners.clear();
    _allFlagsListeners.clear();
    _connectionStatusListeners.clear();
  }
}
