# CustomFit Flutter SDK: Low-Level Design (LLD)

This document outlines the detailed technical implementation plan for each key file in the CustomFit Flutter SDK.

## 1. Core API Files

### 1.1 lib/customfit.dart

**Purpose**: Main entry point and public API for the SDK.

**Implementation Details**:
```dart
/// Main entry point for the CustomFit Flutter SDK
library customfit;

// Export public classes and functions
export 'src/client/cf_client.dart';
export 'src/config/core/cf_config.dart';
export 'src/core/model/cf_user.dart';
export 'src/core/error/cf_result.dart';
export 'src/analytics/event/event_data.dart';
export 'src/analytics/event/event_type.dart';
export 'src/analytics/event/event_properties_builder.dart';

// Hide implementation details from public API
export 'src/client/listener/feature_flag_listener.dart' show FeatureFlagChangeListener;
export 'src/client/listener/all_flags_listener.dart' show AllFlagsListener;
export 'src/network/connection/connection_status.dart' show ConnectionStatus;
```

**Key Functions**:
- Export all necessary public-facing classes
- Hide implementation details

### 1.2 lib/src/client/cf_client.dart

**Purpose**: Main client implementation and core API entry point.

**Implementation Details**:
```dart
class CFClient {
  // Internal state
  final String _sessionId;
  final CFConfig _config;
  final MutableCFConfig _mutableConfig;
  final HttpClient _httpClient;
  final SummaryManager _summaryManager;
  final EventTracker _eventTracker;
  final ConfigFetcher _configFetcher;
  final ConnectionManager _connectionManager;
  final BackgroundStateMonitor _backgroundStateMonitor;
  
  // Feature flag state
  final Map<String, dynamic> _configMap = {};
  final Map<String, List<Function>> _configListeners = {};
  
  // User information
  CFUser _user;

  // Private constructor
  CFClient._({
    required CFConfig config,
    required CFUser user,
  }) : 
    _config = config,
    _user = user,
    _sessionId = Uuid().v4(),
    _mutableConfig = MutableCFConfig(config),
    _httpClient = HttpClient(config),
    _connectionManager = ConnectionManager(config),
    _backgroundStateMonitor = DefaultBackgroundStateMonitor() {
      _summaryManager = SummaryManager(_sessionId, _httpClient, _user, _config);
      _eventTracker = EventTracker(_sessionId, _httpClient, _user, _summaryManager, _config);
      _configFetcher = ConfigFetcher(_httpClient, _config, _user);
      
      // Initialize SDK components
      _initialize();
  }

  // Initialization logic
  Future<void> _initialize() async {
    // Configure logging
    LogLevelUpdater.updateLogLevel(_mutableConfig.config);
    
    // Set initial offline mode
    if (_mutableConfig.offlineMode) {
      _configFetcher.setOffline(true);
      _connectionManager.setOfflineMode(true);
      Logger.i("CF client initialized in offline mode");
    }
    
    // Set up environment attributes
    if (_mutableConfig.autoEnvAttributesEnabled) {
      await _initializeEnvironmentAttributes();
    }
    
    // Set up connection status monitoring
    _setupConnectionStatusMonitoring();
    
    // Set up background state monitoring
    _setupBackgroundStateMonitoring();
    
    // Add user context
    _addMainUserContext();
    
    // Set up config change listener
    _setupConfigChangeListener();
    
    // Start periodic SDK settings check
    _startPeriodicSdkSettingsCheck();
    
    // Initial fetch of SDK settings
    await _checkSdkSettings();
  }

  // Factory method - public init API
  static Future<CFClient> init(CFConfig config, CFUser user) async {
    final client = CFClient._(config: config, user: user);
    // Wait for initialization to complete
    await client._waitForInitialization();
    return client;
  }

  // Feature flag methods
  String getString(String key, String fallbackValue) {
    return _getConfigValue(key, fallbackValue, (val) => val is String);
  }
  
  bool getBoolean(String key, bool fallbackValue) {
    return _getConfigValue(key, fallbackValue, (val) => val is bool);
  }
  
  num getNumber(String key, num fallbackValue) {
    return _getConfigValue(key, fallbackValue, (val) => val is num);
  }
  
  Map<String, dynamic> getJson(String key, Map<String, dynamic> fallbackValue) {
    return _getConfigValue(key, fallbackValue, 
      (val) => val is Map<String, dynamic> || (val is Map && val.keys.every((k) => k is String)));
  }
  
  // Implementation of config value getter
  T _getConfigValue<T>(String key, T fallbackValue, bool Function(dynamic) validator) {
    final value = _configMap[key];
    if (value != null && validator(value)) {
      return value as T;
    }
    return fallbackValue;
  }

  // Event tracking
  Future<CFResult<EventData>> trackEvent(String eventName, [Map<String, dynamic> properties = const {}]) {
    try {
      // Validate event name
      if (eventName.isEmpty) {
        return CFResult.error(
          "Event name cannot be blank", 
          category: ErrorCategory.validation
        );
      }
      
      // Delegate to event tracker
      return _eventTracker.trackEvent(eventName, properties);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Unexpected error tracking event: $eventName",
        "CFClient",
        ErrorSeverity.high
      );
      return CFResult.error(
        "Failed to track event", 
        exception: e, 
        category: ErrorCategory.internal
      );
    }
  }
  
  // Overload with builder pattern
  Future<CFResult<EventData>> trackEventWithBuilder(String eventName, 
      void Function(EventPropertiesBuilder) propertiesBuilder) async {
    try {
      final builder = EventPropertiesBuilder();
      propertiesBuilder(builder);
      return trackEvent(eventName, builder.build());
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error building properties for event: $eventName",
        "CFClient",
        ErrorSeverity.medium
      );
      return CFResult.error(
        "Failed to build event properties",
        exception: e,
        category: ErrorCategory.validation
      );
    }
  }

  // User property management
  void addUserProperty(String key, dynamic value) {
    _user = _user.addProperty(key, value);
    Logger.d("Added user property: $key = $value");
  }

  // Type-specific property methods
  void addStringProperty(String key, String value) {
    if (value.isEmpty) {
      throw ArgumentError("String value for '$key' cannot be blank");
    }
    addUserProperty(key, value);
  }

  void addNumberProperty(String key, num value) {
    addUserProperty(key, value);
  }

  void addBooleanProperty(String key, bool value) {
    addUserProperty(key, value);
  }

  void addDateProperty(String key, DateTime value) {
    addUserProperty(key, value);
  }

  void addGeoPointProperty(String key, double lat, double lon) {
    addUserProperty(key, {"lat": lat, "lon": lon});
  }

  // Network state management
  void setOffline() {
    _mutableConfig.setOfflineMode(true);
    _configFetcher.setOffline(true);
    _connectionManager.setOfflineMode(true);
    Logger.i("CF client is now in offline mode");
  }

  void setOnline() {
    _mutableConfig.setOfflineMode(false);
    _configFetcher.setOffline(false);
    _connectionManager.setOfflineMode(false);
    Logger.i("CF client is now in online mode");
  }

  // SDK cleanup - important to prevent memory leaks
  void shutdown() {
    // Unregister all listeners
    _connectionManager.shutdown();
    _backgroundStateMonitor.shutdown();
    
    // Shutdown timers
    _stopPeriodicSdkSettingsCheck();
    
    // Flush any pending data
    _eventTracker.flushEvents();
    _summaryManager.flushSummaries();
    
    Logger.i("CF client shut down");
  }
}
```

