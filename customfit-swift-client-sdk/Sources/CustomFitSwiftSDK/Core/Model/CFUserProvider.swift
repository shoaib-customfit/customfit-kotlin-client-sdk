import Foundation

/// Protocol for providing user information to the CustomFit SDK
public protocol CFUserProvider {
    /// Get the current user
    /// - Returns: The current user
    func getUser() -> CFUser
}

/// Extension to make CFUser directly conform to CFUserProvider
extension CFUser: CFUserProvider {
    /// Return self as the user
    /// - Returns: Self
    public func getUser() -> CFUser {
        return self
    }
} 