import SwiftUI
import CustomFitSwiftSDK

// MARK: - Demo Provider
class CustomFitProvider: ObservableObject {
    @Published var isInitialized = false
    @Published var heroText = "CF DEMO"
    @Published var enhancedToast = false
    @Published var initializationError: String?
    
    private var client: CFClient?
    
    init() {
        initializeCustomFit()
    }
    
    private func initializeCustomFit() {
        print("🚀 Initializing CustomFit Swift SDK...")
        
        do {
            // Create configuration
            let config = CFConfig.builder("swift-demo-client-key")
                .debugLoggingEnabled(true)
                .offlineMode(true) // Use offline mode for demo
                .build()
            
            // Create user
            let user = CFUser(user_customer_id: "swift-demo-user")
                .addProperty(key: "platform", value: "swift")
                .addProperty(key: "app", value: "demo")
            
            // Initialize singleton
            client = CFClient.initialize(config: config, user: user)
            
            DispatchQueue.main.async {
                self.isInitialized = true
                print("✅ CustomFit Swift SDK initialized successfully")
            }
            
        } catch {
            print("❌ Failed to initialize CustomFit SDK: \(error)")
            DispatchQueue.main.async {
                self.initializationError = "Failed to initialize SDK: \(error.localizedDescription)"
            }
        }
    }
    
    func evaluateFlag(_ key: String) -> Bool {
        guard let client = client else {
            print("⚠️ CFClient not initialized")
            return false
        }
        
        let result = client.booleanEvaluation(key: key, defaultValue: false)
        print("🚩 Flag '\(key)' evaluated to: \(result)")
        return result
    }
    
    func trackEvent(_ eventName: String, properties: [String: Any] = [:]) {
        guard let client = client else {
            print("⚠️ CFClient not initialized")
            return
        }
        
        print("📊 Tracking event: \(eventName)")
        // Add event tracking logic here when available
    }
}

// MARK: - Main App
@main
struct CustomFitDemoApp: App {
    var body: some Scene {
        WindowGroup("CustomFit Demo") {
            DemoView()
                .frame(width: 500, height: 600)
        }
    }
}

// MARK: - Demo View
struct DemoView: View {
    @StateObject private var customFitProvider = CustomFitProvider()
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var showingSecondScreen = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 CustomFit Swift Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            if !customFitProvider.isInitialized {
                if let error = customFitProvider.initializationError {
                    Text("❌ \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("🔄 Initializing SDK...")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            
            Text(customFitProvider.heroText)
                .font(.title)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            Text("Enhanced Toast: \(customFitProvider.enhancedToast ? "ON ✅" : "OFF ❌")")
                .font(.headline)
            
            VStack(spacing: 15) {
                Button("Show Toast") {
                    print("📱 Show Toast button clicked!")
                    customFitProvider.trackEvent("button_clicked", properties: ["button": "show_toast"])
                    toastMessage = customFitProvider.enhancedToast ? "Enhanced toast feature enabled!" : "Button clicked!"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!customFitProvider.isInitialized)
                
                Button("Toggle Enhanced Toast") {
                    print("🔄 Toggling enhanced toast")
                    customFitProvider.trackEvent("toggle_feature", properties: ["feature": "enhanced_toast"])
                    
                    // Evaluate feature flag
                    customFitProvider.enhancedToast = customFitProvider.evaluateFlag("enhanced-toast-enabled")
                    
                    toastMessage = "Enhanced toast \(customFitProvider.enhancedToast ? "enabled" : "disabled")"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!customFitProvider.isInitialized)
                
                Button("Go to Second Screen") {
                    print("🚀 Navigating to second screen")
                    customFitProvider.trackEvent("navigation", properties: ["destination": "second_screen"])
                    showingSecondScreen = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!customFitProvider.isInitialized)
                
                Button("Refresh Config") {
                    print("🔃 Refreshing config")
                    customFitProvider.trackEvent("config_refresh")
                    let timestamp = DateFormatter().string(from: Date())
                    customFitProvider.heroText = "Updated: \(Date().formatted(.dateTime.hour().minute()))"
                    toastMessage = "Config refreshed!"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!customFitProvider.isInitialized)
            }
            
            if showingToast {
                Text(toastMessage)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .transition(.opacity)
            }
            
            Spacer()
            
            Text(customFitProvider.isInitialized ? "✅ SDK Initialized!" : "⏳ Initializing...")
                .font(.caption)
                .foregroundColor(customFitProvider.isInitialized ? .green : .orange)
        }
        .padding()
        .sheet(isPresented: $showingSecondScreen) {
            SecondView(customFitProvider: customFitProvider)
        }
        .onAppear {
            print("🎯 CustomFit Demo App appeared successfully!")
        }
    }
}

// MARK: - Second Screen
struct SecondView: View {
    @Environment(\.dismiss) private var dismiss
    let customFitProvider: CustomFitProvider
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Welcome to Second Screen!")
                .font(.title)
                .fontWeight(.medium)
            
            Text("This matches the Android SecondActivity")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Back to Main Screen") {
                customFitProvider.trackEvent("navigation", properties: ["destination": "main_screen"])
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            print("📱 Second screen appeared")
            customFitProvider.trackEvent("screen_view", properties: ["screen": "second"])
        }
    }
}

#Preview {
    DemoView()
} 