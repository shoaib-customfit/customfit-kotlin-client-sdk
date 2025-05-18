import 'package:flutter/foundation.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

class CustomFitProvider with ChangeNotifier {
  late final CFClient _client;
  bool _isInitialized = false;
  Map<String, dynamic> _featureFlags = {};
  bool _isOffline = false;
  String _heroText = 'CF DEMO';
  bool _enhancedToast = false;

  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get featureFlags => _featureFlags;
  bool get isOffline => _isOffline;
  String get heroText => _heroText;
  bool get enhancedToast => _enhancedToast;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing CustomFit provider...');

    final config = CFConfig.builder(
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek',
    )
        .setDebugLoggingEnabled(true)
        .setOfflineMode(false)
        .setSdkSettingsCheckIntervalMs(60000)
        .setSummariesFlushTimeSeconds(30)
        .setSummariesFlushIntervalMs(30000)
        .setEventsFlushTimeSeconds(30)
        .setEventsFlushIntervalMs(30000)
        .build();

    final user = CFUser(
      userCustomerId: 'flutter_user_${DateTime.now().millisecondsSinceEpoch}',
      properties: {
        'name': 'Demo User',
        'platform': 'Flutter',
      },
      anonymous: true,
    );

    debugPrint('Creating CFClient...');
    _client = CFClient.create(config, user);

    // Register for flag changes before doing anything else
    debugPrint('Setting up feature flag listeners...');
    _setupFeatureFlagListeners();

    // Trigger initial config fetch and wait for it to complete
    debugPrint('Fetching initial configuration...');
    await _client.configManager.refreshConfigs();

    // Load the latest values from the fetched configuration
    debugPrint('Loading config values...');
    await _loadConfigValues();

    // Mark as initialized and notify UI
    _isInitialized = true;
    notifyListeners();
  }

  /// Set up listeners for feature flag changes
  void _setupFeatureFlagListeners() {
    // Listen to all flags changes
    _client.listenerManager.registerAllFlagsListener(
      _CustomAllFlagsListener(
        onFlagsChanged: (oldFlags, newFlags) async {
          debugPrint('⚡ Feature flags changed. Updating values...');
          _featureFlags = newFlags;

          // When flags change, also update our local values
          await _loadConfigValues();

          // Then notify UI
          notifyListeners();
        },
      ),
    );

    // Also set up specific listeners for our key feature flags
    _client.configManager.addConfigListener<String>('hero_text', (value) {
      debugPrint('⚡ hero_text specific listener triggered with value: $value');
      _heroText = value;
      notifyListeners();
    });

    _client.configManager.addConfigListener<bool>('enhanced_toast', (value) {
      debugPrint(
          '⚡ enhanced_toast specific listener triggered with value: $value');
      _enhancedToast = value;
      notifyListeners();
    });
  }

  Future<void> _loadConfigValues() async {
    // Get direct access to the raw config map to examine structure
    debugPrint('===== LOADING CONFIG VALUES =====');

    // Check for specific feature flags we care about
    _heroText = _client.configManager.getString('hero_text', 'CF DEMO');
    _enhancedToast = _client.configManager.getBoolean('enhanced_toast', false);

    // Debug logging to see the values
    debugPrint('Loaded heroText value: $_heroText');
    debugPrint('Loaded enhancedToast value: $_enhancedToast');
  }

  Future<void> toggleOfflineMode() async {
    if (!_isInitialized) return;

    if (_isOffline) {
      _client.connectionManager.setOfflineMode(false);
    } else {
      _client.connectionManager.setOfflineMode(true);
    }
    _isOffline = !_isOffline;
    notifyListeners();
  }

  Future<void> trackEvent(String eventName,
      {Map<String, dynamic>? properties}) async {
    if (!_isInitialized) return;
    await _client.eventTracker.trackEvent(eventName, properties ?? {});
  }

  Future<void> addUserProperty(String key, dynamic value) async {
    if (!_isInitialized) return;
    _client.userManager.addUserProperty(key, value);
    notifyListeners();
  }

  /// Force a refresh of feature flags
  Future<bool> refreshFeatureFlags() async {
    if (!_isInitialized) return false;

    debugPrint('Manually refreshing feature flags...');
    final success = await _client.configManager.refreshConfigs();
    return success;
  }

  /// Debug and refresh specifically the hero_text feature flag
  Future<void> debugHeroText() async {
    if (!_isInitialized) return;

    debugPrint('=========== HERO TEXT DEBUG ===========');

    // Dump the entire config map
    _client.configManager.dumpConfigMap();

    // Try to force access through getString
    final heroTextValue =
        _client.configManager.getString('hero_text', 'NOT FOUND');
    debugPrint('Current getString() result: "$heroTextValue"');

    // Attempt to refresh
    debugPrint('Triggering config refresh...');
    await refreshFeatureFlags();

    // Dump the config map again after refresh
    debugPrint('AFTER REFRESH:');
    _client.configManager.dumpConfigMap();

    // Get the updated value
    final updatedValue =
        _client.configManager.getString('hero_text', 'CF DEMO');
    debugPrint('Updated hero_text value: "$updatedValue"');

    debugPrint('=======================================');
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _client.shutdown();
    }
    super.dispose();
  }
}

class _CustomAllFlagsListener implements AllFlagsListener {
  final void Function(Map<String, dynamic>, Map<String, dynamic>)
      onFlagsChanged;

  _CustomAllFlagsListener({required this.onFlagsChanged});

  @override
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    onFlagsChanged(oldFlags, newFlags);
  }
}

// Factory method to create CFClient (since it has a private constructor)
CFClient createCFClient(CFConfig config, CFUser user) {
  // This is a workaround for the private constructor
  // In a real implementation, CFClient would have a public factory method
  // We're using dynamic to bypass the private constructor restriction
  // In a real implementation, you would use the public factory method
  const dynamic client = CFClient;
  return client._(config, user);
}
