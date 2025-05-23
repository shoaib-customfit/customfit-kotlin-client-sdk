import XCTest
@testable import CustomFitSwiftSDK

final class CFConfigTests: XCTestCase {
    func testBasicConfiguration() {
        let config = CFConfig(clientKey: "test-key")
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertTrue(config.loggingEnabled)
        XCTAssertFalse(config.debugLoggingEnabled)
        XCTAssertFalse(config.offlineMode)
    }
    
    func testConfigurationWithCustomValues() {
        let config = CFConfig(
            clientKey: "test-key",
            eventsQueueSize: 200,
            loggingEnabled: false,
            debugLoggingEnabled: true,
            offlineMode: true
        )
        
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertEqual(config.eventsQueueSize, 200)
        XCTAssertFalse(config.loggingEnabled)
        XCTAssertTrue(config.debugLoggingEnabled)
        XCTAssertTrue(config.offlineMode)
    }
    
    static var allTests = [
        ("testBasicConfiguration", testBasicConfiguration),
        ("testConfigurationWithCustomValues", testConfigurationWithCustomValues),
    ]
} 