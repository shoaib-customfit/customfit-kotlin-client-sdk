import 'dart:io';

/// Represents device and operating system information for context-aware evaluation
class DeviceContext {
  /// Device manufacturer
  final String? manufacturer;

  /// Device model
  final String? model;

  /// Operating system name (e.g., "Android", "iOS")
  final String? osName;

  /// Operating system version
  final String? osVersion;

  /// SDK version
  final String sdkVersion;

  /// Application identifier
  final String? appId;

  /// Application version
  final String? appVersion;

  /// Device locale
  final String? locale;

  /// Device timezone
  final String? timezone;

  /// Device screen width in pixels
  final int? screenWidth;

  /// Device screen height in pixels
  final int? screenHeight;

  /// Device screen density (DPI)
  final double? screenDensity;

  /// Network type (e.g., "wifi", "cellular")
  final String? networkType;

  /// Network carrier
  final String? networkCarrier;

  /// Additional custom attributes
  final Map<String, dynamic> customAttributes;

  /// Constructor
  DeviceContext({
    this.manufacturer,
    this.model,
    this.osName,
    this.osVersion,
    this.sdkVersion = '1.0.0',
    this.appId,
    this.appVersion,
    this.locale,
    this.timezone,
    this.screenWidth,
    this.screenHeight,
    this.screenDensity,
    this.networkType,
    this.networkCarrier,
    this.customAttributes = const {},
  });

  /// Creates a basic device context with system properties
  static DeviceContext createBasic() {
    return DeviceContext(
      osName: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
    );
  }

  /// Creates a DeviceContext from a map representation
  factory DeviceContext.fromMap(Map<String, dynamic> map) {
    return DeviceContext(
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String?,
      osName: map['os_name'] as String?,
      osVersion: map['os_version'] as String?,
      sdkVersion: map['sdk_version'] as String? ?? '1.0.0',
      appId: map['app_id'] as String?,
      appVersion: map['app_version'] as String?,
      locale: map['locale'] as String?,
      timezone: map['timezone'] as String?,
      screenWidth: (map['screen_width'] as num?)?.toInt(),
      screenHeight: (map['screen_height'] as num?)?.toInt(),
      screenDensity: (map['screen_density'] as num?)?.toDouble(),
      networkType: map['network_type'] as String?,
      networkCarrier: map['network_carrier'] as String?,
      customAttributes: (map['custom_attributes'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converts the device context to a map for sending to the API
  Map<String, dynamic> toMap() {
    final map = {
      'manufacturer': manufacturer,
      'model': model,
      'os_name': osName,
      'os_version': osVersion,
      'sdk_version': sdkVersion,
      'app_id': appId,
      'app_version': appVersion,
      'locale': locale,
      'timezone': timezone,
      'screen_width': screenWidth,
      'screen_height': screenHeight,
      'screen_density': screenDensity,
      'network_type': networkType,
      'network_carrier': networkCarrier,
      'custom_attributes': customAttributes,
    };

    return map..removeWhere((key, value) => value == null);
  }
} 