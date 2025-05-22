import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// User data management
public class UserManager {
    
    // MARK: - Properties
    
    private var user: CFUser
    
    // MARK: - Initialization
    
    public init(user: CFUser) {
        self.user = user
        
        // Add device and application information
        enrichUserWithEnvironmentData()
    }
    
    // MARK: - Public Methods
    
    /// Update the current user
    public func updateUser(_ newUser: CFUser) {
        // Retain device and application context from current user if not provided
        if newUser.deviceContext == nil {
            newUser.deviceContext = user.deviceContext
        }
        
        if newUser.applicationInfo == nil {
            newUser.applicationInfo = user.applicationInfo
        }
        
        self.user = newUser
    }
    
    /// Get the current user
    public func getUser() -> CFUser {
        return user
    }
    
    /// Get evaluation context for feature evaluation
    public func getEvaluationContext() -> EvaluationContext {
        return user.getEvaluationContext()
    }
    
    // MARK: - Private Methods
    
    private func enrichUserWithEnvironmentData() {
        // Add device information if not already present
        if user.deviceContext == nil {
            user.deviceContext = collectDeviceContext()
        }
        
        // Add application information if not already present
        if user.applicationInfo == nil {
            user.applicationInfo = collectApplicationInfo()
        }
    }
    
    private func collectDeviceContext() -> DeviceContext {
        // This would collect real device information using iOS APIs
        // For now, we'll create a placeholder
        return DeviceContext(
            deviceId: UUID().uuidString,
            deviceModel: UIDevice.current.model,
            deviceManufacturer: "Apple",
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            screenWidth: Int(UIScreen.main.bounds.width),
            screenHeight: Int(UIScreen.main.bounds.height),
            localeLanguage: Locale.current.languageCode,
            localeCountry: Locale.current.regionCode,
            timeZone: TimeZone.current.identifier
            // Battery and network info would require more implementation
        )
    }
    
    private func collectApplicationInfo() -> ApplicationInfo {
        // This would collect real application information
        let bundle = Bundle.main
        let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let appBuild = bundle.infoDictionary?["CFBundleVersion"] as? String
        let appName = bundle.infoDictionary?["CFBundleName"] as? String
        let appId = bundle.bundleIdentifier
        
        return ApplicationInfo(
            appId: appId,
            appVersion: appVersion,
            appBuild: appBuild,
            appName: appName,
            sdkVersion: "1.0.0", // This would be the actual SDK version
            sdkType: "swift"
        )
    }
} 