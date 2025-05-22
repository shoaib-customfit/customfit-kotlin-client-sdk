import Foundation

/// Application information for context
public struct ApplicationInfo {
    /// Application identifier
    public let appId: String?
    
    /// Application version
    public let appVersion: String?
    
    /// Application build number
    public let appBuild: String?
    
    /// Application name
    public let appName: String?
    
    /// SDK version
    public let sdkVersion: String
    
    /// SDK type (swift)
    public let sdkType: String
    
    /// Initialize a new application info
    /// - Parameters:
    ///   - appId: Application identifier
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
        sdkVersion: String = CFConstants.General.DEFAULT_SDK_VERSION,
        sdkType: String = "swift"
    ) {
        self.appId = appId
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.appName = appName
        self.sdkVersion = sdkVersion
        self.sdkType = sdkType
    }
    
    /// Convert to dictionary
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["sdk_version"] = sdkVersion
        result["sdk_type"] = sdkType
        
        if let appId = appId {
            result["id"] = appId
        }
        
        if let appVersion = appVersion {
            result["version"] = appVersion
        }
        
        if let appBuild = appBuild {
            result["build"] = appBuild
        }
        
        if let appName = appName {
            result["name"] = appName
        }
        
        return result
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