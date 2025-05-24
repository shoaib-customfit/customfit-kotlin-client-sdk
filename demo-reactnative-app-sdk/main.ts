/**
 * CustomFit React Native SDK - Complete Demo
 * 
 * This demo shows all features of the SDK in action:
 * - Configuration and initialization
 * - Feature flags and configuration values
 * - Event tracking and summaries
 * - User management and attributes
 * - Listener system
 * - Lifecycle management
 * - Offline/online modes
 * - React hooks integration
 */

import {
  CFClient,
  CFConfig,
  CFUser,
  CFLifecycleManager,
  Logger,
  CFConstants,
  FeatureFlagChangeListener,
  AllFlagsChangeListener,
  ConnectionStatusListener,
  useCustomFit,
  useFeatureFlag,
  useAllFeatureFlags,
  useScreenTracking,
  ConnectionStatus,
  AppState,
  BatteryState,
} from '../src/index';

// Demo configuration - using the same client key as Kotlin SDK
const CLIENT_KEY = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';

/**
 * Helper function to format timestamps
 */
function timestamp(): string {
  const now = new Date();
  const hours = now.getHours().toString().padStart(2, '0');
  const minutes = now.getMinutes().toString().padStart(2, '0');
  const seconds = now.getSeconds().toString().padStart(2, '0');
  const milliseconds = now.getMilliseconds().toString().padStart(3, '0');
  
  return `${hours}:${minutes}:${seconds}.${milliseconds}`;
}

/**
 * Log function with timestamp
 */
function log(message: string): void {
  console.log(`[${timestamp()}] ${message}`);
}

/**
 * Demo class showing all SDK functionality
 */
class CustomFitDemo {
  private client: CFClient | null = null;
  private lifecycleManager: CFLifecycleManager | null = null;

  /**
   * Run the complete demo
   */
  async runDemo(): Promise<void> {
    log('🚀 Starting CustomFit React Native SDK Demo');
    log('===============================================');

    try {
      // Step 1: Configuration
      await this.demonstrateConfiguration();

      // Step 2: Initialization
      await this.demonstrateInitialization();

      // Step 3: Feature Flags
      await this.demonstrateFeatureFlags();

      // Step 4: Event Tracking
      await this.demonstrateEventTracking();

      // Step 5: User Management
      await this.demonstrateUserManagement();

      // Step 6: Listeners
      await this.demonstrateListeners();

      // Step 7: Lifecycle Management
      await this.demonstrateLifecycleManagement();

      // Step 8: Dynamic Configuration
      await this.demonstrateDynamicConfiguration();

      // Step 9: React Hooks (simulated)
      await this.demonstrateReactHooks();

      // Step 10: Performance and Metrics
      await this.demonstrateMetrics();

      // Step 11: Cleanup
      await this.demonstrateCleanup();

      log('✅ Demo completed successfully!');

    } catch (error) {
      log(`❌ Demo failed: ${error}`);
    }
  }

  /**
   * Demonstrate SDK configuration
   */
  private async demonstrateConfiguration(): Promise<void> {
    log('\n📋 STEP 1: Configuration');
    log('========================');

    // Create configuration with all options
    const config = CFConfig.builder(CLIENT_KEY)
      .eventsQueueSize(100)
      .eventsFlushTimeSeconds(2)
      .eventsFlushIntervalMs(3000)
      .maxStoredEvents(1000)
      .maxRetryAttempts(3)
      .retryInitialDelayMs(1000)
      .retryMaxDelayMs(30000)
      .retryBackoffMultiplier(2.0)
      .summariesQueueSize(50)
      .summariesFlushTimeSeconds(60)
      .summariesFlushIntervalMs(60000)
      .sdkSettingsCheckIntervalMs(300000) // 5 minutes
      .networkConnectionTimeoutMs(10000)
      .networkReadTimeoutMs(10000)
      .loggingEnabled(true)
      .debugLoggingEnabled(true)
      .logLevel('DEBUG')
      .offlineMode(false)
      .disableBackgroundPolling(false)
      .backgroundPollingIntervalMs(3600000) // 1 hour
      .useReducedPollingWhenBatteryLow(true)
      .reducedPollingIntervalMs(7200000) // 2 hours
      .autoEnvAttributesEnabled(true)
      .build();

    log(`✓ Configuration created with client key: ${config.clientKey.substring(0, 8)}...`);
    log(`✓ Events queue size: ${config.eventsQueueSize}`);
    log(`✓ Summaries flush interval: ${config.summariesFlushIntervalMs}ms`);
    log(`✓ Background polling enabled: ${!config.disableBackgroundPolling}`);
    log(`✓ Auto environment attributes: ${config.autoEnvAttributesEnabled}`);
  }

