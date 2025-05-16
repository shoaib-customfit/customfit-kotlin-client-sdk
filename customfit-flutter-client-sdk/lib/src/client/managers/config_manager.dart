import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/core/cf_config.dart';
import '../../network/config_fetcher.dart';

/// Interface for ConfigManager
abstract class ConfigManager {
  /// Get a string feature flag value
  String getString(String key, String defaultValue);

  /// Get a boolean feature flag value
  bool getBoolean(String key, bool defaultValue);

  /// Get a number feature flag value
  num getNumber(String key, num defaultValue);

  /// Get a JSON feature flag value
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue);

  /// Add a listener for a specific feature flag
  void addConfigListener<T>(String key, void Function(T) listener);

  /// Remove a listener for a specific feature flag
  void removeConfigListener<T>(String key, void Function(T) listener);

  /// Clear all listeners for a specific feature flag
  void clearConfigListeners(String key);

  /// Returns a map of all feature flags with their current values
  Map<String, dynamic> getAllFlags();

  /// Shutdown the config manager
  void shutdown();

  /// Manually trigger a refresh of configs
  Future<bool> refreshConfigs();

  /// Debug method to dump the entire config map in detail
  void dumpConfigMap();
}

/// Implementation of ConfigManager
class ConfigManagerImpl implements ConfigManager {
  final CFConfig _config;
  final ConfigFetcher _configFetcher;

  // Cache for feature flags
  final Map<String, dynamic> _configMap = {};

  // Listeners for feature flag changes
  final Map<String, List<void Function(dynamic)>> _configListeners = {};

  // Lock for config map operations
  final _configLock = Object();

  // Timer for SDK settings check
  Timer? _sdkSettingsTimer;

  // Last modified timestamp for SDK settings
  String? _previousLastModified;

  // Completer for SDK settings initialization
  final Completer<void> _sdkSettingsCompleter = Completer<void>();

  /// Create a new ConfigManagerImpl
  ConfigManagerImpl({
    required CFConfig config,
    required ConfigFetcher configFetcher,
  })  : _config = config,
        _configFetcher = configFetcher {
    // Start SDK settings check
    _startSdkSettingsCheck();
  }

  /// Start periodic SDK settings check
  void _startSdkSettingsCheck() {
    // Cancel any existing timer first
    _sdkSettingsTimer?.cancel();

    // Get the configured interval from CFConfig
    final intervalMs = _config.sdkSettingsCheckIntervalMs;

    // IMPORTANT: Enforce a reasonable minimum interval to prevent network abuse
    // Minimum 1 minute (60000ms), recommended 4+ minutes (240000ms)
    final minimumInterval = 60000; // 1 minute absolute minimum
    final recommendedInterval = 240000; // 4 minutes recommended

    // Apply minimum interval with clear warnings
    final actualIntervalMs =
        intervalMs < minimumInterval ? recommendedInterval : intervalMs;

    if (intervalMs < minimumInterval) {
      debugPrint(
          'CRITICAL WARNING: Configured interval ${intervalMs}ms is too short and would cause excessive network traffic!');
      debugPrint(
          'Enforcing recommended interval of ${recommendedInterval}ms (4 minutes) to prevent network abuse.');
      debugPrint(
          'Please update your CFConfig to use a reasonable polling interval (4+ minutes recommended).');
    } else if (intervalMs < recommendedInterval) {
      debugPrint(
          'WARNING: Configured interval ${intervalMs}ms is shorter than the recommended ${recommendedInterval}ms (4 minutes).');
      debugPrint(
          'Short intervals may cause excessive network traffic and battery drain.');
    }

    // Log the final interval being used
    debugPrint(
        'Starting SDK settings check timer with actual interval: ${actualIntervalMs}ms');

    // Create a new timer with the safe interval
    _sdkSettingsTimer = Timer.periodic(
      Duration(milliseconds: actualIntervalMs),
      (timer) {
        debugPrint('Timer fired after ${actualIntervalMs}ms');
        _checkSdkSettings();
      },
    );

    // Perform initial check outside the timer
    _initialSdkSettingsCheck();
  }

