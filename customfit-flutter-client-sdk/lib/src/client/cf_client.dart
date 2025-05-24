// lib/src/client/cf_client.dart

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../analytics/event/event_tracker.dart';
import '../analytics/summary/summary_manager.dart';
import '../client/listener/all_flags_listener.dart';
import '../client/listener/feature_flag_change_listener.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/environment_manager.dart';
import '../client/managers/listener_manager.dart';
import '../client/managers/user_manager.dart';
import '../config/core/cf_config.dart';
import '../config/core/mutable_cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/error/error_category.dart';
import '../core/session/session_manager.dart';
import '../../logging/log_level_updater.dart';
import '../../logging/logger.dart';
import '../core/model/application_info.dart';
import '../core/model/cf_user.dart';
import '../core/model/device_context.dart';
import '../core/model/evaluation_context.dart';
import '../core/model/context_type.dart';
import '../network/config_fetcher.dart';
import '../network/http_client.dart';
import '../network/connection/connection_information.dart';
import '../network/connection/connection_manager_impl.dart';
import '../network/connection/connection_status.dart';
import '../network/connection/connection_status_listener.dart';
import '../platform/app_state.dart';
import '../platform/app_state_listener.dart';
import '../platform/background_state_monitor.dart';
import '../platform/default_background_state_monitor.dart';
import '../constants/cf_constants.dart';

/// Main SDK client orchestrating analytics, config, and environment.
class CFClient {
  static const _source = 'CFClient';

  // Singleton implementation
  static CFClient? _instance;
  static bool _isInitializing = false;
  static Completer<CFClient>? _initializationCompleter;

  /// Initialize or get the singleton instance of CFClient
  /// This method ensures only one instance exists and handles concurrent initialization attempts
  static Future<CFClient> initialize(CFConfig config, CFUser user) async {
    // Fast path: if already initialized, return existing instance
    if (_instance != null) {
      Logger.i('CFClient singleton already exists, returning existing instance');
      return _instance!;
    }

    // If currently initializing, wait for existing initialization
    if (_isInitializing && _initializationCompleter != null) {
      Logger.i('CFClient initialization in progress, waiting for completion...');
      return _initializationCompleter!.future;
    }

    // Start new initialization
    Logger.i('Starting CFClient singleton initialization...');
    _isInitializing = true;
    _initializationCompleter = Completer<CFClient>();

    try {
      // Create the instance
      final newInstance = CFClient._(config, user);

      // Wait for SDK settings initialization to complete
      await newInstance._sdkSettingsCompleter.future;

      // Store the singleton instance
      _instance = newInstance;
      _isInitializing = false;

      Logger.i('CFClient singleton initialized successfully');
      _initializationCompleter!.complete(newInstance);
      return newInstance;
    } catch (e) {
      _isInitializing = false;
      _initializationCompleter = null;

      Logger.e('Failed to initialize CFClient singleton: $e');
      _initializationCompleter!.completeError(e);
      rethrow;
    }
  }

  /// Get the current singleton instance if it exists
  static CFClient? getInstance() {
    return _instance;
  }

  /// Check if the singleton instance is initialized
  static bool isInitialized() {
    return _instance != null;
  }

  /// Check if initialization is currently in progress
  static bool isInitializing() {
    return _isInitializing;
  }

  /// Shutdown and clear the singleton instance
  static Future<void> shutdownSingleton() async {
    if (_instance != null) {
      Logger.i('Shutting down CFClient singleton...');
      await _instance!.shutdown();
      _instance = null;
      _isInitializing = false;
      _initializationCompleter = null;
      Logger.i('CFClient singleton shutdown complete');
    }
  }

  /// Force reinitialize the singleton with new configuration
  static Future<CFClient> reinitialize(CFConfig config, CFUser user) async {
    Logger.i('Reinitializing CFClient singleton...');
    await shutdownSingleton();
    return initialize(config, user);
  }

  /// @deprecated Use initialize() instead
  @Deprecated('Use initialize() instead')
  static Future<CFClient> init(CFConfig config, CFUser user) async {
    Logger.w('CFClient.init() is deprecated, use CFClient.initialize() instead');
    return initialize(config, user);
  }

  /// Create a detached (non-singleton) instance of CFClient
  /// Use this only if you specifically need multiple instances (not recommended)
  /// Most applications should use init() for singleton pattern
  static CFClient createDetached(CFConfig config, CFUser user) {
    Logger.w('Creating detached CFClient instance - this bypasses singleton pattern!');
    return CFClient._(config, user);
  }

  /// Factory method to create a new CFClient instance
  @Deprecated('Use init() for singleton pattern or createDetached() for non-singleton instances')
  static CFClient create(CFConfig config, CFUser user) {
    return CFClient._(config, user);
  }

