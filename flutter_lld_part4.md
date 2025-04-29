# CustomFit Flutter SDK: Low-Level Design (LLD) - Part 4

## 4. Platform Integration Components

### 4.1 lib/src/platform/device_info_detector.dart

**Purpose**: Detect and collect device information across platforms.

**Implementation Details**:
```dart
class DeviceInfoDetector {
  // Device info plugin
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  // Constants
  static const String _source = "DeviceInfoDetector";
  
  // Get device context with platform-specific details
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
        return DeviceContext.createBasic();
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to detect device info",
        _source,
        ErrorSeverity.low
      );
      return DeviceContext.createBasic();
    }
  }
  
  // Get Android device context
  static Future<DeviceContext> _getAndroidDeviceContext() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    
    return DeviceContext(
      platform: "android",
      osVersion: androidInfo.version.release,
      deviceModel: androidInfo.model,
      deviceManufacturer: androidInfo.manufacturer,
      deviceId: androidInfo.id,
      deviceName: androidInfo.device,
      screenWidth: window.physicalSize.width ~/ window.devicePixelRatio,
      screenHeight: window.physicalSize.height ~/ window.devicePixelRatio,
      screenDensity: window.devicePixelRatio,
      sdkVersion: CFConstants.general.sdkVersion,
      locale: Platform.localeName,
      timeZone: DateTime.now().timeZoneName,
      appInstallTime: await _getAppInstallTime(),
    );
  }
  
  // Get iOS device context
  static Future<DeviceContext> _getIosDeviceContext() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;
    
    return DeviceContext(
      platform: "ios",
      osVersion: iosInfo.systemVersion,
      deviceModel: iosInfo.model,
      deviceManufacturer: "Apple",
      deviceId: iosInfo.identifierForVendor ?? "unknown",
      deviceName: iosInfo.name,
      screenWidth: window.physicalSize.width ~/ window.devicePixelRatio,
      screenHeight: window.physicalSize.height ~/ window.devicePixelRatio,
      screenDensity: window.devicePixelRatio,
      sdkVersion: CFConstants.general.sdkVersion,
      locale: Platform.localeName,
      timeZone: DateTime.now().timeZoneName,
      appInstallTime: await _getAppInstallTime(),
    );
  }
  
  // Get web device context
  static Future<DeviceContext> _getWebDeviceContext() async {
    final webInfo = await _deviceInfoPlugin.webBrowserInfo;
    
    return DeviceContext(
      platform: "web",
      osVersion: webInfo.appVersion ?? "unknown",
      deviceModel: webInfo.browserName.toString(),
      deviceManufacturer: webInfo.vendor ?? "unknown",
      deviceId: "web_${DateTime.now().millisecondsSinceEpoch}",
      deviceName: webInfo.userAgent ?? "unknown",
      screenWidth: window.physicalSize.width ~/ window.devicePixelRatio,
      screenHeight: window.physicalSize.height ~/ window.devicePixelRatio,
      screenDensity: window.devicePixelRatio,
      sdkVersion: CFConstants.general.sdkVersion,
      locale: webInfo.language ?? "unknown",
      timeZone: DateTime.now().timeZoneName,
      appInstallTime: await _getAppInstallTime(),
    );
  }
  
  // Get app install time (returns current time if not available)
  static Future<DateTime> _getAppInstallTime() async {
    try {
      if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        
        // Use Android-specific API to get install time
        final methodChannel = MethodChannel('customfit/app_info');
        final int? installTimeMs = await methodChannel.invokeMethod<int>(
          'getAppInstallTime',
          {'packageName': packageName}
        );
        
        if (installTimeMs != null) {
          return DateTime.fromMillisecondsSinceEpoch(installTimeMs);
        }
      } else if (Platform.isIOS) {
        // iOS doesn't provide direct access to install time
        // Use shared preferences as fallback
        final prefs = await SharedPreferences.getInstance();
        final installTime = prefs.getInt('cf_app_install_time');
        
        if (installTime != null) {
          return DateTime.fromMillisecondsSinceEpoch(installTime);
        } else {
          // First run - set install time
          final now = DateTime.now();
          await prefs.setInt('cf_app_install_time', now.millisecondsSinceEpoch);
          return now;
        }
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to get app install time",
        _source,
        ErrorSeverity.low
      );
    }
    
    // Fallback to current time
    return DateTime.now();
  }
}
```