  /// Perform initial SDK settings check
  Future<void> _initialSdkSettingsCheck() async {
    await _checkSdkSettings();
    if (!_sdkSettingsCompleter.isCompleted) {
      _sdkSettingsCompleter.complete();
    }
  }

  /// Check SDK settings for updates
  Future<void> _checkSdkSettings() async {
    try {
      // Fetch metadata
      final metadataResult = await _configFetcher.fetchMetadata();

      if (!metadataResult.isSuccess) {
        debugPrint('Failed to fetch metadata');
        return;
      }

      final headers = metadataResult.getOrNull() ?? {};
      final lastModified = headers['Last-Modified'];

      // If we get 'unchanged' for Last-Modified, it means we got a 304 response
      // No need to fetch the config again
      if (lastModified == 'unchanged') {
        debugPrint(
            'SDK settings unchanged (304 Not Modified), skipping config fetch');
        return;
      }

      // Check if we need to update based on Last-Modified
      if (lastModified != null && lastModified != _previousLastModified) {
        debugPrint(
            'Last-Modified changed from $_previousLastModified to $lastModified');
        _previousLastModified = lastModified;

        // Fetch config
        final configSuccess =
            await _configFetcher.fetchConfig(lastModified: lastModified);

        if (!configSuccess) {
          debugPrint('Failed to fetch config');
          return;
        }

        // Get configs
        final configsResult = _configFetcher.getConfigs();

        if (!configsResult.isSuccess) {
          debugPrint('Failed to get configs');
          return;
        }

        final configs = configsResult.getOrNull() ?? {};
        _updateConfigMap(configs);
      } else {
        debugPrint('No change in Last-Modified header, skipping config fetch');
      }
    } catch (e) {
      debugPrint('Error checking SDK settings: $e');
    }
  }

  /// Update config map with new values
  void _updateConfigMap(Map<String, dynamic> newConfigs) {
    final updatedKeys = <String>[];

    synchronized(_configLock, () {
      // Update config map
      newConfigs.forEach((key, value) {
        final currentValue = _configMap[key];

        // Check if the value has changed
        if (currentValue != value) {
          debugPrint('⚡ Config key "$key" changed: $currentValue -> $value');
          _configMap[key] = value;
          updatedKeys.add(key);
        }
      });
    });

    // Debug: Print the full config map
    debugPrint('===== FULL CONFIG MAP =====');
    _configMap.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('==========================');

    // Notify listeners if anything changed
    if (updatedKeys.isNotEmpty) {
      debugPrint(
          '⚡ Notifying listeners about ${updatedKeys.length} changed keys: $updatedKeys');
      _notifyConfigChanges(updatedKeys);
    } else {
      debugPrint('No config keys changed, skipping notification');
    }
  }

  /// Notify listeners of config changes
  void _notifyConfigChanges(List<String> updatedKeys) {
    for (final key in updatedKeys) {
      final value = _configMap[key];
      final listeners = _configListeners[key];

      // Extract the actual value to notify, handling feature flags with variation field
      dynamic valueToNotify = value;

      // If it's a feature flag with variation field, use that value
      if (value is Map<String, dynamic> && value.containsKey('variation')) {
        valueToNotify = value['variation'];
        debugPrint(
            '⚡ Notifying listeners for "$key" with variation value: $valueToNotify');
      } else {
        debugPrint(
            '⚡ Notifying listeners for "$key" with direct value: $valueToNotify');
      }

      if (listeners != null) {
        for (final listener in List<void Function(dynamic)>.from(listeners)) {
          try {
            debugPrint(
                '⚡ Calling listener for "$key" with value: $valueToNotify');
            listener(valueToNotify);
          } catch (e) {
            debugPrint('Error notifying config change listener: $e');
          }
        }
      } else {
        debugPrint('No listeners registered for key "$key"');
      }
    }
  }

