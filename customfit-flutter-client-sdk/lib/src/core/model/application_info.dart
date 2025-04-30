import 'package:package_info_plus/package_info_plus.dart';

/// Collects and stores information about the application for use in targeting and analytics
class ApplicationInfo {
  /// Application name
  final String? appName;

  /// Application package name/identifier
  final String? packageName;

  /// Application version name (e.g., "1.2.3")
  final String? versionName;

  /// Application version code (numeric)
  final int? versionCode;

  /// When the app was first installed
  final String? installDate;

  /// When the app was last updated
  final String? lastUpdateDate;

  /// Build type (e.g., "debug", "release")
  final String? buildType;

  /// How many times the app has been launched
  final int launchCount;

  /// Additional custom attributes
  final Map<String, String> customAttributes;

  /// Constructor
  ApplicationInfo({
    this.appName,
    this.packageName,
    this.versionName,
    this.versionCode,
    this.installDate,
    this.lastUpdateDate,
    this.buildType,
    this.launchCount = 1,
    this.customAttributes = const {},
  });

  /// Creates an ApplicationInfo from a map representation
  factory ApplicationInfo.fromMap(Map<String, dynamic> map) {
    final rawCustomAttributes = map['custom_attributes'];
    final customAttributes = rawCustomAttributes is Map<String, dynamic>
        ? rawCustomAttributes
            .map((key, value) => MapEntry(key, value.toString()))
        : <String, String>{};

    return ApplicationInfo(
      appName: map['app_name'] as String?,
      packageName: map['package_name'] as String?,
      versionName: map['version_name'] as String?,
      versionCode: (map['version_code'] as num?)?.toInt(),
      installDate: map['install_date'] as String?,
      lastUpdateDate: map['last_update_date'] as String?,
      buildType: map['build_type'] as String?,
      launchCount: (map['launch_count'] as num?)?.toInt() ?? 0,
      customAttributes: customAttributes,
    );
  }

  /// Creates an ApplicationInfo from PackageInfo
  static Future<ApplicationInfo> fromPackageInfo(
      PackageInfo packageInfo) async {
    return ApplicationInfo(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      versionName: packageInfo.version,
      versionCode: int.tryParse(packageInfo.buildNumber),
      buildType:
          const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug',
    );
  }

  /// Converts the application info to a map for serialization
  Map<String, dynamic> toMap() {
    final map = {
      'app_name': appName,
      'package_name': packageName,
      'version_name': versionName,
      'version_code': versionCode,
      'install_date': installDate,
      'last_update_date': lastUpdateDate,
      'build_type': buildType,
      'launch_count': launchCount,
      'custom_attributes': customAttributes,
    };

    return map..removeWhere((key, value) => value == null);
  }
}
