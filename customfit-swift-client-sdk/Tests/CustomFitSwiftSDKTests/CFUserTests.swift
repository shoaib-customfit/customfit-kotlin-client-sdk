import XCTest
@testable import CustomFitSwiftSDK

final class CFUserTests: XCTestCase {
    
    func testBasicUserCreation() {
        let user = CFUser(user_customer_id: "test-user-123")
        
        XCTAssertEqual(user.getUserId(), "test-user-123")
        XCTAssertNil(user.getAnonymousId())
        XCTAssertNil(user.getDeviceId())
        XCTAssertFalse(user.anonymous)
        XCTAssertTrue(user.getCurrentProperties().isEmpty)
    }
    
    func testAnonymousUser() {
        let user = CFUser(anonymous: true)
        
        XCTAssertNil(user.getUserId())
        XCTAssertTrue(user.anonymous)
        XCTAssertTrue(user.getCurrentProperties().isEmpty)
    }
    
    func testUserWithProperties() {
        let properties = ["name": "John Doe", "age": 30] as [String: Any]
        let user = CFUser(user_customer_id: "test-user", properties: properties)
        
        XCTAssertEqual(user.getUserId(), "test-user")
        XCTAssertEqual(user.getProperty(key: "name") as? String, "John Doe")
        XCTAssertEqual(user.getProperty(key: "age") as? Int, 30)
    }
    
    func testUserImmutability() {
        let originalUser = CFUser(user_customer_id: "original-user")
        let updatedUser = originalUser.addProperty(key: "newProp", value: "newValue")
        
        // Original user should remain unchanged
        XCTAssertTrue(originalUser.getCurrentProperties().isEmpty)
        
        // Updated user should have the new property
        XCTAssertEqual(updatedUser.getProperty(key: "newProp") as? String, "newValue")
        XCTAssertEqual(updatedUser.getUserId(), "original-user")
    }
    
    func testToUserMap() {
        let user = CFUser(
            user_customer_id: "test-user",
            properties: ["name": "John", "age": 25]
        )
        
        let userMap = user.toUserMap()
        
        XCTAssertEqual(userMap["user_customer_id"] as? String, "test-user")
        XCTAssertEqual(userMap["anonymous"] as? Bool, false)
        
        let properties = userMap["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertEqual(properties?["name"] as? String, "John")
        XCTAssertEqual(properties?["age"] as? Int, 25)
    }
} 