  String _sessionId;
  final MutableCFConfig _mutableConfig;
  // ignore: unused_field
  final HttpClient _httpClient;

  /// Managers exposed to users
  final SummaryManager summaryManager;
  final EventTracker eventTracker;
  final ConfigFetcher configFetcher;

  /// Core managers
  final ConfigManager configManager;
  final UserManager userManager;
  final EnvironmentManager environmentManager;
  final ListenerManager listenerManager;

  /// Connectivity and background
  final ConnectionManagerImpl connectionManager;
  final BackgroundStateMonitor backgroundStateMonitor;

  /// Session manager for handling session lifecycle
  SessionManager? _sessionManager;

  /// Feature config and flag listeners
  final Map<String, List<void Function(dynamic)>> _configListeners = {};

  // This field is intentionally unused in the current implementation
  // but will be used in future versions for feature flag listeners
  @pragma('vm:entry-point')
  // ignore: unused_field, will be used in future implementations
  final Map<String, List<FeatureFlagChangeListener>> _featureFlagListeners =
      const {};
  // ignore: unused_field
  final Set<AllFlagsListener> _allFlagsListeners = const {};

  /// Contexts, device/app info
  final Map<String, EvaluationContext> _contexts = {};
  // ignore: unused_field
  late DeviceContext _deviceContext;
  // ignore: unused_field
  ApplicationInfo? _applicationInfo;

  /// Current user reference - marked as unused
  // ignore: unused_field
  final CFUser _user;

  /// Internal SDK settings tracking
  Timer? _sdkSettingsTimer;
  String? _previousLastModified;
  final Map<String, dynamic> _configMap = {};
  final _configLock = Object();
  final Completer<void> _sdkSettingsCompleter = Completer<void>();

  CFClient._(CFConfig config, CFUser user)
      : _sessionId = const Uuid().v4(),
        _mutableConfig = MutableCFConfig(config),
        _httpClient = HttpClient(config),
        connectionManager = ConnectionManagerImpl(config),
        backgroundStateMonitor = DefaultBackgroundStateMonitor(),
        _user = user,
        summaryManager =
            SummaryManager(const Uuid().v4(), HttpClient(config), user, config),
        eventTracker = EventTracker(HttpClient(config),
            ConnectionManagerImpl(config), user, const Uuid().v4(), config,
            summaryManager: SummaryManager(
                const Uuid().v4(), HttpClient(config), user, config)),
        // Pass CFConfig directly to ConfigFetcher
        configFetcher = ConfigFetcher(HttpClient(config), config, user),
        // Initialize core managers
        userManager = UserManagerImpl(user),
        // Create a new ConfigFetcher instance for ConfigManager
        configManager = ConfigManagerImpl(
            config: config,
            configFetcher: ConfigFetcher(HttpClient(config), config, user)),
        environmentManager = EnvironmentManagerImpl(
            backgroundStateMonitor: DefaultBackgroundStateMonitor(),
            userManager: UserManagerImpl(user)),
        listenerManager = ListenerManagerImpl() {
    // Configure logging
    LogLevelUpdater.updateLogLevel(_mutableConfig.config);

    // Offline mode
    if (_mutableConfig.offlineMode) {
      configFetcher.setOffline(true);
      connectionManager.setOfflineMode(true);
      Logger.i('CF client initialized in offline mode');
    }

    // Auto environment attributes
    if (_mutableConfig.autoEnvAttributesEnabled) {
      _initializeEnvironmentAttributes(user);
    }

    // Setup monitors
    _setupConnectionListeners();
    _setupBackgroundListeners();

    // Add main user context
    _addMainUserContext(user);

    // Initialize SessionManager
    _initializeSessionManager();

    // SDK settings polling
    _startPeriodicSdkSettingsCheck();
    _initialSdkSettingsCheck();
  }

  /// Initialize SessionManager with configuration
  void _initializeSessionManager() {
    // Create session configuration based on CFConfig defaults
    const sessionConfig = SessionConfig(
      maxSessionDurationMs: 60 * 60 * 1000, // 1 hour default
      minSessionDurationMs: 5 * 60 * 1000,  // 5 minutes minimum
      backgroundThresholdMs: 15 * 60 * 1000, // 15 minutes background threshold
      rotateOnAppRestart: true,
      rotateOnAuthChange: true,
      sessionIdPrefix: 'cf_session',
      enableTimeBasedRotation: true,
    );

    // Initialize SessionManager asynchronously
    SessionManager.initialize(config: sessionConfig).then((result) {
      if (result.isSuccess) {
        _sessionManager = result.getOrNull();
        if (_sessionManager != null) {
          // Get the current session ID
          _sessionId = _sessionManager!.getCurrentSessionId();

          // Set up session rotation listener
          final listener = _CFClientSessionListener(this);
          _sessionManager!.addListener(listener);

          Logger.i('🔄 SessionManager initialized with session: $_sessionId');
        }
      } else {
        Logger.e('Failed to initialize SessionManager: ${result.getErrorMessage()}');
      }
    }).catchError((e) {
      Logger.e('SessionManager initialization error: $e');
    });
  }