**Key Functions**:
- Detect device information across platforms
- Handle platform differences (Android, iOS, Web)
- Collect device metrics
- Get app install time

### 4.2 lib/src/platform/application_info_detector.dart

**Purpose**: Detect and collect application information.

**Implementation Details**:
```dart
class ApplicationInfoDetector {
  // Constants
  static const String _source = "ApplicationInfoDetector";
  
  // Get application info
  static Future<ApplicationInfo?> detectApplicationInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      return ApplicationInfo(
        appId: packageInfo.packageName,
        appVersion: packageInfo.version,
        appBuild: packageInfo.buildNumber,
        appName: packageInfo.appName,
        launchCount: 1, // Initial launch count
        firstLaunchTime: DateTime.now(),
      );
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to detect application info",
        _source,
        ErrorSeverity.low
      );
      return null;
    }
  }
  
  // Get updated application info with incremented launch count
  static ApplicationInfo incrementLaunchCount(ApplicationInfo info) {
    return ApplicationInfo(
      appId: info.appId,
      appVersion: info.appVersion,
      appBuild: info.appBuild,
      appName: info.appName,
      launchCount: info.launchCount + 1,
      firstLaunchTime: info.firstLaunchTime,
    );
  }
}
```

**Key Functions**:
- Detect application package information
- Create application info model
- Manage app launch counting

### 4.3 lib/src/platform/app_state.dart

**Purpose**: Define application state enum.

**Implementation Details**:
```dart
enum AppState {
  /// App is in the foreground and visible to the user
  foreground,

  /// App is in the background but still running
  background,

  /// App is in the process of being terminated
  terminated
}

// Extension methods for converting between Flutter's AppLifecycleState
extension AppStateExtension on AppState {
  static AppState fromAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return AppState.foreground;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        return AppState.background;
      case AppLifecycleState.detached:
        return AppState.terminated;
      default:
        return AppState.foreground;
    }
  }
}
```

**Key Functions**:
- Define app state enum
- Map Flutter lifecycle states to app states

### 4.4 lib/src/platform/app_state_listener.dart

**Purpose**: Interface for app state change listeners.

**Implementation Details**:
```dart
abstract class AppStateListener {
  void onAppStateChanged(AppState newState);
}
```

**Key Functions**:
- Define app state change listener interface

### 4.5 lib/src/platform/battery_state.dart

**Purpose**: Define battery state enum.

**Implementation Details**:
```dart
enum BatteryState {
  /// Battery is in a full state (90% or above)
  full,

  /// Battery is in a normal state (between 20% and 90%)
  normal,

  /// Battery is in a low state (below 20%)
  low,

  /// Battery state is unknown
  unknown,
  
  /// Device is charging
  charging
}

// Extension methods for converting between battery_plus BatteryState
extension BatteryStateExtension on BatteryState {
  static BatteryState fromBatteryPlusState(battery_plus.BatteryState state, int level) {
    // If charging, return charging state regardless of level
    if (state == battery_plus.BatteryState.charging) {
      return BatteryState.charging;
    }
    
    // Otherwise determine state based on level
    if (level >= 90) {
      return BatteryState.full;
    } else if (level >= 20) {
      return BatteryState.normal;
    } else if (level > 0) {
      return BatteryState.low;
    } else {
      return BatteryState.unknown;
    }
  }
}
```

**Key Functions**:
- Define battery state enum
- Map battery_plus states to SDK battery states

### 4.6 lib/src/platform/battery_state_listener.dart

**Purpose**: Interface for battery state change listeners.

**Implementation Details**:
```dart
abstract class BatteryStateListener {
  void onBatteryStateChanged(BatteryState newState, int level);
}
```

**Key Functions**:
- Define battery state change listener interface

### 4.7 lib/src/platform/background_state_monitor.dart

**Purpose**: Abstract class for background state monitoring.

**Implementation Details**:
```dart
abstract class BackgroundStateMonitor {
  // Add app state listener
  void addAppStateListener(AppStateListener listener);
  
  // Remove app state listener
  void removeAppStateListener(AppStateListener listener);
  
  // Add battery state listener
  void addBatteryStateListener(BatteryStateListener listener);
  
  // Remove battery state listener
  void removeBatteryStateListener(BatteryStateListener listener);
  
  // Get current app state
  AppState getCurrentAppState();
  
  // Get current battery state
  BatteryState getCurrentBatteryState();
  
  // Get current battery level (0-100)
  int getCurrentBatteryLevel();
  
  // Clean up resources
  void shutdown();
}
```

