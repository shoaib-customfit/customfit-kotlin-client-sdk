import Foundation

/// Device context information
public struct DeviceContext: Codable {
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
    
    /// Screen width in pixels
    public let screenWidth: Int?
    
    /// Screen height in pixels
    public let screenHeight: Int?
    
    /// Locale language code
    public let localeLanguage: String?
    
    /// Locale country code
    public let localeCountry: String?
    
    /// Device time zone
    public let timeZone: String?
    
    /// Battery level (0-100)
    public let batteryLevel: Int?
    
    /// Whether the device is charging
    public let isCharging: Bool?
    
    /// Network connection type
    public let networkType: String?
    
    /// Initialize with all fields
    /// - Parameters:
    ///   - deviceId: Device ID
    ///   - deviceModel: Device model
    ///   - deviceManufacturer: Device manufacturer
    ///   - osName: Operating system name
    ///   - osVersion: Operating system version
    ///   - screenWidth: Screen width in pixels
    ///   - screenHeight: Screen height in pixels
    ///   - localeLanguage: Locale language code
    ///   - localeCountry: Locale country code
    ///   - timeZone: Device time zone
    ///   - batteryLevel: Battery level (0-100)
    ///   - isCharging: Whether the device is charging
    ///   - networkType: Network connection type
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
        batteryLevel: Int? = nil,
        isCharging: Bool? = nil,
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
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.networkType = networkType
    }
    
    /// Convert to dictionary representation
    /// - Returns: Dictionary with device context properties
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let deviceId = deviceId { dict["device_id"] = deviceId }
        if let deviceModel = deviceModel { dict["device_model"] = deviceModel }
        if let deviceManufacturer = deviceManufacturer { dict["device_manufacturer"] = deviceManufacturer }
        if let osName = osName { dict["os_name"] = osName }
        if let osVersion = osVersion { dict["os_version"] = osVersion }
        if let screenWidth = screenWidth { dict["screen_width"] = screenWidth }
        if let screenHeight = screenHeight { dict["screen_height"] = screenHeight }
        if let localeLanguage = localeLanguage { dict["locale_language"] = localeLanguage }
        if let localeCountry = localeCountry { dict["locale_country"] = localeCountry }
        if let timeZone = timeZone { dict["time_zone"] = timeZone }
        if let batteryLevel = batteryLevel { dict["battery_level"] = batteryLevel }
        if let isCharging = isCharging { dict["is_charging"] = isCharging }
        if let networkType = networkType { dict["network_type"] = networkType }
        
        return dict
    }
    
    /// Create from dictionary representation
    /// - Parameter dict: Dictionary with device context properties
    /// - Returns: DeviceContext instance
    public static func fromDictionary(_ dict: [String: Any]) -> DeviceContext {
        return DeviceContext(
            deviceId: dict["device_id"] as? String,
            deviceModel: dict["device_model"] as? String,
            deviceManufacturer: dict["device_manufacturer"] as? String,
            osName: dict["os_name"] as? String,
            osVersion: dict["os_version"] as? String,
            screenWidth: dict["screen_width"] as? Int,
            screenHeight: dict["screen_height"] as? Int,
            localeLanguage: dict["locale_language"] as? String,
            localeCountry: dict["locale_country"] as? String,
            timeZone: dict["time_zone"] as? String,
            batteryLevel: dict["battery_level"] as? Int,
            isCharging: dict["is_charging"] as? Bool,
            networkType: dict["network_type"] as? String
        )
    }
} 