**Key Functions**:
- Initialize the SDK with configuration and user details
- Provide feature flag retrieval methods (getString, getBoolean, etc.)
- Event tracking with validation
- User property management
- Network state management (online/offline)
- Lifecycle management

### 1.3 lib/src/config/core/cf_config.dart

**Purpose**: Immutable configuration class with builder pattern.

**Implementation Details**:
```dart
class CFConfig {
  final String clientKey;
  // Event tracker configuration
  final int eventsQueueSize;
  final int eventsFlushTimeSeconds;
  final int eventsFlushIntervalMs;
  // Retry configuration
  final int maxRetryAttempts;
  final int retryInitialDelayMs;
  final int retryMaxDelayMs;
  final double retryBackoffMultiplier;
  // Summary manager configuration
  final int summariesQueueSize;
  final int summariesFlushTimeSeconds;
  final int summariesFlushIntervalMs;
  // SDK settings check configuration
  final int sdkSettingsCheckIntervalMs;
  // Network configuration
  final int networkConnectionTimeoutMs;
  final int networkReadTimeoutMs;
  // Logging configuration
  final bool loggingEnabled;
  final bool debugLoggingEnabled;
  final String logLevel;
  // Offline mode
  final bool offlineMode;
  // Background operation settings
  final bool disableBackgroundPolling;
  final int backgroundPollingIntervalMs;
  final bool useReducedPollingWhenBatteryLow;
  final int reducedPollingIntervalMs;
  final int maxStoredEvents;
  // Environment attributes
  final bool autoEnvAttributesEnabled;

  // Computed property for dimension ID
  String? get dimensionId => _extractDimensionIdFromToken(clientKey);

  // Private constructor - use builder pattern instead
  CFConfig._({
    required this.clientKey,
    this.eventsQueueSize = CFConstants.eventDefaults.queueSize,
    this.eventsFlushTimeSeconds = CFConstants.eventDefaults.flushTimeSeconds,
    this.eventsFlushIntervalMs = CFConstants.eventDefaults.flushIntervalMs,
    this.maxRetryAttempts = CFConstants.retryConfig.maxRetryAttempts,
    this.retryInitialDelayMs = CFConstants.retryConfig.initialDelayMs,
    this.retryMaxDelayMs = CFConstants.retryConfig.maxDelayMs,
    this.retryBackoffMultiplier = CFConstants.retryConfig.backoffMultiplier,
    this.summariesQueueSize = CFConstants.summaryDefaults.queueSize,
    this.summariesFlushTimeSeconds = CFConstants.summaryDefaults.flushTimeSeconds,
    this.summariesFlushIntervalMs = CFConstants.summaryDefaults.flushIntervalMs,
    this.sdkSettingsCheckIntervalMs = CFConstants.backgroundPolling.sdkSettingsCheckIntervalMs,
    this.networkConnectionTimeoutMs = CFConstants.network.connectionTimeoutMs,
    this.networkReadTimeoutMs = CFConstants.network.readTimeoutMs,
    this.loggingEnabled = true,
    this.debugLoggingEnabled = false,
    this.logLevel = CFConstants.logging.defaultLogLevel,
    this.offlineMode = false,
    this.disableBackgroundPolling = false,
    this.backgroundPollingIntervalMs = CFConstants.backgroundPolling.backgroundPollingIntervalMs,
    this.useReducedPollingWhenBatteryLow = true,
    this.reducedPollingIntervalMs = CFConstants.backgroundPolling.reducedPollingIntervalMs,
    this.maxStoredEvents = CFConstants.eventDefaults.maxStoredEvents,
    this.autoEnvAttributesEnabled = false,
  });

  // Extract dimension ID from token
  String? _extractDimensionIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonMap = jsonDecode(decoded) as Map<String, dynamic>;
      
      return jsonMap['dimension_id'] as String?;
    } catch (e) {
      Logger.w("Failed to extract dimension ID from token: $e");
      return null;
    }
  }

  // Static factory method from client key only
  static CFConfig fromClientKey(String clientKey) => Builder(clientKey).build();

  // Builder implementation for fluent API
  static Builder builder(String clientKey) => Builder(clientKey);
}

// Builder class for CFConfig
class Builder {
  final String clientKey;
  int eventsQueueSize = CFConstants.eventDefaults.queueSize;
  int eventsFlushTimeSeconds = CFConstants.eventDefaults.flushTimeSeconds;
  int eventsFlushIntervalMs = CFConstants.eventDefaults.flushIntervalMs;
  // Additional fields with default values...

  Builder(this.clientKey) {
    if (clientKey.isEmpty) {
      throw ArgumentError("Client key cannot be empty");
    }
  }

  // Builder methods
  Builder setEventsQueueSize(int size) {
    eventsQueueSize = size;
    return this;
  }

  Builder setEventsFlushTimeSeconds(int seconds) {
    eventsFlushTimeSeconds = seconds;
    return this;
  }

  Builder setEventsFlushIntervalMs(int ms) {
    eventsFlushIntervalMs = ms;
    return this;
  }

  // Additional builder methods...

  // Build method creates immutable CFConfig
  CFConfig build() {
    return CFConfig._(
      clientKey: clientKey,
      eventsQueueSize: eventsQueueSize,
      eventsFlushTimeSeconds: eventsFlushTimeSeconds,
      eventsFlushIntervalMs: eventsFlushIntervalMs,
      // Additional parameters...
    );
  }
}
```

