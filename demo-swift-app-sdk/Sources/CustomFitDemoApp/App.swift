import SwiftUI
import CustomFitSwiftSDK

// MARK: - CFHelper (matches Android CFHelper pattern)
class CFHelper: ObservableObject {
    private static var client: CFClient?
    
    static func getCFClient() -> CFClient? {
        return client
    }
    
    static func isInitialized() -> Bool {
        return client != nil
    }
    
    static func initialize(config: CFConfig, user: CFUser) throws {
        client = CFClient.initialize(config: config, user: user)
        print("✅ CFClient singleton initialized successfully")
    }
    
    static func recordSimpleEvent(_ eventName: String) {
        guard let client = client else {
            print("⚠️ Cannot record event: CFClient not initialized")
            return
        }
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        client.trackEvent(name: eventName)
        print("📊 EVENT TRACKED: \(eventName) at \(timestamp)")
    }
    
    static func recordEventWithProperties(_ eventName: String, properties: [String: Any]) {
        guard let client = client else {
            print("⚠️ Cannot record event: CFClient not initialized")
            return
        }
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        var enrichedProperties = properties
        enrichedProperties["sdk_version"] = "1.0.0"
        enrichedProperties["sdk_type"] = "swift"
        enrichedProperties["event_timestamp"] = timestamp
        
        client.trackEvent(name: eventName, properties: enrichedProperties)
        print("📊 EVENT TRACKED: \(eventName)")
        print("   📋 Properties: \(enrichedProperties)")
        print("   ⏰ Timestamp: \(timestamp)")
    }
    
    static func getFeatureFlag(_ flagName: String, defaultValue: Bool) -> Bool {
        guard let client = client else {
            print("⚠️ Cannot get feature flag: CFClient not initialized, returning default")
            return defaultValue
        }
        
        let value = client.getBooleanFeatureFlag(key: flagName, defaultValue: defaultValue)
        print("🚩 Feature flag \(flagName): \(value)")
        return value
    }
    
    static func getString(_ key: String, defaultValue: String) -> String {
        guard let client = client else {
            print("⚠️ Cannot get string config: CFClient not initialized, returning default")
            return defaultValue
        }
        
        let value = client.getFeatureFlag(key: key, defaultValue: defaultValue)
        print("🚩 Config value \(key): \(value)")
        return value
    }
    
    static func addConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        guard let client = client else {
            print("⚠️ Cannot add config listener: CFClient not initialized")
            return
        }
        
        // Use the actual SDK config listener method
        client.addConfigListener(key: key, listener: listener)
        print("📝 Config listener added for \(key) - using real SDK listener")
    }
    
    static func removeConfigListenersByKey(_ key: String) {
        guard let client = client else {
            print("⚠️ Cannot remove config listeners: CFClient not initialized")
            return
        }
        
        // Use the actual SDK method to clear config listeners
        client.clearConfigListeners(key: key)
        print("🗑️ Removed config listeners for \(key)")
    }
    
    static func getAllFlags() -> [String: Any] {
        guard let client = client else {
            print("⚠️ Cannot get all flags: CFClient not initialized")
            return [:]
        }
        
        // Use the actual SDK method to get all flags
        let flags = client.getAllFlags()
        print("📋 Retrieved feature flags: \(flags)")
        return flags
    }
}

// MARK: - Demo Provider (matches Android pattern)
class CustomFitProvider: ObservableObject {
    @Published var isInitialized = false
    @Published var heroText = "CF DEMO"
    @Published var enhancedToast = false
    @Published var initializationError: String?
    @Published var lastConfigChangeMessage: String?
    @Published var hasNewConfigMessage = false
    @Published var recentEvents: [String] = []
    
    private var lastMessageTime: Date?
    
    var hasNewConfigMessageComputed: Bool {
        guard let lastMessageTime = lastMessageTime else { return false }
        return Date().timeIntervalSince(lastMessageTime) < 300 // 5 minutes
    }
    
    init() {
        initializeCustomFit()
    }
    
