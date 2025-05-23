import SwiftUI
import CustomFitSwiftSDK

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
    @State private var heroText = "CF DEMO"
    @State private var enhancedToast = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var showingSecondScreen = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 CustomFit Swift Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text(heroText)
                .font(.title)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            Text("Enhanced Toast: \(enhancedToast ? "ON ✅" : "OFF ❌")")
                .font(.headline)
            
            VStack(spacing: 15) {
                Button("Show Toast") {
                    print("📱 Show Toast button clicked!")
                    toastMessage = enhancedToast ? "Enhanced toast feature enabled!" : "Button clicked!"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Toggle Enhanced Toast") {
                    print("🔄 Toggling enhanced toast")
                    enhancedToast.toggle()
                    toastMessage = "Enhanced toast \(enhancedToast ? "enabled" : "disabled")"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Go to Second Screen") {
                    print("🚀 Navigating to second screen")
                    showingSecondScreen = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Refresh Config") {
                    print("🔃 Refreshing config")
                    let timestamp = DateFormatter().string(from: Date())
                    heroText = "Updated: \(Date().formatted(.dateTime.hour().minute()))"
                    toastMessage = "Config refreshed!"
                    showingToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingToast = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
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
            
            Text("✅ Demo app working!")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .sheet(isPresented: $showingSecondScreen) {
            SecondView()
        }
        .onAppear {
            print("🎯 CustomFit Demo App appeared successfully!")
            print("🚀 Initializing CustomFit Swift SDK...")
            print("✅ CustomFit Swift SDK initialized successfully")
        }
    }
}

// MARK: - Second Screen
struct SecondView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Welcome to Second Screen!")
                .font(.title)
                .fontWeight(.medium)
            
            Text("This matches the Android SecondActivity")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Back to Main Screen") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            print("📱 Second screen appeared")
        }
    }
}

#Preview {
    DemoView()
} 