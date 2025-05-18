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
import '../core/logging/log_level_updater.dart';
import '../core/logging/logger.dart';
import '../core/model/application_info.dart';
import '../core/model/cf_user.dart';
import '../core/model/device_context.dart';
import '../core/model/evaluation_context.dart';
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

  /// Factory method to create a new CFClient instance
  static CFClient create(CFConfig config, CFUser user) {
    return CFClient._(config, user);
  }

  final String _sessionId;
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

    // Config change listener
    // _mutableConfig.addConfigChangeListener(
    //    (oldC, newC) => _handleConfigChange(oldC, newC));

    // SDK settings polling
    _startPeriodicSdkSettingsCheck();
    _initialSdkSettingsCheck();
  }

  /// Initialize application and device context
  void _initializeEnvironmentAttributes(CFUser user) {
    _deviceContext = user.device ?? DeviceContext();
    _updateUserWithDeviceContext(user);

    final existingApp = user.application;
    final appInfo = existingApp ?? ApplicationInfo();
    _updateUserWithApplicationInfo(user, appInfo);
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
        } else if (state == AppState.foreground) {
          _resumePolling();
          _checkSdkSettings();
        }
      }),
    );
  }

  void _addMainUserContext(CFUser user) {
    final ctx = EvaluationContext(
        type: ContextType.user, key: user.userCustomerId ?? _sessionId);
    _contexts['user'] = ctx;
    _updateUserWithDeviceContext(user);
  }

  void _updateUserWithDeviceContext(CFUser user) {
    Logger.d('Device context updated');
  }

  void _updateUserWithApplicationInfo(CFUser user, ApplicationInfo info) {
    Logger.d('Application info updated');
  }

  /// Handle dynamic config changes
  // ignore: unused_element
  void _handleConfigChange(CFConfig oldC, CFConfig newC) {
    if (oldC.offlineMode != newC.offlineMode) {
      configFetcher.setOffline(newC.offlineMode);
      connectionManager.setOfflineMode(true);
    }
    // other change handlers omitted for brevity
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

  // ignore: unused_element
  void _adjustPollingForBattery(bool low) {
    // No-op since we're using ConfigManager for polling
    // ConfigManager already has battery-aware polling functionality
    Logger.d(
        'Battery polling adjustment ignored - using ConfigManager for polling');
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
    final oldConfig = Map<String, dynamic>.from(_configMap);
    _configMap.clear();
    _configMap.addAll(newConfigs);

    Logger.d('Config map updated with ${newConfigs.length} configs');

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
    configManager.addConfigListener<T>(key, listener);
  }

  /// Remove a config listener for a specific feature flag
  void removeConfigListener(String key) {
    configManager.clearConfigListeners(key);
  }

  /// Get a string value from config
  String getString(String key, String defaultValue) {
    return configManager.getString(key, defaultValue);
  }

  /// Get a boolean value from config
  bool getBoolean(String key, bool defaultValue) {
    return configManager.getBoolean(key, defaultValue);
  }

  /// Force a manual fetch of configs
  Future<bool> fetchConfigs() async {
    return await configManager.refreshConfigs();
  }

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
    _sdkSettingsTimer?.cancel();
    connectionManager.shutdown();
    backgroundStateMonitor.shutdown();
    environmentManager.shutdown();

    // Flush any pending events
    try {
      await eventTracker.flush();
      // SummaryManager doesn't have flush method yet
    } catch (e) {
      ErrorHandler.handleException(e, 'Error flushing events during shutdown',
          source: _source, severity: ErrorSeverity.medium);
    }
  }

  /// Manually flushes the events queue to the server
  /// Useful for immediately sending tracked events without waiting for the automatic flush
  ///
  /// @return CFResult containing the number of events flushed or error details
  Future<CFResult<int>> flushEvents() async {
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
