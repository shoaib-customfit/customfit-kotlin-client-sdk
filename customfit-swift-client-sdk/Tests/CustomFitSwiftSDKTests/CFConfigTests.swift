import XCTest
@testable import CustomFitSwiftSDK

final class CFConfigTests: XCTestCase {
    func testConfigInitialization() {
        let config = CFConfig(clientKey: "test-key")
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertEqual(config.apiBaseUrl, "https://api.customfit.ai/v1")
    }
    
    func testBuilderPattern() {
        let config = CFConfig.Builder(clientKey: "test-key")
            .eventsQueueSize(200)
            .logLevel("INFO")
            .build()
            
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertEqual(config.eventsQueueSize, 200)
        XCTAssertEqual(config.logLevel, "INFO")
    }
    
    static var allTests = [
        ("testConfigInitialization", testConfigInitialization),
        ("testBuilderPattern", testBuilderPattern),
    ]
} 