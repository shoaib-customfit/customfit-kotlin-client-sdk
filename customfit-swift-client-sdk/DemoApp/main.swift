import Foundation
import CustomFitSwiftSDK

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Starting CustomFit SDK Test - Clean Metadata Test")

func main() {
    let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
    
    // Create user
    let user = CFUser.builder(user_customer_id: "test-user-123")
        .withAnonymousId("anon-456")
        .withDeviceId("device-789")
        .build()
    
    // Create CFConfig that matches Kotlin setup exactly
    let config = CFConfig.Builder(clientKey)
        .offlineMode(false)  // Ensure online mode like Kotlin
        .disableBackgroundPolling(false)  // Enable polling like Kotlin 
        .sdkSettingsCheckIntervalMs(2000)  // Same 2 second interval as Kotlin
        .summariesFlushIntervalMs(3000)  // Same 3 second interval as Kotlin
        .debugLoggingEnabled(true)
        .build()
    
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Initializing CFClient - NO forceRefresh calls...")
    
    // Create CFClient
    let cfClient = CFClient.init(config: config, user: user)
    
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Waiting for natural SDK initialization...")
    Thread.sleep(forTimeInterval: 1.0)
    
    // Test basic functionality
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Testing feature flag retrieval...")
    let heroText = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default-value")
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Feature flag value: \(heroText)")
    
    // Test manual summary flush to verify HTTP calls work
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Adding more summaries to trigger flush...")
    
    // Add some feature usage summaries to increase the queue size
    // Note: These will be internal calls since we don't have public summary methods
    for i in 1...3 {
        _ = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default")
        print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Called getFeatureValue #\(i) - this should add summaries")
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Waiting for periodic summary flush (should happen every 3 seconds)...")
    Thread.sleep(forTimeInterval: 10.0)
    
    print("[\(timestamp())] CustomFit-Demo [Swift] [INFO] Test completed successfully!")
}

main()