**Key Functions**:
- Define interface for background state monitoring
- Manage app and battery state listeners

### 4.8 lib/src/platform/default_background_state_monitor.dart

**Purpose**: Default implementation of background state monitoring.

**Implementation Details**:
```dart
class DefaultBackgroundStateMonitor implements BackgroundStateMonitor, WidgetsBindingObserver {
  // App state
  AppState _currentAppState = AppState.foreground;
  
  // Battery state
  BatteryState _currentBatteryState = BatteryState.unknown;
  int _currentBatteryLevel = 100;
  
  // Listeners
  final List<AppStateListener> _appStateListeners = [];
  final List<BatteryStateListener> _batteryStateListeners = [];
  
  // Battery plugin
  final Battery _battery = Battery();
  StreamSubscription<battery_plus.BatteryState>? _batteryStateSubscription;
  
  // Constants
  static const String _source = "DefaultBackgroundStateMonitor";
  
  DefaultBackgroundStateMonitor() {
    _initialize();
  }
  
  // Initialize monitoring
  void _initialize() {
    // Register with WidgetsBinding for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize battery monitoring
    _initializeBatteryMonitoring();
  }
  
  // Initialize battery monitoring
  Future<void> _initializeBatteryMonitoring() async {
    try {
      // Get initial battery level
      _currentBatteryLevel = await _battery.batteryLevel;
      
      // Get initial battery state
      final batteryState = await _battery.batteryState;
      _updateBatteryState(batteryState);
      
      // Listen for battery state changes
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen(_updateBatteryState);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to initialize battery monitoring",
        _source,
        ErrorSeverity.low
      );
    }
  }
  
  // Update battery state
  void _updateBatteryState(battery_plus.BatteryState batteryState) async {
    try {
      // Get current battery level
      _currentBatteryLevel = await _battery.batteryLevel;
      
      // Map to our battery state enum
      final newState = BatteryStateExtension.fromBatteryPlusState(
        batteryState,
        _currentBatteryLevel
      );
      
      if (newState != _currentBatteryState) {
        _currentBatteryState = newState;
        _notifyBatteryStateListeners();
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update battery state",
        _source,
        ErrorSeverity.low
      );
    }
  }
  
  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final newAppState = AppStateExtension.fromAppLifecycleState(state);
    
    if (newAppState != _currentAppState) {
      _currentAppState = newAppState;
      _notifyAppStateListeners();
    }
  }
  
  // Notify app state listeners
  void _notifyAppStateListeners() {
    for (final listener in _appStateListeners) {
      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying app state listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Notify battery state listeners
  void _notifyBatteryStateListeners() {
    for (final listener in _batteryStateListeners) {
      try {
        listener.onBatteryStateChanged(_currentBatteryState, _currentBatteryLevel);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying battery state listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Add app state listener
  @override
  void addAppStateListener(AppStateListener listener) {
    if (!_appStateListeners.contains(listener)) {
      _appStateListeners.add(listener);
      
      // Immediately notify with current state
      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new app state listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Remove app state listener
  @override
  void removeAppStateListener(AppStateListener listener) {
    _appStateListeners.remove(listener);
  }
  
  // Add battery state listener
  @override
  void addBatteryStateListener(BatteryStateListener listener) {
    if (!_batteryStateListeners.contains(listener)) {
      _batteryStateListeners.add(listener);
      
      // Immediately notify with current state
      try {
        listener.onBatteryStateChanged(_currentBatteryState, _currentBatteryLevel);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new battery state listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Remove battery state listener
  @override
  void removeBatteryStateListener(BatteryStateListener listener) {
    _batteryStateListeners.remove(listener);
  }
  
  // Get current app state
  @override
  AppState getCurrentAppState() => _currentAppState;
  
  // Get current battery state
  @override
  BatteryState getCurrentBatteryState() => _currentBatteryState;
  
  // Get current battery level
  @override
  int getCurrentBatteryLevel() => _currentBatteryLevel;
  
  // Clean up resources
  @override
  void shutdown() {
    WidgetsBinding.instance.removeObserver(this);
    _batteryStateSubscription?.cancel();
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
}
```

**Key Functions**:
- Monitor app lifecycle changes
- Monitor battery state and level changes
- Notify registered listeners of state changes
- Clean up resources when no longer needed 