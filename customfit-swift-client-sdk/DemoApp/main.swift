import Foundation
import CustomFitSwiftSDK

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

/// Demonstrates SessionManager standalone functionality
func demonstrateSessionManager() async {
    print("\n[\(timestamp())] ========== SessionManager Demo ==========")
    
    // Create custom session configuration
    let sessionConfig = SessionConfig(
        maxSessionDurationMs: 30 * 60 * 1000, // 30 minutes
        minSessionDurationMs: 2 * 60 * 1000,  // 2 minutes
        backgroundThresholdMs: 5 * 60 * 1000, // 5 minutes
        rotateOnAppRestart: true,
        rotateOnAuthChange: true,
        sessionIdPrefix: "demo_session",
        enableTimeBasedRotation: true
    )
    
    print("[\(timestamp())] Initializing SessionManager with custom config...")
    
    // Initialize SessionManager
    let result = SessionManager.initialize(config: sessionConfig)
    
    switch result {
    case .success(let sessionManager):
        // Add a rotation listener
        let listener = DemoSessionListener()
        sessionManager.addListener(listener)
        
        // Get current session
        let sessionId = sessionManager.getCurrentSessionId()
        print("[\(timestamp())] 📍 Current session ID: \(sessionId)")
        
        // Get session statistics
        let stats = sessionManager.getSessionStats()
        print("[\(timestamp())] 📊 Session stats: \(stats)")
        
        // Simulate user activity
        print("[\(timestamp())] 👤 Simulating user activity...")
        sessionManager.updateActivity()
        
        // Simulate authentication change
        print("[\(timestamp())] 🔐 Simulating authentication change...")
        sessionManager.onAuthenticationChange(userId: "user_123")
        
        // Get new session ID after auth change
        let newSessionId = sessionManager.getCurrentSessionId()
        print("[\(timestamp())] 📍 New session ID after auth change: \(newSessionId)")
        
        // Force manual rotation
        print("[\(timestamp())] 🔄 Forcing manual session rotation...")
        let manualRotationId = sessionManager.forceRotation()
        print("[\(timestamp())] 📍 Session ID after manual rotation: \(manualRotationId)")
        
        print("[\(timestamp())] ✅ SessionManager demo completed successfully")
        
    case .error(let message, let error, _, _):
        print("[\(timestamp())] ❌ Failed to initialize SessionManager: \(message)")
        if let error = error {
            print("[\(timestamp())] ❌ Error details: \(error.localizedDescription)")
        }
    }
    
    print("[\(timestamp())] ========== End SessionManager Demo ==========\n")
}

/// Demonstrates CFClient integration with SessionManager
func demonstrateCFClientIntegration() async {
    print("\n[\(timestamp())] ========== CFClient Integration Demo ==========")
    
    let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
    
    let config = CFConfig.builder(clientKey)
        .sdkSettingsCheckIntervalMs(2_000)
        .backgroundPollingIntervalMs(2_000)
        .reducedPollingIntervalMs(2_000)
        .summariesFlushTimeSeconds(3)
        .summariesFlushIntervalMs(3_000)
        .eventsFlushTimeSeconds(3)
        .eventsFlushIntervalMs(3_000)
        .debugLoggingEnabled(true)
        .build()
    
    print("[\(timestamp())] Test config for SDK settings check:")
    print("[\(timestamp())] - SDK Settings Check Interval: \(config.sdkSettingsCheckIntervalMs)ms")
    
    let user = CFUser(
        user_customer_id: "user123",
        anonymous: false,
        properties: ["name": "john"]
    )
    
    print("\n[\(timestamp())] Initializing CFClient with test config...")
    let cfClient = CFClient.initialize(config: config, user: user)
    
    // Test SessionManager integration with CFClient
    print("\n[\(timestamp())] Testing SessionManager integration with CFClient...")
    let clientSessionId = cfClient.getCurrentSessionId()
    print("[\(timestamp())] CFClient session ID: \(clientSessionId)")
    
    // Get session statistics
    let sessionStats = cfClient.getSessionStatistics()
    print("[\(timestamp())] 📊 CFClient session stats: \(sessionStats)")
    
    // Test session management methods
    print("[\(timestamp())] 👤 Updating session activity...")
    cfClient.updateSessionActivity()
    
    print("[\(timestamp())] 🔐 Testing user authentication change...")
    cfClient.onUserAuthenticationChange(userId: "new_user_456")
    
    let newSessionId = cfClient.getCurrentSessionId()
    print("[\(timestamp())] 📍 Session ID after auth change: \(newSessionId)")
    
    print("[\(timestamp())] 🔄 Testing manual session rotation...")
    if let manualSessionId = cfClient.forceSessionRotation() {
        print("[\(timestamp())] 📍 Session ID after manual rotation: \(manualSessionId)")
    }
    
    // Test session listener
    let sessionListener = CFClientSessionListener()
    cfClient.addSessionRotationListener(sessionListener)
    
    print("[\(timestamp())] 🔄 Triggering one more rotation to test listener...")
    _ = cfClient.forceSessionRotation()
    
    print("[\(timestamp())] Debug logging enabled - tracking some events...")
    
    for i in 1...3 {
        print("\n[\(timestamp())] Check cycle \(i)...")
        
        let properties = ["source": "app", "cycle": i] as [String : Any]
        cfClient.trackEvent(name: "demo_event_\(i)", properties: properties)
        print("[\(timestamp())] Tracked demo_event_\(i) for cycle \(i)")
        
        // Small delay between events (compatibility for older macOS)
        if #available(macOS 10.15, *) {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } else {
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
    
    print("\n[\(timestamp())] ✅ CFClient integration demo completed successfully")
    print("[\(timestamp())] ========== End CFClient Integration Demo ==========\n")
}

// MARK: - Demo Session Listeners

/// Demo session rotation listener for standalone SessionManager demo
class DemoSessionListener: SessionRotationListener {
    func onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        print("[\(timestamp())] 🔄 Session rotated: \(oldSessionId ?? "nil") -> \(newSessionId) (\(reason.description))")
    }
    
    func onSessionRestored(sessionId: String) {
        print("[\(timestamp())] 🔄 Session restored: \(sessionId)")
    }
    
    func onSessionError(error: String) {
        print("[\(timestamp())] ❌ Session error: \(error)")
    }
}

