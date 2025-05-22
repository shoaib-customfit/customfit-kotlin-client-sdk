import Foundation
import CustomFitSwiftSDK

// Function to get formatted timestamp
func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

// Main test logic
print("[\(timestamp())] Starting CustomFit SDK Test")
Logger.info("🔔 DIRECT TEST: Logging test via Logger")

let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

// Create a configuration
let config = CFConfig.Builder(clientKey)
    .sdkSettingsCheckIntervalMs(2_000)
    .backgroundPollingIntervalMs(2_000)
    .reducedPollingIntervalMs(2_000)
    .summariesFlushTimeSeconds(3)
    .summariesFlushIntervalMs(3_000)
    .eventsFlushTimeSeconds(3)
    .eventsFlushIntervalMs(3_000)
    .debugLoggingEnabled(true)
    .build()

print("\n[\(timestamp())] Test config for SDK settings check:")
print("[\(timestamp())] - SDK Settings Check Interval: \(config.sdkSettingsCheckIntervalMs)ms")

// Create a user using builder
let user = CFUser.builder(user_customer_id: "user123")
    .makeAnonymous(false)
    .withStringProperty(key: "name", value: "john")
    .build()

print("\n[\(timestamp())] Initializing CFClient with test config...")
let cfClient = CFClient.`init`(config: config, user: user)

print("[\(timestamp())] Debug logging enabled - watch for SDK settings checks in logs")
print("[\(timestamp())] Waiting for initial SDK settings check...")

// Wait for SDK settings check to complete
cfClient.awaitSdkSettingsCheck { error in
    if let error = error {
        print("[\(timestamp())] Error in SDK settings check: \(error)")
    } else {
        print("[\(timestamp())] Initial SDK settings check complete.")
    }
}

print("\n[\(timestamp())] Testing event tracking is disabled to reduce POST requests...")

// Add a listener for hero_text flag
cfClient.addFeatureValueListener(key: "hero_text") { (newValue: String) in
    print("[\(timestamp())] CHANGE DETECTED: hero_text updated to: \(newValue)")
}

print("\n[\(timestamp())] --- PHASE 1: Normal SDK Settings Checks ---")

// Run through check cycles
for i in 1...3 {
    print("\n[\(timestamp())] Check cycle \(i)...")
    
    print("[\(timestamp())] About to track event-\(i) for cycle \(i)")
    cfClient.trackEvent(name: "event-\(i)", properties: ["source": "app"])
    print("[\(timestamp())] Tracked event-\(i) for cycle \(i)")
    
    print("[\(timestamp())] Waiting for SDK settings check...")
    Thread.sleep(forTimeInterval: 5.0)
    
    let currentValue = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default-value")
    print("[\(timestamp())] Value after check cycle \(i): \(currentValue)")
}

// Shutdown the client
cfClient.shutdown()

print("\n[\(timestamp())] Test completed after all check cycles")
print("[\(timestamp())] Test complete. Press Enter to exit...")

// Wait for user input
_ = readLine() 