**Key Functions**:
- Immutable configuration storage
- Builder pattern for easy configuration
- Default values from constants
- Token parsing for dimension ID extraction

### 1.4 lib/src/core/model/cf_user.dart

**Purpose**: User model defining identity and attributes.

**Implementation Details**:
```dart
class CFUser {
  final String userId;
  final Map<String, dynamic> properties;
  final DeviceContext? deviceContext;
  final ApplicationInfo? applicationInfo;

  CFUser({
    required this.userId,
    this.properties = const {},
    this.deviceContext,
    this.applicationInfo,
  });

  // Create a copy with added property
  CFUser addProperty(String key, dynamic value) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    updatedProperties[key] = value;
    return CFUser(
      userId: userId,
      properties: updatedProperties,
      deviceContext: deviceContext,
      applicationInfo: applicationInfo,
    );
  }

  // Create a copy with device context
  CFUser withDeviceContext(DeviceContext context) {
    return CFUser(
      userId: userId,
      properties: properties,
      deviceContext: context,
      applicationInfo: applicationInfo,
    );
  }

  // Create a copy with application info
  CFUser withApplicationInfo(ApplicationInfo info) {
    return CFUser(
      userId: userId,
      properties: properties,
      deviceContext: deviceContext,
      applicationInfo: info,
    );
  }

  // Get all user properties as a map (for API requests)
  Map<String, dynamic> toUserMap() {
    final map = {
      'user_id': userId,
      ...properties,
    };
    
    // Add device context if available
    deviceContext?.toMap().forEach((key, value) {
      map['device_$key'] = value;
    });
    
    // Add application info if available
    applicationInfo?.toMap().forEach((key, value) {
      map['app_$key'] = value;
    });
    
    return map;
  }

  // Factory method from JSON
  factory CFUser.fromJson(Map<String, dynamic> json) {
    return CFUser(
      userId: json['user_id'] as String,
      properties: (json['properties'] as Map<String, dynamic>?) ?? {},
      deviceContext: json['device_context'] != null
          ? DeviceContext.fromJson(json['device_context'] as Map<String, dynamic>)
          : null,
      applicationInfo: json['application_info'] != null
          ? ApplicationInfo.fromJson(json['application_info'] as Map<String, dynamic>)
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'properties': properties,
      if (deviceContext != null) 'device_context': deviceContext!.toJson(),
      if (applicationInfo != null) 'application_info': applicationInfo!.toJson(),
    };
  }
}
```

