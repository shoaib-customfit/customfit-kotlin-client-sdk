import Foundation
import CustomFitSwiftSDK

func main() {
    let timestamp = { DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium) }
    
    print("[\(timestamp())] Starting CustomFit SDK Test - Clean Metadata Test")
    
    let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
    
    // Create CFConfig that matches Kotlin setup exactly
    let config = CFConfig.Builder(clientKey)
        .offlineMode(false)  // Ensure online mode like Kotlin
        .disableBackgroundPolling(false)  // Enable polling like Kotlin 
        .sdkSettingsCheckIntervalMs(2000)  // Same 2 second interval as Kotlin
        .summariesFlushIntervalMs(3000)  // Same 3 second interval as Kotlin
        .debugLoggingEnabled(true)
        .build()
    
    // Create user exactly like Kotlin
    let user = CFUser.builder(user_customer_id: "user123")
        .makeAnonymous(false)
        .withStringProperty(key: "name", value: "john")
        .build()
    
    print("[\(timestamp())] Initializing CFClient - NO forceRefresh calls...")
    let cfClient = CFClient.init(config: config, user: user)
    
    // Let the SDK do its natural initialization without forcing refreshes
    print("[\(timestamp())] Waiting for natural SDK initialization...")
    Thread.sleep(forTimeInterval: 5.0)
    
    // Test basic functionality
    print("[\(timestamp())] Testing feature flag retrieval...")
    let heroText = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default-value")
    print("[\(timestamp())] Feature flag value: \(heroText)")
    
    // Test manual summary flush to verify HTTP calls work
    print("[\(timestamp())] Adding more summaries to trigger flush...")
    
    // Add some feature usage summaries to increase the queue size
    // Note: These will be internal calls since we don't have public summary methods
    for i in 1...3 {
        _ = cfClient.getFeatureValue(key: "hero_text", defaultValue: "default")
        print("[\(timestamp())] Called getFeatureValue #\(i) - this should add summaries")
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    print("[\(timestamp())] Waiting for periodic summary flush (should happen every 3 seconds)...")
    Thread.sleep(forTimeInterval: 8.0)  // Wait long enough for 2+ flush cycles
    
    print("[\(timestamp())] Test completed successfully!")
}

main()