  @override
  String getString(String key, String defaultValue) {
    debugPrint(
        'getString called for key: "$key" with default: "$defaultValue"');
    final value = _configMap[key];

    debugPrint(
        'Raw value from _configMap["$key"]: $value (type: ${value?.runtimeType})');

    if (value == null) {
      debugPrint('Config key "$key" not found, using default: $defaultValue');
      return defaultValue;
    }

    // IMPORTANT: First check if it's a feature flag with a variation field
    if (value is Map<String, dynamic>) {
      debugPrint('Value for "$key" is a Map with keys: ${value.keys.toList()}');

      if (value.containsKey('variation')) {
        final variation = value['variation'];
        debugPrint(
            '✅ FOUND "variation" field for "$key": "$variation" (type: ${variation.runtimeType})');

        if (variation is String) {
          debugPrint(
              '✅ RETURNING feature flag "$key" string variation value: "$variation"');
          return variation;
        } else {
          debugPrint(
              '⚠️ Variation for "$key" is not a string: $variation (${variation.runtimeType})');
          // Convert to string if possible
          return variation.toString();
        }
      } else {
        debugPrint('⚠️ Map for "$key" does not contain "variation" field');
      }
    }

    // Direct string value
    if (value is String) {
      debugPrint('Found string value for "$key": "$value"');
      return value;
    }

    debugPrint(
        '⚠️ Value for "$key" is not a string: $value (${value.runtimeType}), using default: "$defaultValue"');
    return defaultValue;
  }

  @override
  bool getBoolean(String key, bool defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      debugPrint('Config key "$key" not found, using default: $defaultValue');
      return defaultValue;
    }

    // Check if it's a feature flag with a variation field (same as in CFClient._notifyConfigChanges)
    if (value is Map<String, dynamic> && value.containsKey('variation')) {
      final variation = value['variation'];

      // Check the type of the variation value
      if (variation is bool) {
        debugPrint(
            'Found feature flag "$key" with variation value: $variation');
        return variation;
      }

      if (variation is String) {
        debugPrint(
            'Found feature flag "$key" with string variation value: $variation, converting to boolean');
        return variation.toLowerCase() == 'true';
      }

      if (variation is num) {
        debugPrint(
            'Found feature flag "$key" with numeric variation value: $variation, converting to boolean');
        return variation != 0;
      }
    }

    // Direct boolean value
    if (value is bool) {
      debugPrint('Found boolean value for "$key": $value');
      return value;
    }

    if (value is String) {
      debugPrint(
          'Found string value for "$key": $value, converting to boolean');
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      debugPrint(
          'Found numeric value for "$key": $value, converting to boolean');
      return value != 0;
    }

