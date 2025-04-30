import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../core/model/device_context.dart';

/// Utility class for detecting device information.
class DeviceInfoDetector {
  // Device info plugin
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  // Constants
  // ignore: unused_field
  static const String _source = "DeviceInfoDetector";

  /// Get device context with platform-specific details.
  static Future<DeviceContext> detectDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidDeviceContext();
      } else if (Platform.isIOS) {
        return await _getIosDeviceContext();
      } else if (kIsWeb) {
        return await _getWebDeviceContext();
      } else {
        // Fallback for other platforms
        return DeviceContext();
      }
    } catch (e) {
      debugPrint("Failed to detect device info: $e");
      return DeviceContext();
    }
  }

  /// Get Android device context
  static Future<DeviceContext> _getAndroidDeviceContext() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;

    return DeviceContext(
      manufacturer: androidInfo.manufacturer,
      model: androidInfo.model,
      osName: "Android",
      osVersion: androidInfo.version.release,
      sdkVersion: androidInfo.version.sdkInt.toString(),
      appId: "com.customfit.app", // Should be retrieved from package info
      appVersion: "1.0.0", // Should be retrieved from package info
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: "unknown", // Can be implemented with connectivity package
      networkCarrier: "unknown", // Requires platform-specific code
    );
  }

  /// Get iOS device context
  static Future<DeviceContext> _getIosDeviceContext() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;

    return DeviceContext(
      manufacturer: "Apple",
      model: iosInfo.model,
      osName: "iOS",
      osVersion: iosInfo.systemVersion,
      sdkVersion: iosInfo.systemVersion,
      appId: "com.customfit.app", // Should be retrieved from package info
      appVersion: "1.0.0", // Should be retrieved from package info
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: "unknown", // Can be implemented with connectivity package
      networkCarrier: "unknown", // Requires platform-specific code
    );
  }

  /// Get web device context
  static Future<DeviceContext> _getWebDeviceContext() async {
    final webInfo = await _deviceInfoPlugin.webBrowserInfo;

    return DeviceContext(
      manufacturer: webInfo.vendor ?? "unknown",
      model: webInfo.browserName.toString(),
      osName: webInfo.platform ?? "web",
      osVersion: webInfo.appVersion ?? "unknown",
      sdkVersion: webInfo.appVersion ?? "unknown",
      appId: "com.customfit.web", // Should be retrieved from package info
      appVersion: "1.0.0", // Should be retrieved from package info
      locale: webInfo.language ?? "unknown",
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: "unknown", // Can be implemented with connectivity package
      networkCarrier: "unknown", // Not available on web
    );
  }

  /// Get screen width (or null if not available)
  static int? _getScreenWidth() {
    try {
      // We'll use a more accurate method in a real implementation
      return MediaQueryData.fromView(
              WidgetsBinding.instance.platformDispatcher.views.first)
          .size
          .width
          .toInt();
    } catch (e) {
      return null;
    }
  }

  /// Get screen height (or null if not available)
  static int? _getScreenHeight() {
    try {
      // We'll use a more accurate method in a real implementation
      return MediaQueryData.fromView(
              WidgetsBinding.instance.platformDispatcher.views.first)
          .size
          .height
          .toInt();
    } catch (e) {
      return null;
    }
  }

  /// Get screen density (or null if not available)
  static double? _getScreenDensity() {
    try {
      return WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
    } catch (e) {
      return null;
    }
  }
}
