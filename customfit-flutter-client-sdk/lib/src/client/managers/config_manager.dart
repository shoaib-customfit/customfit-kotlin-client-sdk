import 'dart:async';

// Removing unused foundation and uuid imports
// import 'package:flutter/foundation.dart';
// import 'package:uuid/uuid.dart';

import '../../config/core/cf_config.dart';
import '../../network/config_fetcher.dart';
import '../../analytics/summary/summary_manager.dart';
import '../../core/logging/logger.dart';
import '../../core/error/cf_result.dart';

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
  final SummaryManager? _summaryManager;

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
    SummaryManager? summaryManager,
  })  : _config = config,
        _configFetcher = configFetcher,
        _summaryManager = summaryManager {
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
    const minimumInterval = 60000; // 1 minute absolute minimum
    const recommendedInterval = 240000; // 4 minutes recommended

    // Apply minimum interval with clear warnings
    final actualIntervalMs =
        intervalMs < minimumInterval ? recommendedInterval : intervalMs;

    if (intervalMs < minimumInterval) {
      Logger.w(
          'CRITICAL WARNING: Configured interval ${intervalMs}ms is too short and would cause excessive network traffic!');
      Logger.w(
          'Enforcing recommended interval of ${recommendedInterval}ms (4 minutes) to prevent network abuse.');
      Logger.w(
          'Please update your CFConfig to use a reasonable polling interval (4+ minutes recommended).');
    } else if (intervalMs < recommendedInterval) {
      Logger.w(
          'WARNING: Configured interval ${intervalMs}ms is shorter than the recommended ${recommendedInterval}ms (4 minutes).');
      Logger.w(
          'Short intervals may cause excessive network traffic and battery drain.');
    }

    // Log the final interval being used
    Logger.i(
        'Starting SDK settings check timer with actual interval: ${actualIntervalMs}ms');

    // Create a new timer with the safe interval
    _sdkSettingsTimer = Timer.periodic(
      Duration(milliseconds: actualIntervalMs),
      (timer) {
        Logger.d('Timer fired after ${actualIntervalMs}ms');
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
      Logger.d('🔎 API POLL: Starting SDK settings check');

      // Fetch metadata
      final metadataResult = await _configFetcher.fetchMetadata();

      if (!metadataResult.isSuccess) {
        Logger.w(
            '🔎 API POLL: Failed to fetch metadata: ${metadataResult.getErrorMessage()}');
        return;
      }

      final headers = metadataResult.getOrNull() ?? {};
      final lastModified = headers['Last-Modified'];

      // If we get 'unchanged' for Last-Modified, it means we got a 304 response
      // No need to fetch the config again
      if (lastModified == 'unchanged') {
        Logger.d(
            '🔎 API POLL: SDK settings unchanged (304 Not Modified), skipping config fetch');
        return;
      }

      // Check if we need to update based on Last-Modified
      if (lastModified != null && lastModified != _previousLastModified) {
        Logger.i(
            '🔎 API POLL: Last-Modified changed from $_previousLastModified to $lastModified');
        _previousLastModified = lastModified;

        // Fetch config
        final configSuccess =
            await _configFetcher.fetchConfig(lastModified: lastModified);

        if (!configSuccess) {
          Logger.w('🔎 API POLL: Failed to fetch config');
          return;
        }

        // Get configs
        final configsResult = _configFetcher.getConfigs();

        if (!configsResult.isSuccess) {
          Logger.w(
              '🔎 API POLL: Failed to get configs: ${configsResult.getErrorMessage()}');
          return;
        }

        final configs = configsResult.getOrNull() ?? {};
        Logger.i(
            '🔎 API POLL: Successfully fetched ${configs.length} config entries');
        _updateConfigMap(configs);
      } else {
        Logger.d(
            '🔎 API POLL: No change in Last-Modified header, skipping config fetch');
      }
    } catch (e) {
      Logger.e('🔎 API POLL: Error checking SDK settings: $e');
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
          Logger.i(
              '⚡ CONFIG UPDATE: Key "$key" changed: $currentValue -> $value');
          _configMap[key] = value;
          updatedKeys.add(key);
        }
      });
    });

    // Debug: Print the full config map
    Logger.d('===== FULL CONFIG MAP =====');
    _configMap.forEach((key, value) {
      Logger.d('$key: $value');
    });
    Logger.d('==========================');

    // Notify listeners if anything changed
    if (updatedKeys.isNotEmpty) {
      Logger.i(
          '⚡ Notifying listeners about ${updatedKeys.length} changed keys: $updatedKeys');
      _notifyConfigChanges(updatedKeys);
    } else {
      Logger.d('No config keys changed, skipping notification');
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
        Logger.d(
            '⚡ Notifying listeners for "$key" with variation value: $valueToNotify');
      } else {
        Logger.d(
            '⚡ Notifying listeners for "$key" with direct value: $valueToNotify');
      }

      if (listeners != null) {
        for (final listener in List<void Function(dynamic)>.from(listeners)) {
          try {
            Logger.d(
                '⚡ Calling listener for "$key" with value: $valueToNotify');
            listener(valueToNotify);
          } catch (e) {
            Logger.e('Error notifying config change listener: $e');
          }
        }
      }
    }
  }

  @override
  String getString(String key, String defaultValue) {
    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is String) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected String, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  bool getBoolean(String key, bool defaultValue) {
    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is bool) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected bool, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  num getNumber(String key, num defaultValue) {
    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is num) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected num, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is Map<String, dynamic>) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected Map<String, dynamic>, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  /// Helper method to get the variation value
  dynamic _getVariation(String key) {
    final config = synchronized(_configLock, () => _configMap[key]);

    if (config == null) {
      Logger.d('No config found for key "$key"');
      return null;
    }

    if (config is Map<String, dynamic>) {
      return config['variation'];
    } else {
      Logger.d('Config for "$key" is not a map: $config');
      return null;
    }
  }

  /// Push summary for tracking and analytics
  void _pushSummaryForKey(String key) {
    if (_summaryManager == null) {
      return;
    }

    try {
      final config = synchronized(_configLock, () => _configMap[key]);

      if (config is Map<String, dynamic>) {
        // Create a copy to avoid modifying the original
        final configMapWithKey = Map<String, dynamic>.from(config);

        // Add key to help with debugging
        configMapWithKey['key'] = key;

        // Ensure required fields are present
        if (!configMapWithKey.containsKey('experience_id') &&
            configMapWithKey.containsKey('id')) {
          configMapWithKey['experience_id'] = configMapWithKey['id'] as String;
        }

        // Add default values for other required fields if missing
        if (!configMapWithKey.containsKey('config_id')) {
          configMapWithKey['config_id'] =
              configMapWithKey['id'] ?? 'default-config-id';
        }

        if (!configMapWithKey.containsKey('variation_id')) {
          configMapWithKey['variation_id'] =
              configMapWithKey['id'] ?? 'default-variation-id';
        }

        if (!configMapWithKey.containsKey('version')) {
          configMapWithKey['version'] = '1.0.0';
        }

        // Use async/await with pushSummary instead of then
        Logger.d('Pushing summary for key: $key');
        _summaryManager.pushSummary(configMapWithKey).then((_) {
          Logger.d('Summary pushed for key: $key');
        }).catchError((error) {
          Logger.w(
              'Failed to push summary for key "$key": ${error is CFResult ? error.getErrorMessage() : error}');
        });
      }
    } catch (e) {
      Logger.e('Exception while pushing summary for key "$key": $e');
    }
  }

  @override
  void addConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      // Get or create list of listeners for this key
      final listeners = _configListeners[key] ?? [];

      // Add listener
      listeners.add((value) {
        if (value is T) {
          listener(value);
        } else {
          Logger.w(
              'Type mismatch for listener on "$key": expected ${T.toString()}, got ${value.runtimeType}');
        }
      });

      // Update map
      _configListeners[key] = listeners;
    });

    Logger.d('Added listener for key "$key"');

    // Notify immediately if we already have a value
    final variation = _getVariation(key);
    if (variation != null && variation is T) {
      listener(variation);
    }
  }

  @override
  void removeConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      // Get listeners for this key
      final listeners = _configListeners[key];

      if (listeners != null) {
        // Remove matching listeners
        // This is a bit tricky since we can't directly compare function references
        // We'll need to use toString() and hope for the best
        final listenerString = listener.toString();
        listeners.removeWhere((l) => l.toString() == listenerString);

        // Update map
        _configListeners[key] = listeners;
      }
    });

    Logger.d('Removed listener for key "$key"');
  }

  @override
  void clearConfigListeners(String key) {
    synchronized(_configLock, () {
      _configListeners.remove(key);
    });

    Logger.d('Cleared all listeners for key "$key"');
  }

  @override
  Map<String, dynamic> getAllFlags() {
    final result = <String, dynamic>{};

    synchronized(_configLock, () {
      for (final entry in _configMap.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          result[key] = value['variation'];
        } else {
          result[key] = value;
        }
      }
    });

    return result;
  }

  @override
  void shutdown() {
    Logger.i('Shutting down ConfigManager');
    _sdkSettingsTimer?.cancel();
    _sdkSettingsTimer = null;
    _configListeners.clear();
  }

  @override
  Future<bool> refreshConfigs() async {
    Logger.i('⚡ Manually refreshing configs');
    try {
      await _checkSdkSettings();
      return true;
    } catch (e) {
      Logger.e('Error refreshing configs: $e');
      return false;
    }
  }

  @override
  void dumpConfigMap() {
    Logger.i('===== DETAILED CONFIG MAP =====');

    synchronized(_configLock, () {
      for (final key in _configMap.keys) {
        final value = _configMap[key];
        Logger.i('$key: $value');

        if (value is Map<String, dynamic>) {
          for (final subKey in value.keys) {
            Logger.i('  $subKey: ${value[subKey]}');
          }
        }
      }
    });

    Logger.i('==============================');
  }
}

/// Helper for synchronized blocks
T synchronized<T>(Object lock, T Function() fn) {
  T result;
  result = fn();
  return result;
}