/// Demo session rotation listener for CFClient integration
class CFClientSessionListener: SessionRotationListener {
    func onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        print("[\(timestamp())] 🎯 CFClient Session rotated: \(oldSessionId ?? "nil") -> \(newSessionId) (\(reason.description))")
    }
    
    func onSessionRestored(sessionId: String) {
        print("[\(timestamp())] 🎯 CFClient Session restored: \(sessionId)")
    }
    
    func onSessionError(error: String) {
        print("[\(timestamp())] ❌ CFClient Session error: \(error)")
    }
}

// MARK: - Main Execution

/// Main execution function
func main() async {
    print("[\(timestamp())] Starting CustomFit Swift SDK Test with SessionManager Demo")
    
    // First run the SessionManager demo
    await demonstrateSessionManager()
    
    // Then run the CFClient integration demo
    await demonstrateCFClientIntegration()
    
    print("[\(timestamp())] Demo completed. Press Enter to exit...")
    _ = readLine()
}

// Execute main function
if #available(macOS 10.15, *) {
    Task {
        await main()
    }
    RunLoop.main.run()
} else {
    // For older macOS versions, run synchronously
    print("[\(timestamp())] Running demo synchronously for older macOS...")
    let demo = SessionManagerSyncDemo()
    demo.runDemo()
}

/// Synchronous demo for older macOS versions
class SessionManagerSyncDemo {
    func runDemo() {
        print("[\(timestamp())] Starting CustomFit Swift SDK Test with SessionManager Demo (Sync)")
        
        // Basic demo without async functionality
        demonstrateSessionManagerSync()
        demonstrateCFClientIntegrationSync()
        
        print("[\(timestamp())] Demo completed. Press Enter to exit...")
        _ = readLine()
    }
    
    func demonstrateSessionManagerSync() {
        print("\n[\(timestamp())] ========== SessionManager Demo (Sync) ==========")
        
        let sessionConfig = SessionConfig(
            maxSessionDurationMs: 30 * 60 * 1000,
            minSessionDurationMs: 2 * 60 * 1000,
            backgroundThresholdMs: 5 * 60 * 1000,
            rotateOnAppRestart: true,
            rotateOnAuthChange: true,
            sessionIdPrefix: "demo_session",
            enableTimeBasedRotation: true
        )
        
        print("[\(timestamp())] Initializing SessionManager with custom config...")
        
        let result = SessionManager.initialize(config: sessionConfig)
        
        switch result {
        case .success(let sessionManager):
            let sessionId = sessionManager.getCurrentSessionId()
            print("[\(timestamp())] 📍 Current session ID: \(sessionId)")
            
            sessionManager.updateActivity()
            sessionManager.onAuthenticationChange(userId: "user_123")
            
            let newSessionId = sessionManager.getCurrentSessionId()
            print("[\(timestamp())] 📍 New session ID after auth change: \(newSessionId)")
            
            print("[\(timestamp())] ✅ SessionManager demo completed successfully")
            
        case .error(let message, _, _, _):
            print("[\(timestamp())] ❌ Failed to initialize SessionManager: \(message)")
        }
        
        print("[\(timestamp())] ========== End SessionManager Demo ==========\n")
    }
    
    func demonstrateCFClientIntegrationSync() {
        print("\n[\(timestamp())] ========== CFClient Integration Demo (Sync) ==========")
        
        let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
        
        let config = CFConfig.builder(clientKey)
            .debugLoggingEnabled(true)
            .build()
        
        let user = CFUser(
            user_customer_id: "user123",
            anonymous: false,
            properties: ["name": "john"]
        )
        
        print("\n[\(timestamp())] Initializing CFClient with test config...")
        let cfClient = CFClient.initialize(config: config, user: user)
        
        let clientSessionId = cfClient.getCurrentSessionId()
        print("[\(timestamp())] CFClient session ID: \(clientSessionId)")
        
        print("[\(timestamp())] ✅ CFClient integration demo completed successfully")
        print("[\(timestamp())] ========== End CFClient Integration Demo ==========\n")
    }
}