**Key Functions**:
- Store user identity and properties
- Immutable design with builder-like methods
- Integration with device and application context
- JSON serialization support

### 1.5 lib/src/core/error/cf_result.dart

**Purpose**: Result type for operation outcomes (success/error).

**Implementation Details**:
```dart
// Base result class
abstract class CFResult<T> {
  // Factory for success result
  static CFSuccess<T> success<T>(T data) => CFSuccess<T>(data);

  // Factory for error result
  static CFError<T> error<T>(
    String message, {
    dynamic exception,
    ErrorCategory category = ErrorCategory.unknown,
  }) =>
      CFError<T>(message, exception: exception, category: category);

  // Check if result is success
  bool get isSuccess;

  // Check if result is error
  bool get isError;

  // Execute callbacks based on result type
  CFResult<T> onSuccess(void Function(T data) action);
  CFResult<T> onError(void Function(CFError<T> error) action);

  // Transform to a new result type
  CFResult<R> map<R>(R Function(T data) transform);

  // Get value or fallback
  T getOrDefault(T defaultValue);

  // Pattern matching style handler
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(CFError<T> error) onError,
  });
}

// Success implementation
class CFSuccess<T> extends CFResult<T> {
  final T data;

  CFSuccess(this.data);

  @override
  bool get isSuccess => true;

  @override
  bool get isError => false;

  @override
  CFResult<T> onSuccess(void Function(T data) action) {
    action(data);
    return this;
  }

  @override
  CFResult<T> onError(void Function(CFError<T> error) action) {
    return this;
  }

  @override
  CFResult<R> map<R>(R Function(T data) transform) {
    return CFResult.success(transform(data));
  }

  @override
  T getOrDefault(T defaultValue) {
    return data;
  }

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(CFError<T> error) onError,
  }) {
    return onSuccess(data);
  }
}

// Error implementation
class CFError<T> extends CFResult<T> {
  final String message;
  final dynamic exception;
  final ErrorCategory category;

  CFError(
    this.message, {
    this.exception,
    this.category = ErrorCategory.unknown,
  });

  @override
  bool get isSuccess => false;

  @override
  bool get isError => true;

  @override
  CFResult<T> onSuccess(void Function(T data) action) {
    return this;
  }

  @override
  CFResult<T> onError(void Function(CFError<T> error) action) {
    action(this);
    return this;
  }

  @override
  CFResult<R> map<R>(R Function(T data) transform) {
    return CFResult.error<R>(message, exception: exception, category: category);
  }

  @override
  T getOrDefault(T defaultValue) {
    return defaultValue;
  }

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(CFError<T> error) onError,
  }) {
    return onError(this);
  }
}

// Error categories
enum ErrorCategory {
  network,
  serialization,
  validation,
  permission,
  timeout,
  internal,
  unknown,
}
```

**Key Functions**:
- Generic result type for all operations
- Success/Error variants
- Functional programming pattern with onSuccess/onError
- Error categorization
- Pattern matching with fold method 