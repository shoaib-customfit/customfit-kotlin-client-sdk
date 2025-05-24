import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// User data management
public class UserManager: CFUserProvider {
    
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
        if newUser.device == nil {
            newUser.device = user.device
        }
        
        if newUser.application == nil {
            newUser.application = user.application
        }
        
        self.user = newUser
        Logger.debug("User updated")
    }
    
    /// Get the current user
    public func getUser() -> CFUser {
        return user
    }
    
    /// Get evaluation context for feature evaluation
    public func getEvaluationContext() -> EvaluationContext {
        // Create context from user data
        var contextData = user.toDictionary()
        
        // Add device context if available
        if let deviceContext = user.device {
            let deviceDict = deviceContext.toDictionary()
            for (key, value) in deviceDict {
                contextData["device_\(key)"] = value
            }
        }
        
        // Add application info if available
        if let appInfo = user.application {
            let appDict = appInfo.toDictionary()
            for (key, value) in appDict {
                contextData["app_\(key)"] = value
            }
        }
        
        return EvaluationContext(attributes: contextData)
    }
    
    /// Add an evaluation context to the user
    /// - Parameter context: The evaluation context to add
    public func addContext(_ context: EvaluationContext) {
        user = user.addContext(context)
        Logger.debug("Added evaluation context to user")
    }
    
    /// Remove an evaluation context from the user by key
    /// - Parameter key: The context key to remove
    public func removeContext(key: String) {
        user = user.removeContext(key: key)
        Logger.debug("Removed evaluation context from user")
    }
    
    // MARK: - Private Methods
    
    private func enrichUserWithEnvironmentData() {
        // Add device information if not already present
        if user.device == nil {
            user.device = collectDeviceContext()
        }
        
        // Add application information if not already present
        if user.application == nil {
            user.application = collectApplicationInfo()
        }
    }
    
    private func collectDeviceContext() -> DeviceContext {
        let deviceId = UUID().uuidString
        
        #if os(iOS) || os(tvOS)
        // iOS/tvOS specific device info
        return DeviceContext(
            deviceId: deviceId,
            deviceModel: UIDevice.current.model,
            deviceManufacturer: "Apple",
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            screenWidth: Int(UIScreen.main.bounds.width),
            screenHeight: Int(UIScreen.main.bounds.height),
            localeLanguage: Locale.current.languageCode,
            localeCountry: Locale.current.regionCode,
            timeZone: TimeZone.current.identifier
        )
        #else
        // macOS or other platforms
        return DeviceContext(
            deviceId: deviceId,
            deviceModel: "Apple Device",
            deviceManufacturer: "Apple",
            osName: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            screenWidth: 0,
            screenHeight: 0,
            localeLanguage: Locale.current.languageCode,
            localeCountry: Locale.current.regionCode,
            timeZone: TimeZone.current.identifier
        )
        #endif
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