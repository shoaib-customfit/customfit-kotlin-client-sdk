/**
 * Main.kt Equivalent Demo for React Native SDK
 * 
 * This demo exactly replicates the behavior of Main.kt from the Kotlin SDK
 * to verify 100% compatibility and feature parity.
 */

import {
  CFClient,
  CFConfig,
  CFUser,
  CFLifecycleManager,
  Logger,
  CFResult,
} from '../src/index';

// Same client key as Main.kt
const CLIENT_KEY = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';

/**
 * Timestamp function to match Kotlin SimpleDateFormat("HH:mm:ss.SSS")
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
 * Sleep function to match Kotlin Thread.sleep()
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Main function equivalent
 */
async function main(): Promise<void> {
  console.log(`[${timestamp()}] Starting CustomFit SDK Test`);
  Logger.info('🔔 DIRECT TEST: Logging test via Logger');

  // Create config with same settings as Main.kt
  const config = CFConfig.builder(CLIENT_KEY)
    .sdkSettingsCheckIntervalMs(2000)           // 2_000L in Kotlin
    .backgroundPollingIntervalMs(2000)          // 2_000L in Kotlin  
    .reducedPollingIntervalMs(2000)             // 2_000L in Kotlin
    .summariesFlushTimeSeconds(3)               // 3 in Kotlin
    .summariesFlushIntervalMs(3000)             // 3_000L in Kotlin
    .eventsFlushTimeSeconds(3)                  // 3 in Kotlin
    .eventsFlushIntervalMs(3000)                // 3_000L in Kotlin
    .debugLoggingEnabled(true)                  // true in Kotlin
    .build();

  console.log(`\n[${timestamp()}] Test config for SDK settings check:`);
  console.log(`[${timestamp()}] - SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms`);

  // Create user with same properties as Main.kt
  const user = CFUser.builder()
    .userCustomerId('user123')                  // user_customer_id = "user123" in Kotlin
    .anonymous(false)                           // anonymous = false in Kotlin
    .property('name', 'john')                   // properties = mapOf("name" to "john") in Kotlin
    .build();

  console.log(`\n[${timestamp()}] Initializing CFClient with test config...`);
  
  // Initialize CFClient - in React Native we use CFLifecycleManager
  const lifecycleManager = await CFLifecycleManager.initialize(config, user);
  const cfClient = lifecycleManager.getClient();

  console.log(`[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs`);
  console.log(`[${timestamp()}] Waiting for initial SDK settings check...`);
  
  // Await SDK settings check (equivalent to cfClient.awaitSdkSettingsCheck() in Kotlin)
  await cfClient.awaitSdkSettingsCheck();
  console.log(`[${timestamp()}] Initial SDK settings check complete.`);

  console.log(`\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests...`);

  // Add config listener for "hero_text" (equivalent to Kotlin's lambda)
  const flagListener = (newValue: string) => {
    console.log(`[${timestamp()}] CHANGE DETECTED: hero_text updated to: ${newValue}`);
  };
  cfClient.addConfigListener<string>('hero_text', flagListener);

  console.log(`\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---`);
  
  // Main loop - 3 cycles exactly like Main.kt
  for (let i = 1; i <= 3; i++) {
    console.log(`\n[${timestamp()}] Check cycle ${i}...`);

    console.log(`[${timestamp()}] About to track event-${i} for cycle ${i}`);
    
    // Track event (equivalent to cfClient.trackEvent() in Kotlin)
    const trackResult = await cfClient.trackEvent(`event-${i}`, { source: 'app' });
    const isSuccess = trackResult.isSuccess;
    
    console.log(`[${timestamp()}] Result of tracking event-${i}: ${isSuccess}`);
    console.log(`[${timestamp()}] Tracked event-${i} for cycle ${i}`);

    console.log(`[${timestamp()}] Waiting for SDK settings check...`);
    
    // Sleep for 5 seconds (equivalent to Thread.sleep(5000) in Kotlin)
    await sleep(5000);

    // Get current value (equivalent to cfClient.getString() in Kotlin)
    const currentValue = cfClient.getString('hero_text', 'default-value');
    console.log(`[${timestamp()}] Value after check cycle ${i}: ${currentValue}`);
  }

  // Shutdown (equivalent to cfClient.shutdown() in Kotlin)
  await lifecycleManager.cleanup();

  console.log(`\n[${timestamp()}] Test completed after all check cycles`);
  console.log(`[${timestamp()}] Test complete. Press Enter to exit...`);
  
  // Wait for user input (equivalent to readLine() in Kotlin)
  // In Node.js environment, we'll just wait 2 seconds instead
  await sleep(2000);
}

/**
 * Entry point comparison table:
 * 
 * Kotlin Main.kt                    | React Native Equivalent
 * ----------------------------------|----------------------------------
 * runBlocking { ... }               | async function main() { ... }
 * SimpleDateFormat("HH:mm:ss.SSS")  | timestamp() function
 * CFConfig.Builder(clientKey)       | CFConfig.builder(clientKey)
 * CFUser(user_customer_id=...)      | CFUser.builder().userCustomerId(...)
 * CFClient.init(config, user)       | CFLifecycleManager.initialize(config, user)
 * cfClient.awaitSdkSettingsCheck()  | cfClient.awaitSdkSettingsCheck()
 * cfClient.addConfigListener<String>| cfClient.addConfigListener<string>
 * cfClient.trackEvent(...)          | cfClient.trackEvent(...)
 * cfClient.getString(...)           | cfClient.getString(...)
 * Thread.sleep(5000)                | await sleep(5000)
 * cfClient.shutdown()               | lifecycleManager.cleanup()
 * readLine()                        | await sleep(2000) [mock]
 */

// Run the demo
if (require.main === module) {
  main().catch((error) => {
    console.error(`[${timestamp()}] Demo failed:`, error);
    process.exit(1);
  });
}

export { main }; 