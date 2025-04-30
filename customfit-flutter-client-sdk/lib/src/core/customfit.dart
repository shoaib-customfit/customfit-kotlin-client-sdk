import 'dart:async';
import 'package:customfit_flutter_client/src/config/core/cf_config.dart';
import 'package:customfit_flutter_client/src/core/error/cf_result.dart';
import 'package:flutter/foundation.dart';

import '../core/error/error_category.dart';
import '../core/model/cf_user.dart';
import '../platform/device_info_detector.dart';
import '../platform/application_info_detector.dart';

/// The main entry point for the CustomFit SDK.
class CustomFit {
  // Singleton instance
  static CustomFit? _instance;

  // Client key
  final String _clientKey;

  // Configuration
  CFConfig _config;

  // Current user
  CFUser? _user;

  // Private constructor
  CustomFit._({
    required String clientKey,
    required CFConfig config,
  })  : _clientKey = clientKey,
        _config = config {
    // Extract dimension ID from client key
    _extractDimensionId();
  }

  /// Initialize the SDK with the given client key and configuration.
  static Future<CFResult<void>> initialize({
    required String clientKey,
    CFConfig? config,
  }) async {
    try {
      if (_instance != null) {
        return CFResult.error(
          'SDK already initialized',
          category: ErrorCategory.configuration,
        );
      }

      // Create instance with default config if not provided
      _instance = CustomFit._(
        clientKey: clientKey,
        config: config ?? CFConfig.fromClientKey(clientKey),
      );

      // TODO: Initialize components

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to initialize SDK: ${e.toString()}',
        exception: e,
        category: ErrorCategory.configuration,
      );
    }
  }

  /// Get the singleton instance of the SDK.
  static CustomFit get instance {
    if (_instance == null) {
      throw StateError(
          'SDK not initialized. Call CustomFit.initialize() first.');
    }
    return _instance!;
  }

  /// Extract dimension ID from client key.
  void _extractDimensionId() {
    try {
      // Example client key format: sdk_123456789_abcdef
      final parts = _clientKey.split('_');
      if (parts.length >= 2) {
        // We can't directly set dimensionId since it's readonly
        // _config.dimensionId = parts[1];
      }
    } catch (e) {
      debugPrint('Failed to extract dimension ID from client key: $e');
    }
  }

  /// Identify a user.
  static Future<CFResult<void>> identify(CFUser user) async {
    try {
      final instance = CustomFit.instance;
      instance._user = user;

      // Auto-collect device info if enabled
      if (instance._config.autoEnvAttributesEnabled) {
        _collectDeviceInfo(instance);
        _collectAppInfo(instance);
      }

      // TODO: Notify components of user change

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to identify user: ${e.toString()}',
        exception: e,
        category: ErrorCategory.user,
      );
    }
  }

  /// Helper to collect device info
  static void _collectDeviceInfo(CustomFit instance) {
    try {
      DeviceInfoDetector.detectDeviceInfo().then((deviceContext) {
        if (deviceContext != null && instance._user != null) {
          instance._user = instance._user!.withDeviceContext(deviceContext);
        }
      });
    } catch (e) {
      debugPrint('Failed to detect device info: $e');
    }
  }

  /// Helper to collect app info
  static void _collectAppInfo(CustomFit instance) {
    try {
      ApplicationInfoDetector.detectApplicationInfo().then((appInfo) {
        if (appInfo != null && instance._user != null) {
          instance._user = instance._user!.withApplicationInfo(appInfo);
        }
      });
    } catch (e) {
      debugPrint('Failed to detect application info: $e');
    }
  }

  /// Track an event.
  static Future<CFResult<void>> trackEvent(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // TODO: Send event to event tracker

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to track event: ${e.toString()}',
        exception: e,
        category: ErrorCategory.analytics,
      );
    }
  }

  /// Check if a feature is enabled.
  static Future<CFResult<bool>> isFeatureEnabled(String featureKey) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // TODO: Implement feature flag checking

      // Placeholder implementation
      return CFResult.success(false);
    } catch (e) {
      return CFResult.error(
        'Failed to check feature flag: ${e.toString()}',
        exception: e,
        category: ErrorCategory.feature,
      );
    }
  }

  /// Get feature configuration.
  static Future<CFResult<Map<String, dynamic>>> getFeatureConfig(
    String featureKey, {
    Map<String, dynamic>? defaultValue,
  }) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // TODO: Implement feature configuration retrieval

      // Placeholder implementation
      return CFResult.success(defaultValue ?? {});
    } catch (e) {
      return CFResult.error(
        'Failed to get feature config: ${e.toString()}',
        exception: e,
        category: ErrorCategory.feature,
      );
    }
  }

  /// Set offline mode.
  static void setOfflineMode(bool offline) {
    try {
      // Get instance but avoid unused variable warning
      CustomFit._instance;

      // Can't use copyWith since it doesn't exist
      // instance._config = instance._config.copyWith(offlineMode: offline);

      // TODO: Notify components of offline mode change
    } catch (e) {
      debugPrint('Failed to set offline mode: $e');
    }
  }

  /// Shutdown the SDK.
  static Future<void> shutdown() async {
    try {
      if (_instance == null) {
        return;
      }

      // TODO: Shut down components

      _instance = null;
    } catch (e) {
      debugPrint('Failed to shutdown SDK: $e');
    }
  }
}