  /// Update session ID in all managers that use it
  void _updateSessionIdInManagers(String sessionId) {
    // TODO: EventTracker and SummaryManager don't have updateSessionId methods
    // These would need to be enhanced to support dynamic session ID updates
    // For now, we'll just log the session change

    _sessionId = sessionId;
    Logger.d('Updated session ID in managers: $sessionId');
  }

  /// Track session rotation as an analytics event
  void _trackSessionRotationEvent(String? oldSessionId, String newSessionId, RotationReason reason) {
    final properties = <String, dynamic>{
      'old_session_id': oldSessionId ?? 'none',
      'new_session_id': newSessionId,
      'rotation_reason': reason.description,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    trackEvent('cf_session_rotated', properties: properties);
  }

  /// Initialize application and device context automatically when autoEnvAttributesEnabled is true
  void _initializeEnvironmentAttributes(CFUser user) {
    if (!_mutableConfig.autoEnvAttributesEnabled) {
      Logger.d('Auto environment attributes disabled, skipping automatic collection');
      return;
    }

    Logger.d('Auto environment attributes enabled, collecting device and application info');

    // Collect device context automatically
    final deviceContext = _collectDeviceContext(user.device);
    if (deviceContext != null) {
      userManager.updateDeviceContext(deviceContext);
      _deviceContext = deviceContext;
      Logger.d('Auto-collected device context: ${deviceContext.manufacturer} ${deviceContext.model}');
    }

    // Collect application info automatically
    final appInfo = _collectApplicationInfo(user.application);
    if (appInfo != null) {
      userManager.updateApplicationInfo(appInfo);
      Logger.d('Auto-collected application info: ${appInfo.appName} v${appInfo.versionName}');
    }
  }

  /// Collect device context information automatically
  DeviceContext? _collectDeviceContext(DeviceContext? existingContext) {
    try {
      // Start with existing context or create new one
      final context = existingContext ?? DeviceContext();
      
      // TODO: Implement actual device info collection using platform channels
      // For now, return basic Flutter/Dart information
      return DeviceContext(
        manufacturer: context.manufacturer ?? 'Unknown',
        model: context.model ?? 'Unknown',
        osName: context.osName ?? 'Flutter',
        osVersion: context.osVersion ?? 'Unknown',
        sdkVersion: '1.0.0',
        locale: context.locale,
        timezone: context.timezone,
        customAttributes: context.customAttributes,
      );
    } catch (e) {
      Logger.e('Failed to collect device context: $e');
      return null;
    }
  }

  /// Collect application info automatically
  ApplicationInfo? _collectApplicationInfo(ApplicationInfo? existingInfo) {
    try {
      // Start with existing info or create new one
      final info = existingInfo ?? ApplicationInfo();
      
      // TODO: Implement actual app info collection using package_info_plus
      // For now, return basic information
      return ApplicationInfo(
        appName: info.appName ?? 'Flutter App',
        packageName: info.packageName ?? 'com.example.app',
        versionName: info.versionName ?? '1.0.0',
        versionCode: info.versionCode ?? 1,
        buildType: info.buildType ?? 'debug',
        launchCount: info.launchCount + 1,
        customAttributes: info.customAttributes,
      );
    } catch (e) {
      Logger.e('Failed to collect application info: $e');
      return null;
    }
  }

  /// Setup connection status forwarding
  void _setupConnectionListeners() {
    connectionManager.addConnectionStatusListener(
      _CustomConnectionStatusListener(onStatusChanged: (status, info) {
        Logger.d('Connection status changed: $status');
      }),
    );
  }

  /// Setup background and battery listeners
  void _setupBackgroundListeners() {
    backgroundStateMonitor.addAppStateListener(
      _CustomAppStateListener(onStateChanged: (state) {
        if (state == AppState.background) {
          _pausePolling();
          // Notify SessionManager about background transition
          _sessionManager?.onAppBackground();
        } else if (state == AppState.foreground) {
          _resumePolling();
          _checkSdkSettings();
          // Notify SessionManager about foreground transition
          _sessionManager?.onAppForeground();
          // Update session activity
          _sessionManager?.updateActivity();
        }
      }),
    );
  }

  void _addMainUserContext(CFUser user) {
    final ctx = EvaluationContext(
        type: ContextType.user, key: user.userCustomerId ?? _sessionId);
    _contexts['user'] = ctx;
  }

  /// Periodic SDK settings
  void _startPeriodicSdkSettingsCheck() {
    // DISABLED - We're using ConfigManager for SDK settings polling instead
    // This avoids duplicate polling which was causing continuous network requests

    Logger.d(
        'SDK settings polling via CFClient is disabled to avoid duplicate polling with ConfigManager');

    // Keeping this commented code for reference
    /*
    // Ensure timer is canceled before creating a new one
    if (_sdkSettingsTimer != null) {
      Logger.d('Canceling existing SDK settings timer');
      _sdkSettingsTimer!.cancel();
      _sdkSettingsTimer = null;
    }

    // Use the constant value from CFConstants.backgroundPolling.sdkSettingsCheckIntervalMs (5 minutes)
    // For web testing environments, use a shorter interval during development
    final pollingIntervalMs = kDebugMode && kIsWeb
        ? 60000 // 1 minute for web testing in debug mode
        : CFConstants.backgroundPolling.sdkSettingsCheckIntervalMs;

    Logger.d(
        'Starting SDK settings check timer with interval $pollingIntervalMs ms');

    _sdkSettingsTimer = Timer.periodic(
      Duration(milliseconds: pollingIntervalMs),
      (_) {
        Logger.d('Timer triggered SDK settings check');
        _checkSdkSettings();
      },
    );
    */
  }

  void _pausePolling() {
    // No-op since we're using ConfigManager for polling
    Logger.d('Pause polling request ignored - using ConfigManager for polling');
  }

  void _resumePolling() {
    // No-op since we're using ConfigManager for polling
    Logger.d(
        'Resume polling request ignored - using ConfigManager for polling');
  }

  void _initialSdkSettingsCheck() async {
    // Check once without relying on timer
    Logger.d('Performing initial SDK settings check (one-time)');
    await _checkSdkSettings();

    // Complete the completer to signal initialization is done
    if (!_sdkSettingsCompleter.isCompleted) {
      _sdkSettingsCompleter.complete();
    }

    // Log that future checks will be handled by ConfigManager
    Logger.d(
        'Initial SDK settings check complete. Future checks will be handled by ConfigManager.');
  }

  Future<void> _checkSdkSettings() async {
    try {
      // Get the correct SDK settings URL to match Kotlin implementation
      final String dimensionId = _mutableConfig.config.dimensionId ?? "default";
      final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
          .replaceFirst('%s', dimensionId);
      final sdkUrl = "${CFConstants.api.sdkSettingsBaseUrl}$sdkSettingsPath";

      Logger.d('Fetching SDK settings from: $sdkUrl');

      // Match Kotlin implementation by passing URL to fetchMetadata
      final metaResult = await configFetcher.fetchMetadata(sdkUrl);

      // Unwrap directly using null coalescing
      final headers = metaResult.getOrNull() ?? {};
      final lastMod = headers['Last-Modified'];

      Logger.d(
          'SDK settings metadata received, Last-Modified: $lastMod, previous: $_previousLastModified');

      // Handle unchanged case (304 Not Modified)
      if (lastMod == 'unchanged') {
        Logger.d('Metadata unchanged (304), skipping config fetch');
        return;
      }

      // Only fetch configs if Last-Modified has changed (like Kotlin implementation)
      if (lastMod != null && lastMod != _previousLastModified) {
        _previousLastModified = lastMod;
        Logger.d('Last-Modified header changed, fetching configs');
        await _fetchAndProcessConfigs(lastModified: lastMod);
      } else if (_configMap.isEmpty && lastMod != null) {
        // If we've never fetched configs, do it at least once with last-modified header
        Logger.d(
            'First run or empty config, fetching configs with Last-Modified: $lastMod');
        await _fetchAndProcessConfigs(lastModified: lastMod);
      } else {
        Logger.d('No change in Last-Modified, skipping config fetch');
      }
    } catch (e) {
      ErrorHandler.handleException(e, 'SDK settings check failed',
          source: _source, severity: ErrorSeverity.medium);
    }
  }

  // Extract config fetching logic to a separate method for reuse
  Future<void> _fetchAndProcessConfigs({String? lastModified}) async {
    try {
      Logger.d('Fetching user configs with Last-Modified: $lastModified');
      final success =
          await configFetcher.fetchConfig(lastModified: lastModified);

      if (success) {
        Logger.d('Successfully fetched user configs');
        // Try to get configs
        try {
          final configsResult = configFetcher.getConfigs();
          final Map<String, dynamic> configs = configsResult.getOrNull() ?? {};
          Logger.d('Processing ${configs.length} configs');
          _updateConfigMap(configs);
        } catch (e) {
          Logger.e('Failed to process configs: $e');
        }
      } else {
        Logger.e('Failed to fetch user configs');
      }
    } catch (e) {
      Logger.e('Error in fetch and process configs: $e');
    }
  }

  void _updateConfigMap(Map<String, dynamic> newConfigs) {
    // Critical section for thread safety
    _configMap.clear();
    _configMap.addAll(newConfigs);

    Logger.d('Config map updated with ${newConfigs.length} configs');

    // Enhanced logging for key config values, like hero_text for debugging
    if (newConfigs.containsKey('hero_text')) {
      final heroText = newConfigs['hero_text'];
      if (heroText is Map<String, dynamic> &&
          heroText.containsKey('variation')) {
        Logger.i(
            '🚩 Received hero_text update: ${heroText['variation']} (version: ${heroText['version'] ?? 'unknown'})');
      }
    }

    // Instead of handling notifications here, pass the config updates to ConfigManager
    // to ensure listeners registered there are properly notified
    if (configManager is ConfigManagerImpl) {
      Logger.d('Delegating config update notification to ConfigManager');
      (configManager as ConfigManagerImpl).updateConfigsFromClient(newConfigs);
    } else {
      Logger.e(
          'ConfigManager is not of expected type, notifications may not work properly');
    }
  }

  /// Add a config listener for a specific feature flag
  void addConfigListener<T>(String key, void Function(T) listener) {
    Logger.d('Registering config listener for key: $key');
    configManager.addConfigListener<T>(key, listener);
  }

  /// Remove a config listener for a specific feature flag
  void removeConfigListener(String key) {
    Logger.d('Removing all config listeners for key: $key');
    configManager.clearConfigListeners(key);
  }

  /// Clear all listeners for a specific configuration
  void clearConfigListeners(String key) {
    Logger.d('Clearing all config listeners for key: $key');
    configManager.clearConfigListeners(key);
  }

  /// Add feature flag listener (matches Kotlin addFeatureFlagListener)
  void addFeatureFlagListener(String flagKey, void Function(String, dynamic, dynamic) listener) {
    Logger.d('Adding feature flag listener for key: $flagKey');
    final wrapper = _FeatureFlagListenerWrapper(listener);
    listenerManager.registerFeatureFlagListener(flagKey, wrapper);
  }

  /// Remove feature flag listener (matches Kotlin removeFeatureFlagListener)
  void removeFeatureFlagListener(String flagKey, void Function(String, dynamic, dynamic) listener) {
    Logger.d('Removing feature flag listener for key: $flagKey');
    final wrapper = _FeatureFlagListenerWrapper(listener);
    listenerManager.unregisterFeatureFlagListener(flagKey, wrapper);
  }

  /// Add all flags listener (matches Kotlin addAllFlagsListener)
  void addAllFlagsListener(void Function(Map<String, dynamic>, Map<String, dynamic>) listener) {
    Logger.d('Adding all flags listener');
    final wrapper = _AllFlagsListenerWrapper(listener);
    listenerManager.registerAllFlagsListener(wrapper);
  }

  /// Remove all flags listener (matches Kotlin removeAllFlagsListener)
  void removeAllFlagsListener(void Function(Map<String, dynamic>, Map<String, dynamic>) listener) {
    Logger.d('Removing all flags listener');
    final wrapper = _AllFlagsListenerWrapper(listener);
    listenerManager.unregisterAllFlagsListener(wrapper);
  }

  /// Get a feature flag value
  T getFeatureFlag<T>(String key, T defaultValue) {
    final value = configManager.getConfigValue<T>(key, defaultValue);
    if (value == defaultValue) {
      Logger.d('getFeatureFlag: Using default value for key: $key');
    }
    return value;
  }

  /// Get a string value from config
  String getString(String key, String defaultValue) {
    final value = configManager.getString(key, defaultValue);
    if (value == defaultValue) {
      Logger.d('getString: Using default value for key: $key');
    }
    return value;
  }

  /// Get a boolean value from config
  bool getBoolean(String key, bool defaultValue) {
    final value = configManager.getBoolean(key, defaultValue);
    if (value == defaultValue) {
      Logger.d('getBoolean: Using default value for key: $key');
    }
    return value;
  }

  /// Force a manual fetch of configs
  Future<CFResult<void>> trackEvent(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    try {
      // Pass the correct user to the event tracker without creating a temporary event
      return await eventTracker
          .trackEvent(eventType, properties ?? {})
          .then((_) => CFResult.success(null));
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to track event',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error('Failed to track event: ${e.toString()}');
    }
  }

  /// Shutdown the client
  Future<void> shutdown() async {
    Logger.i('Shutting down CF client');

    // Cancel SDK settings timer
    _sdkSettingsTimer?.cancel();

    // Shutdown managers
    connectionManager.shutdown();
    backgroundStateMonitor.shutdown();
    environmentManager.shutdown();

    // Shutdown SessionManager
    SessionManager.shutdown();
    _sessionManager = null;

    // Clear listeners if we had implemented them
    // Not implemented yet in Flutter SDK

    // Flush any pending events and summaries
    try {
      // First flush summaries
      await _flushSummaries().then((result) {
        if (!result.isSuccess) {
          Logger.w(
              'Failed to flush summaries during shutdown: ${result.getErrorMessage()}');
        } else {
          Logger.i('Successfully flushed summaries during shutdown');
        }
      });

      // Then flush events
      await _flushEvents().then((result) {
        if (!result.isSuccess) {
          Logger.w(
              'Failed to flush events during shutdown: ${result.getErrorMessage()}');
        } else {
          Logger.i('Successfully flushed events during shutdown');
        }
      });
    } catch (e) {
      ErrorHandler.handleException(e, 'Error flushing during shutdown',
          source: _source, severity: ErrorSeverity.medium);
    }

    Logger.i('CF client shutdown complete');
  }

  /// Manually flushes the events queue to the server
  /// Useful for immediately sending tracked events without waiting for the automatic flush
  ///
  /// @return CFResult containing the number of events flushed or error details
  Future<CFResult<int>> _flushEvents() async {
    try {
      Logger.i('Manually flushing events');

      // First flush summaries
      final summaryResult = await summaryManager.flushSummaries();
      if (!summaryResult.isSuccess) {
        Logger.w(
            'Failed to flush summaries before flushing events: ${summaryResult.getErrorMessage()}');
      }

      // Then flush events
      final flushResult = await eventTracker.flush();
      if (flushResult.isSuccess) {
        // Since our EventTracker.flush() doesn't return count directly,
        // let's just return a success with a dummy count of 1 for now
        // In a real implementation, we would return the actual count
        Logger.i('Successfully flushed events');
        return CFResult.success(1);
      } else {
        final errorMsg =
            'Failed to flush events: ${flushResult.getErrorMessage()}';
        Logger.e(errorMsg);
        return CFResult.error(
          errorMsg,
          category: ErrorCategory.internal,
        );
      }
    } catch (e) {
      final errorMsg = 'Unexpected error flushing events: ${e.toString()}';
      Logger.e(errorMsg);
      ErrorHandler.handleException(
        e,
        errorMsg,
        source: _source,
        severity: ErrorSeverity.high,
      );
      return CFResult.error(
        'Failed to flush events',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Synchronizes fetching configuration and getting all flags, ensuring latest data
  Future<Map<String, dynamic>> fetchAndGetAllFlags(
      {String? lastModified}) async {
    Logger.d('🔄 Starting synchronized fetch and get flags...');
    try {
      // Fetch the latest configuration
      final success = await configManager.refreshConfigs();
      if (!success) {
        Logger.d(
            '⚠️ Fetch config failed during synchronized fetch. Returning current flags.');
        return configManager.getAllFlags();
      }
      Logger.d('✅ Fetch config succeeded, returning current flags map.');
      return configManager.getAllFlags();
    } catch (e) {
      Logger.e('❌ Error during synchronized fetch: $e');
      return configManager.getAllFlags();
    }
  }

  /// Puts the client in offline mode, preventing network requests
  void setOffline(bool offline) {
    Logger.i('Setting offline mode to $offline');
    if (offline) {
      _mutableConfig.setOfflineMode(true);
      configFetcher.setOffline(true);
      connectionManager.setOfflineMode(true);
      Logger.i('CF client is now in offline mode');
    } else {
      _mutableConfig.setOfflineMode(false);
      configFetcher.setOffline(false);
      connectionManager.setOfflineMode(false);
      Logger.i('CF client is now in online mode');
    }
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => configFetcher.isOffline();

  /// Force a refresh of the configuration regardless of the Last-Modified header
  Future<bool> forceRefresh() async {
    Logger.i('Force refreshing configurations');
    return await configManager.refreshConfigs();
  }

  /// Increment the application launch count
  void incrementAppLaunchCount() {
    try {
      // Implementation would need to update some persistent counter
      // For now just log the action
      Logger.i('App launch count incremented');
    } catch (e) {
      Logger.e('Failed to increment app launch count: $e');
    }
  }

  /// Manually flushes the summaries queue to the server
  Future<CFResult<int>> _flushSummaries() async {
    try {
      Logger.i('Manually flushing summaries');
      final result = await summaryManager.flushSummaries();
      return result;
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to flush summaries',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        'Failed to flush summaries: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  // MARK: - Session Management

  /// Get the current session ID
  String getCurrentSessionId() {
    return _sessionManager?.getCurrentSessionId() ?? _sessionId;
  }

  /// Get current session data with metadata
  SessionData? getCurrentSessionData() {
    return _sessionManager?.getCurrentSession();
  }

  /// Force session rotation with a manual trigger
  /// Returns the new session ID after rotation
  Future<String?> forceSessionRotation() async {
    return await _sessionManager?.forceRotation();
  }

  /// Update session activity (should be called on user interactions)
  /// This helps maintain session continuity by updating the last active timestamp
  Future<void> updateSessionActivity() async {
    await _sessionManager?.updateActivity();
  }

  /// Handle user authentication changes
  /// This will trigger session rotation if configured to do so
  Future<void> onUserAuthenticationChange(String? userId) async {
    await _sessionManager?.onAuthenticationChange(userId);
  }

  /// Get session statistics for debugging and monitoring
  Map<String, dynamic> getSessionStatistics() {
    return _sessionManager?.getSessionStats() ?? {
      'hasActiveSession': false,
      'sessionId': _sessionId,
      'sessionManagerInitialized': false,
    };
  }

  /// Add a session rotation listener to be notified of session changes
  void addSessionRotationListener(SessionRotationListener listener) {
    _sessionManager?.addListener(listener);
  }

  /// Remove a session rotation listener
  void removeSessionRotationListener(SessionRotationListener listener) {
    _sessionManager?.removeListener(listener);
  }

  // MARK: - User Management

  /// Add a property to the user (matches Kotlin naming)
  void addUserProperty(String key, dynamic value) {
    try {
      userManager.addUserProperty(key, value);
      Logger.d('Added user property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add user property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add user property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a string property to the user
  void addStringProperty(String key, String value) {
    try {
      userManager.addStringProperty(key, value);
      Logger.d('Added string property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add string property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add string property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a number property to the user
  void addNumberProperty(String key, num value) {
    try {
      userManager.addNumberProperty(key, value);
      Logger.d('Added number property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add number property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add number property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a boolean property to the user
  void addBooleanProperty(String key, bool value) {
    try {
      userManager.addBooleanProperty(key, value);
      Logger.d('Added boolean property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add boolean property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add boolean property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a date property to the user
  void addDateProperty(String key, DateTime value) {
    try {
      userManager.addDateProperty(key, value);
      Logger.d('Added date property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add date property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add date property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a geolocation property to the user
  void addGeoPointProperty(String key, double lat, double lon) {
    try {
      userManager.addGeoPointProperty(key, lat, lon);
      Logger.d('Added geo point property: $key=($lat, $lon)');
    } catch (e) {
      Logger.e('Failed to add geo point property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add geo point property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add a JSON property to the user
  void addJsonProperty(String key, Map<String, dynamic> value) {
    try {
      userManager.addJsonProperty(key, value);
      Logger.d('Added JSON property: $key=$value');
    } catch (e) {
      Logger.e('Failed to add JSON property: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add JSON property',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Add multiple properties to the user (matches Kotlin naming)
  void addUserProperties(Map<String, dynamic> properties) {
    try {
      userManager.addUserProperties(properties);
      Logger.d('Added user properties: $properties');
    } catch (e) {
      Logger.e('Failed to add user properties: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add user properties',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Get all user properties (matches Kotlin naming)
  Map<String, dynamic> getUserProperties() {
    try {
      return userManager.getUserProperties();
    } catch (e) {
      Logger.e('Failed to get user properties: $e');
      ErrorHandler.handleException(
        e,
        'Failed to get user properties',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return {};
    }
  }

  // MARK: - Context Management

  /// Add an evaluation context to the user
  void addContext(EvaluationContext context) {
    try {
      userManager.addContext(context);
      Logger.d('Added evaluation context: ${context.type}:${context.key}');
    } catch (e) {
      Logger.e('Failed to add context: $e');
      ErrorHandler.handleException(
        e,
        'Failed to add evaluation context',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Remove an evaluation context from the user
  void removeContext(ContextType type, String key) {
    try {
      userManager.removeContext(type, key);
      Logger.d('Removed evaluation context: $type:$key');
    } catch (e) {
      Logger.e('Failed to remove context: $e');
      ErrorHandler.handleException(
        e,
        'Failed to remove evaluation context',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Get all evaluation contexts for the user
  List<EvaluationContext> getContexts() {
    try {
      final user = userManager.getUser();
      return user.contexts;
    } catch (e) {
      Logger.e('Failed to get contexts: $e');
      ErrorHandler.handleException(
        e,
        'Failed to get evaluation contexts',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return [];
    }
  }

  // MARK: - Runtime Configuration Updates
  // Note: Flutter SDK currently has limited runtime configuration update support
  // These methods are placeholders for future implementation when MutableCFConfig is enhanced

  /// Update the SDK settings check interval at runtime
  /// Currently not implemented in Flutter SDK
  void updateSdkSettingsCheckInterval(int intervalMs) {
    Logger.w('updateSdkSettingsCheckInterval not yet implemented in Flutter SDK');
  }

  /// Update the events flush interval at runtime
  /// Currently not implemented in Flutter SDK
  void updateEventsFlushInterval(int intervalMs) {
    Logger.w('updateEventsFlushInterval not yet implemented in Flutter SDK');
  }

  /// Update the summaries flush interval at runtime
  /// Currently not implemented in Flutter SDK
  void updateSummariesFlushInterval(int intervalMs) {
    Logger.w('updateSummariesFlushInterval not yet implemented in Flutter SDK');
  }

  /// Update the network connection timeout at runtime
  /// Currently not implemented in Flutter SDK
  void updateNetworkConnectionTimeout(int timeoutMs) {
    Logger.w('updateNetworkConnectionTimeout not yet implemented in Flutter SDK');
  }

  /// Update the network read timeout at runtime
  /// Currently not implemented in Flutter SDK
  void updateNetworkReadTimeout(int timeoutMs) {
    Logger.w('updateNetworkReadTimeout not yet implemented in Flutter SDK');
  }

  /// Enable or disable debug logging at runtime
  /// Currently not implemented in Flutter SDK
  void setDebugLoggingEnabled(bool enabled) {
    Logger.w('setDebugLoggingEnabled not yet implemented in Flutter SDK');
  }

  /// Enable or disable logging at runtime
  /// Currently not implemented in Flutter SDK
  void setLoggingEnabled(bool enabled) {
    Logger.w('setLoggingEnabled not yet implemented in Flutter SDK');
  }
}

// Custom listener implementations
class _CustomConnectionStatusListener implements ConnectionStatusListener {
  final void Function(ConnectionStatus, ConnectionInformation) onStatusChanged;

  _CustomConnectionStatusListener({required this.onStatusChanged});

  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    onStatusChanged(status, info);
  }
}

class _CustomAppStateListener implements AppStateListener {
  final void Function(AppState) onStateChanged;

  _CustomAppStateListener({required this.onStateChanged});

  @override
  void onAppStateChanged(AppState state) {
    onStateChanged(state);
  }
}

/// Session rotation listener that integrates with CFClient
class _CFClientSessionListener implements SessionRotationListener {
  final CFClient _cfClient;

  _CFClientSessionListener(this._cfClient);

  @override
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    Logger.i('🔄 Session rotated: ${oldSessionId ?? "null"} -> $newSessionId (${reason.description})');

    // Update session ID in managers
    _cfClient._updateSessionIdInManagers(newSessionId);

    // Track session rotation event
    _cfClient._trackSessionRotationEvent(oldSessionId, newSessionId, reason);
  }

  @override
  void onSessionRestored(String sessionId) {
    Logger.i('🔄 Session restored: $sessionId');

    // Update session ID in managers
    _cfClient._updateSessionIdInManagers(sessionId);
  }

  @override
  void onSessionError(String error) {
    Logger.e('🔄 Session error: $error');
  }
}

/// Wrapper for feature flag change listeners
class _FeatureFlagListenerWrapper implements FeatureFlagChangeListener {
  final void Function(String, dynamic, dynamic) callback;

  _FeatureFlagListenerWrapper(this.callback);

  @override
  void onFeatureFlagChanged(String flagKey, dynamic oldValue, dynamic newValue) {
    callback(flagKey, oldValue, newValue);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FeatureFlagListenerWrapper && other.callback == callback;
  }

  @override
  int get hashCode => callback.hashCode;
}

/// Wrapper for all flags listeners
class _AllFlagsListenerWrapper implements AllFlagsListener {
  final void Function(Map<String, dynamic>, Map<String, dynamic>) callback;

  _AllFlagsListenerWrapper(this.callback);

  @override
  void onAllFlagsChanged(Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    callback(oldFlags, newFlags);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _AllFlagsListenerWrapper && other.callback == callback;
  }

  @override
  int get hashCode => callback.hashCode;
}
