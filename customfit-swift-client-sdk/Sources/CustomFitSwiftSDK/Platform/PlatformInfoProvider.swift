import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit // For NSWorkspace
#endif

/// Provides platform-specific information like OS, device model, etc.
public class PlatformInfoProvider {

    public static let shared = PlatformInfoProvider()

    private init() {}

    /// The name of the operating system (e.g., "iOS", "macOS").
    public var osName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(Linux)
        return "Linux"
        #else
        return "UnknownOS"
        #endif
    }

    /// The version of the operating system (e.g., "15.1").
    public var osVersion: String {
        #if os(watchOS)
        return WKInterfaceDevice.current().systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    /// The model of the device (e.g., "iPhone13,2").
    public var deviceModel: String {
        #if os(iOS) || os(tvOS) || os(watchOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #elseif os(macOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        // More user-friendly model name for macOS if possible
        // This is a simplification; a full mapping would be extensive.
        // For example, see https://gist.github.com/adamawolf/3048717
        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
        if identifier.hasPrefix("iMac") { return "iMac" }
        if identifier.hasPrefix("Macmini") { return "Mac mini" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro" }
        return identifier // Fallback to identifier like "MacBookPro17,1"
        #else
        return "UnknownDevice"
        #endif
    }

    /// The name of the SDK.
    public var sdkName: String {
        return CFConstants.General.SDK_NAME // Assuming CFConstants is available
    }

    /// The version of the SDK.
    public var sdkVersion: String {
        return CFConstants.General.DEFAULT_SDK_VERSION // Assuming CFConstants is available
    }

    /// Current language code (e.g., "en").
    public var languageCode: String {
        return Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "unknown"
    }

    /// Current region code (e.g., "US").
    public var regionCode: String {
        return Locale.current.regionCode ?? "unknown"
    }

    /// Current time zone identifier (e.g., "America/New_York").
    public var timeZoneIdentifier: String {
        return TimeZone.current.identifier
    }
    
    /// Network connection type (wifi, cellular, none).
    /// This is a simplified version as ConnectionManager no longer directly polls network type.
    /// It could be enhanced if ConnectionManager provides a best-effort type.
    public var networkConnectionType: String {
        // To align with Kotlin's PlatformInfo.getNetworkConnectionType() which returns "unknown"
        // or a stubbed value, we will also return a basic value.
        // A more sophisticated version might check ConnectionManager.shared.currentStatus if available
        // and if that status implies a certain connectivity, but that couples them.
        return "unknown" // Matches Kotlin's stub
    }

    public func getPlatformDetails() -> [String: String] {
        return [
            "osName": osName,
            "osVersion": osVersion,
            "deviceModel": deviceModel,
            "sdkName": sdkName,
            "sdkVersion": sdkVersion,
            "languageCode": languageCode,
            "regionCode": regionCode,
            "timeZoneIdentifier": timeZoneIdentifier,
            "networkConnectionType": networkConnectionType,
            "sdkPlatform": "swift" // To match Kotlin's "sdk_platform"
        ]
    }
} 