import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/model/application_info.dart';

/// Utility class for detecting application information.
class ApplicationInfoDetector {
  // Constants
  // ignore: unused_field
  static const String _source = "ApplicationInfoDetector";

  /// Get application info
  static Future<ApplicationInfo?> detectApplicationInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      return ApplicationInfo(
        appName: packageInfo.appName,
        packageName: packageInfo.packageName,
        versionName: packageInfo.version,
        versionCode: int.tryParse(packageInfo.buildNumber),
      );
    } catch (e) {
      debugPrint("Failed to detect application info: $e");
      return null;
    }
  }

  /// Get updated application info with incremented launch count
  static ApplicationInfo incrementLaunchCount(ApplicationInfo info) {
    return ApplicationInfo(
      appName: info.appName,
      packageName: info.packageName,
      versionName: info.versionName,
      versionCode: info.versionCode,
      launchCount: (info.launchCount + 1),
      installDate: info.installDate,
      lastUpdateDate: info.lastUpdateDate,
      buildType: info.buildType,
      customAttributes: info.customAttributes,
    );
  }
}
