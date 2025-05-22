import Foundation
import CustomFitSwiftSDK

func main() {
    let timestamp = { DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium) }
    
    print("[\(timestamp())] Starting CustomFit SDK Test")
    
    // DIRECT TEST: Log via Swift equivalent of Timber (matching Kotlin)
    Logger.info("🔔 DIRECT TEST: Logging test via Swift Logger")
    
    let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbW1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
    
    let config = CFConfig.Builder(clientKey)
        .sdkSettingsCheckIntervalMs(2000)        // 2 second interval (same as Kotlin)
        .backgroundPollingIntervalMs(2000)       // 2 second background interval  
        .reducedPollingIntervalMs(2000)          // 2 second reduced interval
        .summariesFlushTimeSeconds(3)            // 3 second summary flush
        .summariesFlushIntervalMs(3000)          // 3000ms summary flush interval
        .eventsFlushTimeSeconds(3)               // 3 second event flush
        .eventsFlushIntervalMs(3000)             // 3000ms event flush interval
        .debugLoggingEnabled(true)               // Enable debug logging
        .build()
    
    print("\n[\(timestamp())] Test config for SDK settings check:")
    print("[\(timestamp())] - SDK Settings Check Interval: \(config.sdkSettingsCheckIntervalMs)ms")
    
    let user = CFUser.builder(user_customer_id: "user123")
        .makeAnonymous(false)
        .withStringProperty(key: "name", value: "john")
        .build()
    
    print("\n[\(timestamp())] Initializing CFClient with test config...")
    let cfClient = CFClient.init(config: config, user: user)
    
    // FORCE listener setup to debug the issue
    print("[\(timestamp())] FORCING listener setup debug...")
    Thread.sleep(forTimeInterval: 2.0) // Give time for async setup
    
    print("[\(timestamp())] Debug logging enabled - watch for SDK settings checks in logs")
    print("[\(timestamp())] Waiting for initial SDK settings check...")
    
    // Wait for initial SDK settings check to complete (like Kotlin's awaitSdkSettingsCheck)
    var sdkInitialized = false
    cfClient.awaitSdkSettingsCheck { error in
        if let error = error {
            print("[\(timestamp())] Initial SDK settings check failed: \(error.localizedDescription)")
        } else {
            print("[\(timestamp())] Initial SDK settings check complete.")
        }
        sdkInitialized = true
    }
    
    // Wait for initialization with proper timeout
    var waitTime = 0.0
    while !sdkInitialized && waitTime < 10.0 {
        Thread.sleep(forTimeInterval: 0.1)
        waitTime += 0.1
    }
    
    if !sdkInitialized {
        print("[\(timestamp())] WARNING: SDK initialization timed out")
    }
    
    print("\n[\(timestamp())] Testing event tracking is disabled to reduce POST requests...")
    
    // Add config listener for hero_text (like Kotlin does)
    let heroTextListener: ((String) -> Void) = { newValue in
        print("[\(timestamp())] CHANGE DETECTED: hero_text updated to: \(newValue)")
    }
    
    cfClient.addFeatureValueListener(key: "hero_text", listener: heroTextListener)
    
    print("\n[\(timestamp())] --- PHASE 1: Normal SDK Settings Checks ---")
    
    for i in 1...3 {
        print("\n[\(timestamp())] Check cycle \(i)...")
        
        print("[\(timestamp())] About to track event-\(i) for cycle \(i)")
        cfClient.trackEvent(name: "event-\(i)", properties: ["source": "app"])
        print("[\(timestamp())] Result of tracking event-\(i): true")
        print("[\(timestamp())] Tracked event-\(i) for cycle \(i)")
        
        print("[\(timestamp())] Waiting for SDK settings check...")
        
        // Wait for 5 seconds like Kotlin - THIS IS WHERE WE SHOULD SEE PERIODIC TIMER LOGS
        Thread.sleep(forTimeInterval: 5.0)
        
        let currentValue = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default-value")
        print("[\(timestamp())] Value after check cycle \(i): \(currentValue)")
    }
    
    // Wait an additional 10 seconds to observe periodic behavior
    print("\n[\(timestamp())] Waiting additional 10 seconds to observe periodic timer behavior...")
    Thread.sleep(forTimeInterval: 10.0)
    
    cfClient.shutdown()
    
    print("\n[\(timestamp())] Test completed after all check cycles")
    print("[\(timestamp())] Test complete. Press Enter to exit...")
    _ = readLine()
}

main() 