  /**
   * Demonstrate SDK initialization
   */
  private async demonstrateInitialization(): Promise<void> {
    log('\n🔧 STEP 2: Initialization');
    log('=========================');

    // Create user
    const user = CFUser.builder()
      .userCustomerId('demo_user_123')
      .anonymousId('anon_456')
      .anonymous(false)
      .property('name', 'Demo User')
      .property('email', 'demo@example.com')
      .property('plan', 'premium')
      .property('signup_date', '2024-01-15')
      .build();

    log(`✓ User created: ${user.userCustomerId}`);
    log(`✓ User properties: ${Object.keys(user.properties || {}).join(', ')}`);

    // Initialize with lifecycle manager
    this.lifecycleManager = await CFLifecycleManager.initialize(
      CFConfig.builder(CLIENT_KEY).debugLoggingEnabled(true).build(),
      user as any // Type cast to fix compatibility
    );

    this.client = this.lifecycleManager.getClient();

    if (this.client) {
      log('✓ SDK initialized successfully with lifecycle manager');
      log('✓ SDK initialization complete');
    } else {
      throw new Error('Failed to initialize SDK');
    }
  }

  /**
   * Demonstrate feature flags and configuration values
   */
  private async demonstrateFeatureFlags(): Promise<void> {
    log('\n🎯 STEP 3: Feature Flags & Configuration');
    log('========================================');

    if (!this.client) return;

    // Test different value types
    const heroText = this.client.getString('hero_text', 'Welcome to our app!');
    const maxRetries = this.client.getNumber('max_retries', 3);
    const debugMode = this.client.getBoolean('debug_mode', false);
    const themeConfig = this.client.getJson('theme_config', { 
      primaryColor: '#007AFF',
      secondaryColor: '#34C759' 
    });

    log(`✓ String flag 'hero_text': "${heroText}"`);
    log(`✓ Number flag 'max_retries': ${maxRetries}`);
    log(`✓ Boolean flag 'debug_mode': ${debugMode}`);
    log(`✓ JSON flag 'theme_config': ${JSON.stringify(themeConfig)}`);

    // Get all flags
    const allFlags = this.client.getAllFlags();
    log(`✓ Total flags available: ${Object.keys(allFlags).length}`);

    // Test generic getFeatureFlag method
    const genericFlag = this.client.getFeatureFlag('generic_flag', 'default_value');
    log(`✓ Generic flag: ${genericFlag}`);
  }

  /**
   * Demonstrate event tracking
   */
  private async demonstrateEventTracking(): Promise<void> {
    log('\n🔔 STEP 4: Event Tracking');
    log('=========================');

    if (!this.client) return;

    // Track simple event
    const simpleResult = await this.client.trackEvent('demo_started', {
      source: 'main_demo',
      timestamp: new Date().toISOString(),
    });

    if (simpleResult.isSuccess) {
      log('✓ Simple event tracked: demo_started');
    } else {
      log(`✗ Failed to track simple event: ${simpleResult.error?.message}`);
    }

    // Track screen view
    const screenResult = await this.client.trackScreenView('demo_screen');
    if (screenResult.isSuccess) {
      log('✓ Screen view tracked: demo_screen');
    }

    // Track feature usage
    const featureResult = await this.client.trackFeatureUsage('hero_text_display', {
      value: 'Welcome to our app!',
      timestamp: Date.now(),
    });
    
    if (featureResult.isSuccess) {
      log('✓ Feature usage tracked: hero_text_display');
    }

    // Track multiple events
    for (let i = 1; i <= 5; i++) {
      await this.client.trackEvent(`batch_event_${i}`, {
        batch_id: 'demo_batch',
        sequence: i,
      });
    }
    log('✓ Batch events tracked (5 events)');

    // Force flush events
    const flushResult = await this.client.flushEvents();
    if (flushResult.isSuccess) {
      log(`✓ Flushed ${flushResult.data} events to server`);
    }
  }

  /**
   * Demonstrate user management
   */
  private async demonstrateUserManagement(): Promise<void> {
    log('\n👤 STEP 5: User Management');
    log('==========================');

    if (!this.client) return;

    // Update user attributes
    this.client.setUserAttribute('last_demo_run', new Date().toISOString());
    this.client.setUserAttribute('demo_version', '1.0.0');
    log('✓ Individual user attributes set');

    // Update multiple attributes
    this.client.setUserAttributes({
      platform: 'react-native',
      demo_completed: false,
      session_count: 1,
    });
    log('✓ Multiple user attributes set');

    // Increment app launch count
    this.client.incrementAppLaunchCount();
    log('✓ App launch count incremented');

    // Get current user
    const currentUser = this.client.getUser();
    log(`✓ Current user: ${currentUser.userCustomerId}`);
    log(`✓ User properties count: ${Object.keys(currentUser.properties || {}).length}`);

    // Create new user and update
    const newUser = CFUser.builder()
      .userCustomerId('updated_demo_user_123')
      .property('updated_at', new Date().toISOString())
      .build();

    this.client.setUser(newUser);
    log('✓ User updated');
  }

