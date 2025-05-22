import Foundation

/// Device context containing information about the user's device
public struct DeviceContext {
    /// Device ID
    public let deviceId: String?
    
    /// Device model
    public let deviceModel: String?
    
    /// Device manufacturer
    public let deviceManufacturer: String?
    
    /// Operating system name
    public let osName: String?
    
    /// Operating system version
    public let osVersion: String?
    
    /// Screen width
    public let screenWidth: Int?
    
    /// Screen height
    public let screenHeight: Int?
    
    /// Locale language
    public let localeLanguage: String?
    
    /// Locale country
    public let localeCountry: String?
    
    /// Time zone
    public let timeZone: String?
    
    /// Network type
    public let networkType: String?
    
    /// Initialize a new device context
    /// - Parameters:
    ///   - deviceId: Device ID
    ///   - deviceModel: Device model
    ///   - deviceManufacturer: Device manufacturer
    ///   - osName: Operating system name
    ///   - osVersion: Operating system version
    ///   - screenWidth: Screen width
    ///   - screenHeight: Screen height
    ///   - localeLanguage: Locale language
    ///   - localeCountry: Locale country
    ///   - timeZone: Time zone
    ///   - networkType: Network type
    public init(
        deviceId: String? = nil,
        deviceModel: String? = nil,
        deviceManufacturer: String? = nil,
        osName: String? = nil,
        osVersion: String? = nil,
        screenWidth: Int? = nil,
        screenHeight: Int? = nil,
        localeLanguage: String? = nil,
        localeCountry: String? = nil,
        timeZone: String? = nil,
        networkType: String? = nil
    ) {
        self.deviceId = deviceId
        self.deviceModel = deviceModel
        self.deviceManufacturer = deviceManufacturer
        self.osName = osName
        self.osVersion = osVersion
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.localeLanguage = localeLanguage
        self.localeCountry = localeCountry
        self.timeZone = timeZone
        self.networkType = networkType
    }
    
    /// Convert to dictionary
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let deviceId = deviceId {
            result["id"] = deviceId
        }
        
        if let deviceModel = deviceModel {
            result["model"] = deviceModel
        }
        
        if let deviceManufacturer = deviceManufacturer {
            result["manufacturer"] = deviceManufacturer
        }
        
        if let osName = osName {
            result["os_name"] = osName
        }
        
        if let osVersion = osVersion {
            result["os_version"] = osVersion
        }
        
        if let screenWidth = screenWidth {
            result["screen_width"] = screenWidth
        }
        
        if let screenHeight = screenHeight {
            result["screen_height"] = screenHeight
        }
        
        if let localeLanguage = localeLanguage {
            result["locale_language"] = localeLanguage
        }
        
        if let localeCountry = localeCountry {
            result["locale_country"] = localeCountry
        }
        
        if let timeZone = timeZone {
            result["timezone"] = timeZone
        }
        
        if let networkType = networkType {
            result["network_type"] = networkType
        }
        
        return result
    }
} 