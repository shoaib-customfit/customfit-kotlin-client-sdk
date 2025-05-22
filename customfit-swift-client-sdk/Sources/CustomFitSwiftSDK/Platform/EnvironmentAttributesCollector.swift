import Foundation

/// Collects various environment attributes for analytics and reporting.
public class EnvironmentAttributesCollector {

    public static var shared: EnvironmentAttributesCollector! // Made it an implicitly unwrapped optional

    private let appInfoProvider: ApplicationInfoProvider
    private let platformInfoProvider: PlatformInfoProvider
    private let backgroundStateMonitor: BackgroundStateMonitor

    private init(appInfoProvider: ApplicationInfoProvider = .shared,
                 platformInfoProvider: PlatformInfoProvider = .shared,
                 backgroundStateMonitor: BackgroundStateMonitor) {
        self.appInfoProvider = appInfoProvider
        self.platformInfoProvider = platformInfoProvider
        self.backgroundStateMonitor = backgroundStateMonitor
    }
    
    /// Initializes the shared instance. This should be called once during SDK setup.
    public static func initializeShared(backgroundStateMonitor: BackgroundStateMonitor) {
        guard shared == nil else {
            Logger.warning("EnvironmentAttributesCollector shared instance already initialized.")
            return
        }
        shared = EnvironmentAttributesCollector(backgroundStateMonitor: backgroundStateMonitor)
    }

    /// Collects all environment attributes.
    /// Note: Kotlin's version includes carrierName which is hard to get reliably in Swift without CoreTelephony
    /// and specific entitlements. It's omitted here for broader compatibility.
    public func getAllAttributes() -> [String: Any] {
        var attributes: [String: Any] = [
            "appVersion": appInfoProvider.appVersion,
            "osVersion": platformInfoProvider.osVersion,
            "deviceModel": platformInfoProvider.deviceModel,
            "language": platformInfoProvider.languageCode,
            "countryCode": platformInfoProvider.regionCode, // Maps to countryCode in Kotlin
            "timeZone": platformInfoProvider.timeZoneIdentifier,
            "sdkPlatform": "swift",
            "sdkName": platformInfoProvider.sdkName,
            "sdkVersion": platformInfoProvider.sdkVersion,
            "appName": appInfoProvider.appName,
            "bundleId": appInfoProvider.bundleId,
            "osName": platformInfoProvider.osName
        ]

        // Battery info
        let batteryState = backgroundStateMonitor.getCurrentBatteryState()
        attributes["batteryLevel"] = Int(batteryState.level * 100) // As percentage int
        attributes["isCharging"] = batteryState.isCharging
        attributes["isBatteryLow"] = batteryState.isLow // Swift specific, but useful

        // Network type from PlatformInfoProvider (currently basic "unknown")
        attributes["networkType"] = platformInfoProvider.networkConnectionType
        
        // App install/update times if available
        if let installTime = appInfoProvider.appInstallTime {
            attributes["appInstallTime"] = Int(installTime.timeIntervalSince1970)
        }
        if let updateTime = appInfoProvider.appUpdateTime {
            attributes["appUpdateTime"] = Int(updateTime.timeIntervalSince1970)
        }

        return attributes
    }
} 