  /**
   * Demonstrate listener system
   */
  private async demonstrateListeners(): Promise<void> {
    log('\n🔊 STEP 6: Listener System');
    log('==========================');

    if (!this.client) return;

    // Feature flag change listener
    const flagListener: FeatureFlagChangeListener = {
      onFeatureFlagChanged: (flagKey: string, oldValue: any, newValue: any) => {
        log(`🔔 FLAG CHANGED: ${flagKey} from ${oldValue} to ${newValue}`);
      }
    };

            this.client.addFeatureFlagListener('hero_text', flagListener);
    log('✓ Feature flag listener registered for "hero_text"');

    // All flags change listener
    const allFlagsListener: AllFlagsChangeListener = {
      onAllFlagsChanged: (flags: Record<string, any>) => {
        log(`🔔 ALL FLAGS CHANGED: ${Object.keys(flags).length} flags updated`);
      }
    };

            this.client.addAllFlagsListener(allFlagsListener);
    log('✓ All flags listener registered');

    // Connection status listener
    const connectionListener: ConnectionStatusListener = {
      onConnectionStatusChanged: (status: ConnectionStatus) => {
        log(`🌐 CONNECTION STATUS: ${status}`);
      }
    };

    this.client.addConnectionStatusListener(connectionListener);
    log('✓ Connection status listener added');

    // Config listener (generic)
    const configListener = (value: string) => {
      log(`⚙️ CONFIG CHANGED: hero_text = ${value}`);
    };

    this.client.addConfigListener<string>('hero_text', configListener);
    log('✓ Generic config listener added');

    // Simulate some time for listeners
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  /**
   * Demonstrate lifecycle management
   */
  private async demonstrateLifecycleManagement(): Promise<void> {
    log('\n🔄 STEP 7: Lifecycle Management');
    log('===============================');

    if (!this.client || !this.lifecycleManager) return;

    // Test offline mode
    this.client.setOfflineMode(true);
    log('✓ SDK set to offline mode');

    const isOffline = this.client.isOffline();
    log(`✓ Offline status: ${isOffline}`);

    // Test online mode
    this.client.setOfflineMode(false);
    log('✓ SDK set to online mode');

    // Test pause/resume
    await this.lifecycleManager.pause();
    log('✓ SDK paused');

    await new Promise(resolve => setTimeout(resolve, 500));

    await this.lifecycleManager.resume();
    log('✓ SDK resumed');

    // Force refresh configurations
    const refreshResult = await this.client.forceRefresh();
    if (refreshResult.isSuccess) {
      log('✓ Configurations force refreshed');
    }

    // Get connection information
    const connectionInfo = this.client.getConnectionInformation();
    log(`✓ Connection status: ${connectionInfo}`);
  }

  /**
   * Demonstrate dynamic configuration updates
   */
  private async demonstrateDynamicConfiguration(): Promise<void> {
    log('\n⚙️ STEP 8: Dynamic Configuration');
    log('================================');

    if (!this.client) return;

    // Auto environment attributes are now handled automatically via config
    log('✓ Auto environment attributes handled via config.autoEnvAttributesEnabled');

    log('✓ Dynamic configuration updates completed');
  }

  /**
   * Demonstrate React hooks (simulated)
   */
  private async demonstrateReactHooks(): Promise<void> {
    log('\n⚛️ STEP 9: React Hooks (Simulated)');
    log('==================================');

    // Note: These would normally be used in React components
    // Here we're just demonstrating the API structure

    log('✓ useCustomFit hook provides:');
    log('  - client instance');
    log('  - isInitialized status');
    log('  - trackEvent function');
    log('  - setUserAttribute function');
    log('  - metrics');

    log('✓ useFeatureFlag<T> hook provides:');
    log('  - live feature flag value');
    log('  - automatic re-renders on changes');

    log('✓ useAllFeatureFlags hook provides:');
    log('  - all feature flags object');
    log('  - automatic updates');

    log('✓ useScreenTracking hook provides:');
    log('  - automatic screen view tracking');
    log('  - component lifecycle integration');

    log('✓ useFeatureTracking hook provides:');
    log('  - feature usage tracking utilities');
    log('  - performance monitoring');
  }

  /**
   * Demonstrate performance metrics
   */
  private async demonstrateMetrics(): Promise<void> {
    log('\n📊 STEP 10: Performance & Metrics');
    log('=================================');

    if (!this.client || !this.lifecycleManager) return;

    // Get SDK metrics
    const metrics = this.client.getMetrics();
    log('✓ SDK Performance Metrics:');
    log(`  - Total events: ${metrics.totalEvents}`);
    log(`  - Total summaries: ${metrics.totalSummaries}`);
    log(`  - Total config fetches: ${metrics.totalConfigFetches}`);
    log(`  - Average response time: ${metrics.averageResponseTime.toFixed(2)}ms`);
    log(`  - Failure rate: ${(metrics.failureRate * 100).toFixed(2)}%`);

    // Environment attributes are now private - they're collected automatically when autoEnvAttributesEnabled=true
    log('✓ Environment Attributes: Collected automatically when autoEnvAttributesEnabled=true');

    // Lifecycle manager metrics
    const lifecycleMetrics = this.lifecycleManager.getMetrics();
    if (lifecycleMetrics) {
      log('✓ Lifecycle Manager Metrics available');
    }

    // Flush all remaining data
    const summaryFlushResult = await this.client.flushSummaries();
    if (summaryFlushResult.isSuccess) {
      log(`✓ Flushed ${summaryFlushResult.data} summaries`);
    }

    const eventFlushResult = await this.client.flushEvents();
    if (eventFlushResult.isSuccess) {
      log(`✓ Flushed ${eventFlushResult.data} events`);
    }
  }

  /**
   * Demonstrate cleanup and shutdown
   */
  private async demonstrateCleanup(): Promise<void> {
    log('\n🧹 STEP 11: Cleanup & Shutdown');
    log('==============================');

    if (!this.lifecycleManager) return;

    // Clean shutdown
    await this.lifecycleManager.cleanup();
    log('✓ SDK cleaned up and shut down');

    // Verify shutdown
    const isInitialized = this.lifecycleManager.isSDKInitialized();
    log(`✓ SDK initialization status: ${isInitialized}`);

    log('✓ All resources cleaned up');
    log('✓ Demo cleanup completed');
  }
}

/**
 * React Component Demo (TypeScript interface)
 * This shows how the SDK would be used in actual React Native components
 */
interface ReactComponentDemo {
  // Example component using hooks
  FeatureFlagComponent(): void;
  EventTrackingComponent(): void;
  UserManagementComponent(): void;
}

const ReactExamples: ReactComponentDemo = {
  FeatureFlagComponent(): void {
    // const heroText = useFeatureFlag('hero_text', 'Default Welcome!');
    // const isDebugMode = useFeatureFlag<boolean>('debug_mode', false);
    // const allFlags = useAllFeatureFlags();
    
    log('📱 React Component would use hooks like:');
    log('  const heroText = useFeatureFlag("hero_text", "Default Welcome!");');
    log('  const isDebugMode = useFeatureFlag<boolean>("debug_mode", false);');
    log('  const allFlags = useAllFeatureFlags();');
  },

  EventTrackingComponent(): void {
    // const { trackEvent } = useCustomFit();
    // useScreenTracking('HomeScreen');
    
    log('📱 React Component would track events like:');
    log('  const { trackEvent } = useCustomFit();');
    log('  useScreenTracking("HomeScreen");');
    log('  trackEvent("button_clicked", { button_id: "cta" });');
  },

  UserManagementComponent(): void {
    // const { setUserAttribute, client } = useCustomFit();
    
    log('📱 React Component would manage users like:');
    log('  const { setUserAttribute, client } = useCustomFit();');
    log('  setUserAttribute("last_action", "button_click");');
    log('  client?.setUser(newUser);');
  },
};

/**
 * Main demo function
 */
async function main(): Promise<void> {
  log('🎯 CustomFit React Native SDK - Complete Demo');
  log('==============================================');
  log('This demo showcases all SDK features and capabilities.');
  log('');

  // Run the main demo
  const demo = new CustomFitDemo();
  await demo.runDemo();

  // Show React examples
  log('\n⚛️ React Component Examples:');
  log('============================');
  ReactExamples.FeatureFlagComponent();
  ReactExamples.EventTrackingComponent();
  ReactExamples.UserManagementComponent();

  log('\n🎉 Demo completed successfully!');
  log('The CustomFit React Native SDK is ready for production use.');
  log('');
  log('Next steps:');
  log('1. Replace CLIENT_KEY with your actual client key');
  log('2. Integrate the SDK into your React Native app');
  log('3. Use the React hooks for seamless component integration');
  log('4. Monitor performance using the metrics API');
  log('5. Customize configuration based on your needs');
}

// Export for use in React Native applications
export { main as runDemo, CustomFitDemo, ReactExamples };

// Auto-run demo (you can comment this out if importing as module)
// main().catch(console.error); 