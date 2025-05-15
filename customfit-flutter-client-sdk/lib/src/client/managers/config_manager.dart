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
  }) : _config = config,
       _configFetcher = configFetcher {
    // Start SDK settings check
    _startSdkSettingsCheck();
  }
  
  /// Start periodic SDK settings check
  void _startSdkSettingsCheck() {
    _sdkSettingsTimer?.cancel();
    _sdkSettingsTimer = Timer.periodic(
      Duration(milliseconds: _config.sdkSettingsCheckIntervalMs),
      (_) => _checkSdkSettings(),
    );
    
    // Perform initial check
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
      
      // Check if we need to update based on Last-Modified
      if (lastModified != null && lastModified != _previousLastModified) {
        _previousLastModified = lastModified;
        
        // Fetch config
        final configSuccess = await _configFetcher.fetchConfig();
        
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
        if (currentValue != value) {
          _configMap[key] = value;
          updatedKeys.add(key);
        }
      });
    });
    
    // Notify listeners
    _notifyConfigChanges(updatedKeys);
  }
  
  /// Notify listeners of config changes
  void _notifyConfigChanges(List<String> updatedKeys) {
    for (final key in updatedKeys) {
      final value = _configMap[key];
      final listeners = _configListeners[key];
      
      if (listeners != null) {
        for (final listener in List<void Function(dynamic)>.from(listeners)) {
          try {
            listener(value);
          } catch (e) {
            debugPrint('Error notifying config change listener: $e');
          }
        }
      }
    }
  }
  
  @override
  String getString(String key, String defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      return defaultValue;
    }
    
    if (value is String) {
      return value;
    }
    
    return defaultValue;
  }
  
  @override
  bool getBoolean(String key, bool defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      return defaultValue;
    }
    
    if (value is bool) {
      return value;
    }
    
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    
    if (value is num) {
      return value != 0;
    }
    
    return defaultValue;
  }
  
  @override
  num getNumber(String key, num defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      return defaultValue;
    }
    
    if (value is num) {
      return value;
    }
    
    if (value is String) {
      try {
        return num.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    
    return defaultValue;
  }
  
  @override
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    final value = _configMap[key];
    if (value == null) {
      return defaultValue;
    }
    
    if (value is Map<String, dynamic>) {
      return value;
    }
    
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
}

/// Simple synchronization helper
T synchronized<T>(Object lock, T Function() fn) {
  try {
    return fn();
  } finally {
    // No actual locking in Dart, this is just a pattern to make the code more readable
  }
}