    private func initializeCustomFit() {
        print("🚀 Initializing CustomFit Swift SDK...")
        
        do {
            // Use the SAME client key as Android reference app
            let clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
            
            // Create configuration matching Android settings
            let config = CFConfig.builder(clientKey)
                .sdkSettingsCheckIntervalMs(2000)
                .backgroundPollingIntervalMs(2000)
                .reducedPollingIntervalMs(2000)
                .summariesFlushTimeSeconds(2)
                .summariesFlushIntervalMs(2000)
                .eventsFlushTimeSeconds(30)
                .eventsFlushIntervalMs(30000)
                .debugLoggingEnabled(true)
                .networkConnectionTimeoutMs(30000)
                .networkReadTimeoutMs(30000)
                .build()
            
            // Create user matching Android pattern
            let user = CFUser(user_customer_id: "swift_user_\(Int(Date().timeIntervalSince1970))")
                .makeAnonymous(true)
                .addProperty(key: "platform", value: "swift")
                .addProperty(key: "app_version", value: "1.0.0")
            
            // Initialize using CFHelper pattern
            try CFHelper.initialize(config: config, user: user)
            
            DispatchQueue.main.async {
                self.isInitialized = true
                self.updateInitialValues()
                self.setupConfigListeners()
                print("✅ CustomFit Swift SDK initialized successfully")
            }
            
        } catch {
            print("❌ Failed to initialize CustomFit SDK: \(error)")
            DispatchQueue.main.async {
                self.initializationError = "Failed to initialize SDK: \(error.localizedDescription)"
                // Still show UI even if initialization fails
                self.isInitialized = true
            }
        }
    }
    
    private func updateInitialValues() {
        // Get initial values from config (matches Android pattern)
        heroText = CFHelper.getString("hero_text", defaultValue: "CF DEMO")
        enhancedToast = CFHelper.getFeatureFlag("enhanced_toast", defaultValue: false)
        
        print("Initial values: heroText=\(heroText), enhancedToast=\(enhancedToast)")
    }
    
    private func setupConfigListeners() {
        // Add listeners for hero_text and enhanced_toast (matches Android pattern)
        CFHelper.addConfigListener(key: "hero_text") { [weak self] (newValue: String) in
            DispatchQueue.main.async {
                if self?.heroText != newValue {
                    self?.heroText = newValue
                    self?.lastConfigChangeMessage = "Configuration updated: hero_text = \(newValue)"
                    self?.lastMessageTime = Date()
                    self?.hasNewConfigMessage = true
                }
            }
        }
        
        CFHelper.addConfigListener(key: "enhanced_toast") { [weak self] (isEnabled: Bool) in
            DispatchQueue.main.async {
                if self?.enhancedToast != isEnabled {
                    self?.enhancedToast = isEnabled
                    self?.lastConfigChangeMessage = "Toast mode updated: \(isEnabled ? "Enhanced" : "Standard")"
                    self?.lastMessageTime = Date()
                    self?.hasNewConfigMessage = true
                }
            }
        }
        
        print("✅ Config listeners set up successfully")
        
        // No periodic polling needed - config listeners will handle updates automatically
        print("🔄 Using config listeners for automatic updates (no periodic polling)")
    }
    
    func trackEvent(_ eventName: String, properties: [String: Any] = [:]) {
        CFHelper.recordEventWithProperties(eventName, properties: properties)
        
        // Add to recent events for display
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let eventString = "\(timestamp): \(eventName)"
            self.recentEvents.insert(eventString, at: 0)
            
            // Keep only last 5 events
            if self.recentEvents.count > 5 {
                self.recentEvents = Array(self.recentEvents.prefix(5))
            }
        }
    }
    
    func refreshFeatureFlags(_ eventName: String? = nil) {
        if let eventName = eventName {
            trackEvent(eventName, properties: [
                "config_key": "all",
                "refresh_source": "user_action",
                "screen": "main",
                "platform": "swift"
            ])
        }
        
        // Update values manually for demo (in real app, this would trigger from server)
        updateInitialValues()
        
        lastConfigChangeMessage = "Configuration manually refreshed"
        lastMessageTime = Date()
        hasNewConfigMessage = true
    }
    
    deinit {
        // Remove listeners when provider is destroyed (matches Android pattern)
        CFHelper.removeConfigListenersByKey("hero_text")
        CFHelper.removeConfigListenersByKey("enhanced_toast")
        
        print("🗑️ Removed config listeners on cleanup")
    }
}

// MARK: - Main App
@main
struct CustomFitDemoApp: App {
    init() {
        // Set bundle identifier for macOS
        if let bundle = Bundle.main.infoDictionary {
            print("📱 Bundle info: \(bundle)")
        }
        
        // Workaround for missing bundle identifier
        setenv("CFBundleIdentifier", "ai.customfit.demo.swift", 1)
        print("📱 Set bundle identifier: ai.customfit.demo.swift")
    }
    
    var body: some Scene {
        WindowGroup("CustomFit Demo") {
            ContentView()
                .frame(width: 400, height: 700)
        }
    }
}

// MARK: - Main Content View (matches Android MainActivity)
struct ContentView: View {
    @StateObject private var customFitProvider = CustomFitProvider()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSecondScreen = false
    @State private var isRefreshing = false
    @State private var forceShowUI = false
    @State private var showConfigChangeNotifications = false // New setting to control auto-alerts
    
