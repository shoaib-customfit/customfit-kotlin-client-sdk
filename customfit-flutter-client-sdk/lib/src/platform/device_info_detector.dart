import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/model/device_context.dart';

/// Utility class for detecting device information.
class DeviceInfoDetector {
  // Plugins for device, package and connectivity info
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static final Connectivity _connectivity = Connectivity();

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
    final packageInfo = await PackageInfo.fromPlatform();
    final connectivityResult = await _connectivity.checkConnectivity();

    String networkType = "unknown";
    if (connectivityResult == ConnectivityResult.mobile) {
      networkType = "cellular";
    } else if (connectivityResult == ConnectivityResult.wifi) {
      networkType = "wifi";
    } else if (connectivityResult == ConnectivityResult.ethernet) {
      networkType = "ethernet";
    } else if (connectivityResult == ConnectivityResult.bluetooth) {
      networkType = "bluetooth";
    }

    return DeviceContext(
      manufacturer: androidInfo.manufacturer,
      model: androidInfo.model,
      osName: "Android",
      osVersion: androidInfo.version.release,
      sdkVersion: androidInfo.version.sdkInt.toString(),
      appId: packageInfo.packageName,
      appVersion: packageInfo.version,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: networkType,
      networkCarrier: "unknown", // Requires platform-specific code
    );
  }

  /// Get iOS device context
  static Future<DeviceContext> _getIosDeviceContext() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;
    final packageInfo = await PackageInfo.fromPlatform();
    final connectivityResult = await _connectivity.checkConnectivity();

    String networkType = "unknown";
    if (connectivityResult == ConnectivityResult.mobile) {
      networkType = "cellular";
    } else if (connectivityResult == ConnectivityResult.wifi) {
      networkType = "wifi";
    }

    return DeviceContext(
      manufacturer: "Apple",
      model: iosInfo.model,
      osName: "iOS",
      osVersion: iosInfo.systemVersion,
      sdkVersion: iosInfo.systemVersion,
      appId: packageInfo.packageName,
      appVersion: packageInfo.version,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: networkType,
      networkCarrier: "unknown", // Requires platform-specific code
    );
  }

  /// Get web device context
  static Future<DeviceContext> _getWebDeviceContext() async {
    final webInfo = await _deviceInfoPlugin.webBrowserInfo;
    final packageInfo = await PackageInfo.fromPlatform();
    final connectivityResult = await _connectivity.checkConnectivity();

    String networkType = "unknown";
    if (connectivityResult == ConnectivityResult.ethernet) {
      networkType = "ethernet";
    } else if (connectivityResult == ConnectivityResult.wifi) {
      networkType = "wifi";
    }

    return DeviceContext(
      manufacturer: webInfo.vendor ?? "unknown",
      model: webInfo.browserName.toString(),
      osName: webInfo.platform ?? "web",
      osVersion: webInfo.appVersion ?? "unknown",
      sdkVersion: webInfo.appVersion ?? "unknown",
      appId: packageInfo.packageName,
      appVersion: packageInfo.version,
      locale: webInfo.language ?? "unknown",
      timezone: DateTime.now().timeZoneName,
      screenWidth: _getScreenWidth(),
      screenHeight: _getScreenHeight(),
      screenDensity: _getScreenDensity(),
      networkType: networkType,
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