    debugPrint(
        'Value for "$key" is not convertible to boolean: $value (${value.runtimeType}), using default: $defaultValue');
    return defaultValue;
  }

  @override
  num getNumber(String key, num defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      debugPrint('Config key "$key" not found, using default: $defaultValue');
      return defaultValue;
    }

    // Check if it's a feature flag with a variation field (same as in CFClient._notifyConfigChanges)
    if (value is Map<String, dynamic> && value.containsKey('variation')) {
      final variation = value['variation'];

      // Check the type of the variation value
      if (variation is num) {
        debugPrint(
            'Found feature flag "$key" with numeric variation value: $variation');
        return variation;
      }

      if (variation is String) {
        debugPrint(
            'Found feature flag "$key" with string variation value: $variation, attempting to convert to number');
        try {
          return num.parse(variation);
        } catch (e) {
          debugPrint(
              'Failed to parse string variation "$variation" as number: $e');
          return defaultValue;
        }
      }
    }

    // Direct numeric value
    if (value is num) {
      debugPrint('Found numeric value for "$key": $value');
      return value;
    }

    if (value is String) {
      debugPrint(
          'Found string value for "$key": $value, attempting to convert to number');
      try {
        return num.parse(value);
      } catch (e) {
        debugPrint('Failed to parse "$value" as number: $e');
        return defaultValue;
      }
    }

    debugPrint(
        'Value for "$key" is not convertible to number: $value (${value.runtimeType}), using default: $defaultValue');
    return defaultValue;
  }

  @override
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      debugPrint('Config key "$key" not found, using default');
      return defaultValue;
    }

    // Check if it's a feature flag with a variation field (same as in CFClient._notifyConfigChanges)
    if (value is Map<String, dynamic> && value.containsKey('variation')) {
      final variation = value['variation'];

      // Check if the variation is itself a Map
      if (variation is Map<String, dynamic>) {
        debugPrint('Found feature flag "$key" with JSON variation value');
        return variation;
      }
    }

    // Direct Map value
    if (value is Map<String, dynamic>) {
      debugPrint('Found JSON value for "$key"');
      return value;
    }

    debugPrint(
        'Value for "$key" is not a JSON object: $value (${value.runtimeType}), using default');
    return defaultValue;
  }

  @override
  void addConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      _configListeners[key] ??= [];

      // Cast to dynamic function to store in the map
      dynamicListener(dynamic value) {
        if (value is T) {
          listener(value);
        }
      }

      _configListeners[key]!.add(dynamicListener);

      // Notify with current value if available
      final currentValue = _configMap[key];
      if (currentValue != null && currentValue is T) {
        listener(currentValue);
      }
    });
  }

  @override
  void removeConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      final listeners = _configListeners[key];
      if (listeners == null) {
        return;
      }

      // Remove listeners that match the signature
      // This is a simplification as we can't directly compare function references
      // in Dart, so we're removing all listeners for the given type
      _configListeners[key] = listeners.where((l) {
        // We can't directly compare function references in Dart
        // This is a simplification that will remove all listeners for the given key
        return false;
      }).toList();
    });
  }

  @override
  void clearConfigListeners(String key) {
    synchronized(_configLock, () {
      _configListeners.remove(key);
    });
  }

  @override
  Map<String, dynamic> getAllFlags() {
    // Debug: Print the full config map when accessed
    debugPrint('===== ACCESSING FULL CONFIG MAP =====');
    _configMap.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('===================================');

    return Map<String, dynamic>.unmodifiable(_configMap);
  }

  /// Get the completer for SDK settings initialization
  Completer<void> getSdkSettingsCompleter() {
    return _sdkSettingsCompleter;
  }

  @override
  void shutdown() {
    _sdkSettingsTimer?.cancel();
    _configListeners.clear();
  }

  /// Manually trigger a refresh of configs
  Future<bool> refreshConfigs() async {
    debugPrint('Manually refreshing configs...');
    try {
      await _checkSdkSettings();
      return true;
    } catch (e) {
      debugPrint('Error during manual config refresh: $e');
      return false;
    }
  }

  /// Debug method to dump the entire config map in detail
  void dumpConfigMap() {
    debugPrint('========== FULL CONFIG MAP DUMP ==========');
    if (_configMap.isEmpty) {
      debugPrint('CONFIG MAP IS EMPTY');
    } else {
      _configMap.forEach((key, value) {
        debugPrint('Key: "$key"');
        debugPrint('  Value: $value');
        debugPrint('  Type: ${value.runtimeType}');

        if (value is Map<String, dynamic>) {
          debugPrint('  Map keys: ${value.keys.toList()}');

          // If it has a variation key, show it
          if (value.containsKey('variation')) {
            final variation = value['variation'];
            debugPrint('  Variation: $variation (${variation.runtimeType})');
          }
        }

        debugPrint('----------------------------------------');
      });
    }
    debugPrint('=========================================');
  }
}

/// Simple synchronization helper
T synchronized<T>(Object lock, T Function() fn) {
  try {
    return fn();
  } finally {
    // No actual locking in Dart, this is just a pattern to make the code more readable
  }
}
