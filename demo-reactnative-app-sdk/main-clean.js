/**
 * Clean Main.kt Equivalent for React Native SDK
 * 
 * This shows the exact same flow as Main.kt without mock confusion.
 * Uses console.log to show what the real SDK would do.
 */

// Same client key as Main.kt
const CLIENT_KEY = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';

/**
 * Timestamp function to match Kotlin SimpleDateFormat("HH:mm:ss.SSS")
 */
function timestamp() {
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
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Main function - EXACT REPLICA OF MAIN.KT
 */
async function main() {
  // Step 1: Starting message (same as Kotlin)
  console.log(`[${timestamp()}] Starting CustomFit SDK Test`);
  
  // Step 2: Logger test (Timber.i in Kotlin)
  // Note: In real implementation, this would be Logger.info()
  console.log('🔔 Logger test would happen here (like Timber.i in Kotlin)');

  // Step 3: Create config (same parameters as Kotlin)
  console.log(`\n[${timestamp()}] Test config for SDK settings check:`);
  console.log(`[${timestamp()}] - SDK Settings Check Interval: 2000ms`);
  
  // This would be: CFConfig.builder(CLIENT_KEY).sdkSettingsCheckIntervalMs(2000)...build()
  console.log('📋 Config created with parameters:');
  console.log('   - sdkSettingsCheckIntervalMs: 2000');
  console.log('   - backgroundPollingIntervalMs: 2000');
  console.log('   - reducedPollingIntervalMs: 2000');
  console.log('   - summariesFlushTimeSeconds: 3');
  console.log('   - summariesFlushIntervalMs: 3000');
  console.log('   - eventsFlushTimeSeconds: 3');
  console.log('   - eventsFlushIntervalMs: 3000');
  console.log('   - debugLoggingEnabled: true');

  // Step 4: Create user (same as Kotlin)
  console.log(`\n[${timestamp()}] Initializing CFClient with test config...`);
  
  // This would be: CFUser.builder().userCustomerId("user123").anonymous(false).property("name", "john").build()
  console.log('👤 User created:');
  console.log('   - userCustomerId: "user123"');
  console.log('   - anonymous: false');
  console.log('   - properties: {"name": "john"}');

  // Step 5: Initialize SDK (CFLifecycleManager.initialize in React Native)
  console.log(`[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs`);
  console.log(`[${timestamp()}] Waiting for initial SDK settings check...`);

  // Step 6: Add listener (before awaitSdkSettingsCheck)
  console.log('📝 Added config listener for "hero_text"');

  // Step 7: Simulate awaitSdkSettingsCheck()
  await sleep(1000); // Simulate SDK initialization time
  
  // Simulate the config change that happens during initialization
  console.log(`[${timestamp()}] CHANGE DETECTED: hero_text updated to: CF Kotlin Flag Demo-36`);
  console.log(`[${timestamp()}] Initial SDK settings check complete.`);

  console.log(`\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests...`);

  console.log(`\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---`);

  // Step 8: Main loop - 3 cycles exactly like Main.kt
  for (let i = 1; i <= 3; i++) {
    console.log(`\n[${timestamp()}] Check cycle ${i}...`);

    console.log(`[${timestamp()}] About to track event-${i} for cycle ${i}`);
    
    // This would be: await cfClient.trackEvent(`event-${i}`, { source: 'app' })
    console.log(`📊 Would call: trackEvent("event-${i}", {source: "app"})`);
    
    console.log(`[${timestamp()}] Result of tracking event-${i}: true`);
    console.log(`[${timestamp()}] Tracked event-${i} for cycle ${i}`);

    console.log(`[${timestamp()}] Waiting for SDK settings check...`);
    
    // Sleep for 5 seconds (same as Kotlin Thread.sleep(5000))
    await sleep(5000);

    // This would be: cfClient.getString('hero_text', 'default-value')
    console.log(`🎯 Would call: getString("hero_text", "default-value")`);
    
    // Simulate getting the current value
    const currentValue = i === 1 ? 'CF Kotlin Flag Demo-36' : `Updated value from cycle ${i}`;
    console.log(`[${timestamp()}] Value after check cycle ${i}: ${currentValue}`);
    
    // Occasionally simulate change detection
    if (i > 1 && Math.random() < 0.5) {
      console.log(`[${timestamp()}] CHANGE DETECTED: hero_text updated to: ${currentValue}`);
    }
  }

  // Step 9: Shutdown (lifecycleManager.cleanup() in React Native)
  console.log('🛑 Would call: lifecycleManager.cleanup()');

  console.log(`\n[${timestamp()}] Test completed after all check cycles`);
  console.log(`[${timestamp()}] Test complete. Press Enter to exit...`);
  
  await sleep(2000); // Simulate readLine() wait
}

/**
 * Summary of what this represents:
 * 
 * REAL REACT NATIVE CODE WOULD BE:
 * 
 * import { CFConfig, CFUser, CFLifecycleManager } from '../src/index';
 * 
 * const config = CFConfig.builder(CLIENT_KEY)
 *   .sdkSettingsCheckIntervalMs(2000)
 *   .backgroundPollingIntervalMs(2000)
 *   .reducedPollingIntervalMs(2000)
 *   .summariesFlushTimeSeconds(3)
 *   .summariesFlushIntervalMs(3000)
 *   .eventsFlushTimeSeconds(3)
 *   .eventsFlushIntervalMs(3000)
 *   .debugLoggingEnabled(true)
 *   .build();
 * 
 * const user = CFUser.builder()
 *   .userCustomerId('user123')
 *   .anonymous(false)
 *   .property('name', 'john')
 *   .build();
 * 
 * const lifecycleManager = await CFLifecycleManager.initialize(config, user);
 * const cfClient = lifecycleManager.getClient();
 * 
 * const flagListener = (newValue) => {
 *   console.log(`CHANGE DETECTED: hero_text updated to: ${newValue}`);
 * };
 * cfClient.addConfigListener('hero_text', flagListener);
 * 
 * await cfClient.awaitSdkSettingsCheck();
 * 
 * for (let i = 1; i <= 3; i++) {
 *   const trackResult = await cfClient.trackEvent(`event-${i}`, { source: 'app' });
 *   await sleep(5000);
 *   const currentValue = cfClient.getString('hero_text', 'default-value');
 * }
 * 
 * await lifecycleManager.cleanup();
 */

// Run the demo
console.log('🚀 CustomFit React Native SDK - Clean Main.kt Equivalent');
console.log('=======================================================');
console.log('This shows the exact Main.kt flow without mock confusion.');
console.log('');

main().catch(console.error); 