    var body: some View {
        VStack(spacing: 20) {
            // Title matching Android layout
            Text(customFitProvider.heroText)
                .font(.title)
                .fontWeight(.bold)
                .padding()
            
            if !customFitProvider.isInitialized && !forceShowUI {
                // Loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading CustomFit...")
                        .padding(.top)
                    Button("Show UI anyway") {
                        forceShowUI = true
                    }
                    .padding(.top)
                }
            } else {
                // Main buttons (exactly matching Android layout)
                VStack(spacing: 16) {
                    // Show Toast Button (matches Android)
                    Button("Show Toast") {
                        // Use EXACT same event name as Android
                        customFitProvider.trackEvent("swift_toast_button_interaction", properties: [
                            "action": "click",
                            "feature": "toast_message",
                            "platform": "swift",
                            "enhanced_toast_enabled": customFitProvider.enhancedToast,
                            "hero_text": customFitProvider.heroText,
                            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                        ])
                        
                        alertMessage = customFitProvider.enhancedToast 
                            ? "✨ Enhanced toast feature enabled! Current hero text: '\(customFitProvider.heroText)'" 
                            : "📱 Standard toast clicked! Current hero text: '\(customFitProvider.heroText)'"
                        showingAlert = true
                        
                        print("🎯 USER ACTION: Toast button clicked - Enhanced: \(customFitProvider.enhancedToast)")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(width: 200)
                    
                    // Go to Second Screen Button (matches Android)
                    Button("Go to Second Screen") {
                        // Use EXACT same event name as Android
                        customFitProvider.trackEvent("swift_screen_navigation", properties: [
                            "from": "main_screen",
                            "to": "second_screen",
                            "user_flow": "primary_navigation",
                            "platform": "swift",
                            "hero_text": customFitProvider.heroText,
                            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                        ])
                        
                        print("🎯 USER ACTION: Navigation to second screen")
                        showingSecondScreen = true
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 200)
                    
                    // Refresh Config Button (matches Android)
                    Button(isRefreshing ? "Refreshing Config..." : "Refresh Config") {
                        if !isRefreshing {
                            isRefreshing = true
                            
                            // Use EXACT same event name as Android
                            customFitProvider.refreshFeatureFlags("swift_config_manual_refresh")
                            
                            print("🎯 USER ACTION: Manual config refresh triggered")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isRefreshing = false
                                alertMessage = "✅ Configuration refreshed successfully!"
                                showingAlert = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 200)
                    .disabled(isRefreshing)
                    
                    // Toggle for config change notifications (for debugging)
                    Toggle("Show Config Change Alerts", isOn: $showConfigChangeNotifications)
                        .padding(.top)
                        .font(.caption)
                }
                .padding()
                
                // Current config status display
                VStack(spacing: 8) {
                    Text("Current Configuration:")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Hero Text: \(customFitProvider.heroText)")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("Enhanced Toast: \(customFitProvider.enhancedToast ? "✅ Enabled" : "❌ Disabled")")
                        .font(.body)
                        .foregroundColor(customFitProvider.enhancedToast ? .green : .red)
                    
                    if let lastMessage = customFitProvider.lastConfigChangeMessage {
                        Text("Last Update: \(lastMessage)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Recent events display
                if !customFitProvider.recentEvents.isEmpty {
                    VStack(spacing: 8) {
                        Text("Recent Events Tracked:")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(customFitProvider.recentEvents, id: \.self) { event in
                            Text(event)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("Message", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingSecondScreen) {
            SecondScreen(customFitProvider: customFitProvider)
        }
        .onAppear {
            // Add safety timeout like other apps but don't show alert automatically
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if !forceShowUI {
                    forceShowUI = true
                    print("⚠️ Timeout reached, forcing UI to show")
                }
            }
        }
        .onChange(of: customFitProvider.hasNewConfigMessage) { hasNew in
            // Only show automatic config change alerts if the toggle is enabled
            if hasNew && customFitProvider.lastConfigChangeMessage != nil && showConfigChangeNotifications {
                alertMessage = "🔄 " + customFitProvider.lastConfigChangeMessage!
                showingAlert = true
                customFitProvider.hasNewConfigMessage = false
            } else if hasNew {
                // Just log the change but don't show alert
                print("🔄 CONFIG CHANGE: \(customFitProvider.lastConfigChangeMessage ?? "unknown")")
                customFitProvider.hasNewConfigMessage = false
            }
        }
    }
}

// MARK: - Second Screen (matches Android SecondActivity)
struct SecondScreen: View {
    @Environment(\.dismiss) private var dismiss
    let customFitProvider: CustomFitProvider
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Second Screen")
                .font(.title)
                .fontWeight(.medium)
            
            Text("This is the second screen")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 300, height: 200)
        .onAppear {
            print("📱 Second screen appeared")
        }
    }
}

#Preview {
    ContentView()
} 
