import Foundation

/// Provides application-specific information.
public class ApplicationInfoProvider {

    public static let shared = ApplicationInfoProvider()

    private init() {}

    /// The application's name.
    public var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ??
               Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "UnknownApp"
    }

    /// The application's version string (e.g., "1.2.3").
    public var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// The application's build number string (e.g., "100").
    public var appBuildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "0"
    }
    
    /// The application's bundle identifier (e.g., "com.example.myapp").
    public var bundleId: String {
        return Bundle.main.bundleIdentifier ?? "ai.customfit.swift.demo"
    }
    
    // Corresponds to getAppInstallTime and getAppUpdateTime from Kotlin's ApplicationInfoDetector
    // These are harder to get reliably and cross-platform on iOS without specific file tracking.
    // For now, returning nil or a placeholder. More specific implementation might be needed if critical.

    /// Estimated application install time.
    /// Note: This is often non-trivial to get accurately on iOS.
    /// This currently returns the file creation date of the app's bundle.
    public var appInstallTime: Date? {
        let bundlePath = Bundle.main.bundleURL
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: bundlePath.path)
            return attributes[.creationDate] as? Date
        } catch {
            Logger.warning("Could not retrieve app install time: \(error.localizedDescription)")
            return nil
        }
    }

    /// Estimated application last update time.
    /// Note: This is often non-trivial to get accurately on iOS.
    /// This currently returns the file modification date of the app's bundle.
    public var appUpdateTime: Date? {
        let bundlePath = Bundle.main.bundleURL
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: bundlePath.path)
            return attributes[.modificationDate] as? Date
        } catch {
            Logger.warning("Could not retrieve app update time: \(error.localizedDescription)")
            return nil
        }
    }

    public func getAppInfo() -> [String: Any] {
        var info: [String: Any] = [
            "appName": appName,
            "appVersion": appVersion,
            "appBuildNumber": appBuildNumber,
            "bundleId": bundleId
        ]
        if let installDate = appInstallTime {
            info["appInstallTime"] = installDate.timeIntervalSince1970
        }
        if let updateDate = appUpdateTime {
            info["appUpdateTime"] = updateDate.timeIntervalSince1970
        }
        return info
    }
} 