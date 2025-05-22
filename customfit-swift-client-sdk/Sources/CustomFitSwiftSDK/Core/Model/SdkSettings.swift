import Foundation

/// Simplified SdkSettings model with only essential flags
/// Only includes fields that are needed for core SDK functionality
public struct SdkSettings: Codable {
    public let cf_account_enabled: Bool
    public let cf_skip_sdk: Bool
    
    public init(cf_account_enabled: Bool = true, cf_skip_sdk: Bool = false) {
        self.cf_account_enabled = cf_account_enabled
        self.cf_skip_sdk = cf_skip_sdk
    }
} 