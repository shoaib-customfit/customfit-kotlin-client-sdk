import Foundation

/// Application information
public struct ApplicationInfo: Codable {
    /// Application ID
    public let appId: String?
    
    /// Application version
    public let appVersion: String?
    
    /// Application build number
    public let appBuild: String?
    
    /// Application name
    public let appName: String?
    
    /// SDK version
    public let sdkVersion: String?
    
    /// SDK type
    public let sdkType: String?
    
    /// Initialize with all fields
    /// - Parameters:
    ///   - appId: Application ID
    ///   - appVersion: Application version
    ///   - appBuild: Application build number
    ///   - appName: Application name
    ///   - sdkVersion: SDK version
    ///   - sdkType: SDK type
    public init(
        appId: String? = nil,
        appVersion: String? = nil,
        appBuild: String? = nil,
        appName: String? = nil,
        sdkVersion: String? = nil,
        sdkType: String? = nil
    ) {
        self.appId = appId
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.appName = appName
        self.sdkVersion = sdkVersion
        self.sdkType = sdkType
    }
    
    /// Convert to dictionary representation
    /// - Returns: Dictionary with application info properties
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let appId = appId { dict["app_id"] = appId }
        if let appVersion = appVersion { dict["app_version"] = appVersion }
        if let appBuild = appBuild { dict["app_build"] = appBuild }
        if let appName = appName { dict["app_name"] = appName }
        if let sdkVersion = sdkVersion { dict["sdk_version"] = sdkVersion }
        if let sdkType = sdkType { dict["sdk_type"] = sdkType }
        
        return dict
    }
    
    /// Create from dictionary representation
    /// - Parameter dict: Dictionary with application info properties
    /// - Returns: ApplicationInfo instance
    public static func fromDictionary(_ dict: [String: Any]) -> ApplicationInfo {
        return ApplicationInfo(
            appId: dict["app_id"] as? String,
            appVersion: dict["app_version"] as? String,
            appBuild: dict["app_build"] as? String,
            appName: dict["app_name"] as? String,
            sdkVersion: dict["sdk_version"] as? String,
            sdkType: dict["sdk_type"] as? String
        )
    }
    
    /// Create a basic ApplicationInfo with current app details
    public static func createBasic() -> ApplicationInfo {
        let bundle = Bundle.main
        let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let appBuild = bundle.infoDictionary?["CFBundleVersion"] as? String
        let appName = bundle.infoDictionary?["CFBundleName"] as? String
        let appId = bundle.bundleIdentifier
        
        return ApplicationInfo(
            appId: appId,
            appVersion: appVersion,
            appBuild: appBuild,
            appName: appName
        )
    }
} 