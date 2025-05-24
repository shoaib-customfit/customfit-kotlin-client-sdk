import 'package:flutter/material.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_sdk.dart';

void main() {
  runApp(const SessionManagerDemoApp());
}

class SessionManagerDemoApp extends StatelessWidget {
  const SessionManagerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CustomFit SessionManager Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SessionManagerDemoScreen(),
    );
  }
}

class SessionManagerDemoScreen extends StatefulWidget {
  const SessionManagerDemoScreen({super.key});

  @override
  State<SessionManagerDemoScreen> createState() => _SessionManagerDemoScreenState();
}

class _SessionManagerDemoScreenState extends State<SessionManagerDemoScreen> {
  final List<String> _logs = [];
  SessionManager? _sessionManager;
  CFClient? _cfClient;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDemo();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    debugPrint('[$timestamp] $message');
  }

  Future<void> _initializeDemo() async {
    _log('========== SessionManager Demo Starting ==========');
    await _demonstrateSessionManager();
    await _demonstrateCFClientIntegration();
    _log('========== Demo Completed ==========');
  }

  /// Demonstrates SessionManager standalone functionality
  Future<void> _demonstrateSessionManager() async {
    _log('');
    _log('========== SessionManager Standalone Demo ==========');
    
    // Create custom session configuration
    const sessionConfig = SessionConfig(
      maxSessionDurationMs: 30 * 60 * 1000, // 30 minutes
      minSessionDurationMs: 2 * 60 * 1000,  // 2 minutes
      backgroundThresholdMs: 5 * 60 * 1000, // 5 minutes
      rotateOnAppRestart: true,
      rotateOnAuthChange: true,
      sessionIdPrefix: 'demo_session',
      enableTimeBasedRotation: true,
    );
    
    _log('Initializing SessionManager with custom config...');
    
    // Initialize SessionManager
    final result = await SessionManager.initialize(config: sessionConfig);
    
    if (result.isSuccess) {
      _sessionManager = result.getOrNull();
      
      if (_sessionManager != null) {
        // Add a rotation listener
        final listener = DemoSessionListener(_log);
        _sessionManager!.addListener(listener);
        
        // Get current session
        final sessionId = _sessionManager!.getCurrentSessionId();
        _log('📍 Current session ID: $sessionId');
        
        // Get session statistics
        final stats = _sessionManager!.getSessionStats();
        _log('📊 Session stats: $stats');
        
        // Simulate user activity
        _log('👤 Simulating user activity...');
        await _sessionManager!.updateActivity();
        
        // Simulate authentication change
        _log('🔐 Simulating authentication change...');
        await _sessionManager!.onAuthenticationChange('user_123');
        
        // Get new session ID after auth change
        final newSessionId = _sessionManager!.getCurrentSessionId();
        _log('📍 New session ID after auth change: $newSessionId');
        
        // Force manual rotation
        _log('🔄 Forcing manual session rotation...');
        final manualRotationId = await _sessionManager!.forceRotation();
        _log('📍 Session ID after manual rotation: $manualRotationId');
        
        _log('✅ SessionManager demo completed successfully');
      }
    } else {
      _log('❌ Failed to initialize SessionManager: ${result.getErrorMessage()}');
    }
    
    _log('========== End SessionManager Demo ==========');
    _log('');
  }

  /// Demonstrates CFClient integration with SessionManager
  Future<void> _demonstrateCFClientIntegration() async {
    _log('');
    _log('========== CFClient Integration Demo ==========');
    
    const clientKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';
    
    final config = CFConfig.builder(clientKey)
        .setSdkSettingsCheckIntervalMs(2000)
        .setBackgroundPollingIntervalMs(2000)
        .setReducedPollingIntervalMs(2000)
        .setSummariesFlushTimeSeconds(3)
        .setSummariesFlushIntervalMs(3000)
        .setEventsFlushTimeSeconds(3)
        .setEventsFlushIntervalMs(3000)
        .setDebugLoggingEnabled(true)
        .build();
    
    _log('Test config for SDK settings check:');
    _log('- SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms');
    
    final user = CFUser(
      userCustomerId: 'user123',
      anonymous: false,
      properties: {'name': 'john'},
    );
    
    _log('');
    _log('Initializing CFClient with test config...');
    _cfClient = await CFClient.initialize(config, user);
    
    // Test SessionManager integration with CFClient
    _log('');
    _log('Testing SessionManager integration with CFClient...');
    final clientSessionId = _cfClient!.getCurrentSessionId();
    _log('CFClient session ID: $clientSessionId');
    
    // Get session statistics
    final sessionStats = _cfClient!.getSessionStatistics();
    _log('📊 CFClient session stats: $sessionStats');
    
    // Test session management methods
    _log('👤 Updating session activity...');
    await _cfClient!.updateSessionActivity();
    
    _log('🔐 Testing user authentication change...');
    await _cfClient!.onUserAuthenticationChange('new_user_456');
    
    final newSessionId = _cfClient!.getCurrentSessionId();
    _log('📍 Session ID after auth change: $newSessionId');
    
    _log('🔄 Testing manual session rotation...');
    final manualSessionId = await _cfClient!.forceSessionRotation();
    if (manualSessionId != null) {
      _log('📍 Session ID after manual rotation: $manualSessionId');
    }
    
    // Test session listener
    final sessionListener = CFClientSessionListener(_log);
    _cfClient!.addSessionRotationListener(sessionListener);
    
    _log('🔄 Triggering one more rotation to test listener...');
    await _cfClient!.forceSessionRotation();
    
    _log('Debug logging enabled - tracking some events...');
    
    for (int i = 1; i <= 3; i++) {
      _log('');
      _log('Check cycle $i...');
      
      final properties = {'source': 'app', 'cycle': i};
      await _cfClient!.trackEvent('demo_event_$i', properties: properties);
      _log('Tracked demo_event_$i for cycle $i');
      
      // Small delay between events
      await Future.delayed(const Duration(seconds: 1));
    }
    
    _log('');
    _log('✅ CFClient integration demo completed successfully');
    _log('========== End CFClient Integration Demo ==========');
    _log('');
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CustomFit SessionManager Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (!_isInitialized)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color? textColor;
                FontWeight? fontWeight;
                
                // Color coding for different types of logs
                if (log.contains('❌')) {
                  textColor = Colors.red;
                  fontWeight = FontWeight.bold;
                } else if (log.contains('✅')) {
                  textColor = Colors.green;
                  fontWeight = FontWeight.bold;
                } else if (log.contains('🔄') || log.contains('📍')) {
                  textColor = Colors.blue;
                } else if (log.contains('==========')) {
                  textColor = Colors.purple;
                  fontWeight = FontWeight.bold;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Courier',
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isInitialized)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_sessionManager != null) {
                        final sessionId = await _sessionManager!.forceRotation();
                        _log('🔄 Manual rotation: $sessionId');
                      }
                    },
                    child: const Text('Rotate Session'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_cfClient != null) {
                        await _cfClient!.updateSessionActivity();
                        _log('👤 Session activity updated');
                      }
                    },
                    child: const Text('Update Activity'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_cfClient != null) {
                        final stats = _cfClient!.getSessionStatistics();
                        _log('📊 Session stats: $stats');
                      }
                    },
                    child: const Text('Get Stats'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cfClient?.shutdown();
    SessionManager.shutdown();
    super.dispose();
  }
}

/// Demo session rotation listener for standalone SessionManager demo
class DemoSessionListener implements SessionRotationListener {
  final void Function(String) _log;

  DemoSessionListener(this._log);

  @override
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    _log('🔄 Session rotated: ${oldSessionId ?? "null"} -> $newSessionId (${reason.description})');
  }

  @override
  void onSessionRestored(String sessionId) {
    _log('🔄 Session restored: $sessionId');
  }

  @override
  void onSessionError(String error) {
    _log('❌ Session error: $error');
  }
}

/// Demo session rotation listener for CFClient integration
class CFClientSessionListener implements SessionRotationListener {
  final void Function(String) _log;

  CFClientSessionListener(this._log);

  @override
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    _log('🎯 CFClient Session rotated: ${oldSessionId ?? "null"} -> $newSessionId (${reason.description})');
  }

  @override
  void onSessionRestored(String sessionId) {
    _log('🎯 CFClient Session restored: $sessionId');
  }

  @override
  void onSessionError(String error) {
    _log('❌ CFClient Session error: $error');
  }
} 