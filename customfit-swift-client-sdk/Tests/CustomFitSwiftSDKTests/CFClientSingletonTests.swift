import XCTest
@testable import CustomFitSwiftSDK

final class CFClientSingletonTests: XCTestCase {
    
    private var testConfig: CFConfig!
    private var testUser: CFUser!
    
    override func setUp() {
        super.setUp()
        
        // Ensure clean state before each test
        CFClient.shutdownSingleton()
        
        // Create test configuration
        testConfig = CFConfig.builder("test-client-key")
            .debugLoggingEnabled(true)
            .offlineMode(true) // Use offline mode for testing
            .build()
        
        // Create test user
        testUser = CFUser(user_customer_id: "test-user-123")
            .addProperty(key: "platform", value: "swift-test")
    }
    
    override func tearDown() {
        // Clean up after each test
        CFClient.shutdownSingleton()
        super.tearDown()
    }
    
    func testSingletonCreation() {
        // Given: No existing instance
        XCTAssertFalse(CFClient.isInitialized())
        XCTAssertNil(CFClient.getInstance())
        
        // When: Creating first instance
        let client1 = CFClient.initialize(config: testConfig, user: testUser)
        
        // Then: Singleton should be created and accessible
        XCTAssertTrue(CFClient.isInitialized())
        XCTAssertNotNil(CFClient.getInstance())
        XCTAssertTrue(client1 === CFClient.getInstance())
    }
    
    func testSingletonReturnsSameInstance() {
        // Given: First instance created
        let client1 = CFClient.initialize(config: testConfig, user: testUser)
        
        // When: Creating second instance with different config
        let differentConfig = CFConfig.builder("different-key")
            .debugLoggingEnabled(false)
            .build()
        let differentUser = CFUser(user_customer_id: "different-user")
        
        let client2 = CFClient.initialize(config: differentConfig, user: differentUser)
        
        // Then: Should return the same instance
        XCTAssertTrue(client1 === client2)
        XCTAssertTrue(client1 === CFClient.getInstance())
    }
    
    func testGetInstanceWithoutInitialization() {
        // Given: No instance created
        XCTAssertFalse(CFClient.isInitialized())
        
        // When: Getting instance without initialization
        let instance = CFClient.getInstance()
        
        // Then: Should return nil
        XCTAssertNil(instance)
        XCTAssertFalse(CFClient.isInitialized())
    }
    
    func testIsInitializedStates() {
        // Initially not initialized
        XCTAssertFalse(CFClient.isInitialized())
        
        // After initialization
        let client = CFClient.initialize(config: testConfig, user: testUser)
        XCTAssertNotNil(client)
        XCTAssertTrue(CFClient.isInitialized())
        
        // After shutdown
        CFClient.shutdownSingleton()
        XCTAssertFalse(CFClient.isInitialized())
    }
    
    func testShutdownSingleton() {
        // Given: Initialized singleton
        let _ = CFClient.initialize(config: testConfig, user: testUser)
        XCTAssertTrue(CFClient.isInitialized())
        XCTAssertNotNil(CFClient.getInstance())
        
        // When: Shutting down
        CFClient.shutdownSingleton()
        
        // Then: Should be clean state
        XCTAssertFalse(CFClient.isInitialized())
        XCTAssertNil(CFClient.getInstance())
        XCTAssertFalse(CFClient.isInitializing())
    }
    
    func testReinitializeSingleton() {
        // Given: First instance
        let client1 = CFClient.initialize(config: testConfig, user: testUser)
        XCTAssertTrue(CFClient.isInitialized())
        
        // When: Reinitializing with new config
        let newConfig = CFConfig.builder("new-key")
            .debugLoggingEnabled(false)
            .build()
        let newUser = CFUser(user_customer_id: "new-user")
        
        let client2 = CFClient.reinitialize(config: newConfig, user: newUser)
        
        // Then: Should have new instance
        XCTAssertTrue(CFClient.isInitialized())
        XCTAssertNotNil(CFClient.getInstance())
        XCTAssertTrue(client2 === CFClient.getInstance())
        XCTAssertFalse(client1 === client2)
    }
    
    func testCreateDetachedInstance() {
        // Given: Existing singleton
        let singleton = CFClient.initialize(config: testConfig, user: testUser)
        XCTAssertTrue(CFClient.isInitialized())
        
        // When: Creating detached instance
        let detachedConfig = CFConfig.builder("detached-key")
            .debugLoggingEnabled(false)
            .build()
        let detachedUser = CFUser(user_customer_id: "detached-user")
        
        let detachedClient = CFClient.createDetached(config: detachedConfig, user: detachedUser)
        
        // Then: Singleton should remain unchanged
        XCTAssertTrue(CFClient.isInitialized())
        XCTAssertTrue(singleton === CFClient.getInstance())
        XCTAssertFalse(detachedClient === CFClient.getInstance())
        XCTAssertFalse(singleton === detachedClient)
    }
    
    func testIsInitializingFlag() {
        // Initially not initializing
        XCTAssertFalse(CFClient.isInitializing())
        
        // After successful initialization
        let client = CFClient.initialize(config: testConfig, user: testUser)
        XCTAssertNotNil(client)
        XCTAssertFalse(CFClient.isInitializing()) // Should be false after completion
        
        // After shutdown
        CFClient.shutdownSingleton()
        XCTAssertFalse(CFClient.isInitializing())
    }
    
    func testSingletonThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety test")
        let iterations = 10
        var completedCount = 0
        var clients: [CFClient] = []
        let clientsLock = NSLock()
        
        // Launch multiple concurrent initialization attempts
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let config = CFConfig.builder("test-key-\(i)")
                    .debugLoggingEnabled(true)
                    .offlineMode(true)
                    .build()
                let user = CFUser(user_customer_id: "test-user-\(i)")
                
                let client = CFClient.initialize(config: config, user: user)
                
                clientsLock.lock()
                clients.append(client)
                completedCount += 1
                
                if completedCount == iterations {
                    expectation.fulfill()
                }
                clientsLock.unlock()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // All clients should be the same instance
        XCTAssertEqual(clients.count, iterations)
        let firstClient = clients.first!
        
        for client in clients {
            XCTAssertTrue(client === firstClient, "All clients should be the same singleton instance")
        }
        
        // Should still be the singleton
        XCTAssertTrue(firstClient === CFClient.getInstance())
    }
    
    func testConcurrentAccessPatterns() {
        let expectation = XCTestExpectation(description: "Concurrent access test")
        var operationCount = 0
        let operationsLock = NSLock()
        let totalOperations = 20
        
        // Mix of different operations
        for i in 0..<totalOperations {
            DispatchQueue.global(qos: .default).async {
                switch i % 4 {
                case 0:
                    // Initialize
                    let client = CFClient.initialize(config: self.testConfig, user: self.testUser)
                    XCTAssertNotNil(client)
                    
                case 1:
                    // Get instance
                    let _ = CFClient.getInstance()
                    // May be nil initially, but should be consistent
                    
                case 2:
                    // Check status
                    let _ = CFClient.isInitialized()
                    let _ = CFClient.isInitializing()
                    // Just verify these don't crash
                    
                case 3:
                    // Create detached (only if singleton exists)
                    if CFClient.isInitialized() {
                        let detached = CFClient.createDetached(config: self.testConfig, user: self.testUser)
                        XCTAssertNotNil(detached)
                    }
                    
                default:
                    break
                }
                
                operationsLock.lock()
                operationCount += 1
                if operationCount == totalOperations {
                    expectation.fulfill()
                }
                operationsLock.unlock()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Should end in a consistent state
        if CFClient.isInitialized() {
            XCTAssertNotNil(CFClient.getInstance())
        } else {
            XCTAssertNil(CFClient.getInstance())
        }
    }
    
    func testShutdownAndReinitializeCycle() {
        // Test multiple cycles of shutdown and reinitialize
        for i in 0..<3 {
            // Initialize
            let config = CFConfig.builder("test-key-\(i)")
                .debugLoggingEnabled(true)
                .offlineMode(true)
                .build()
            let user = CFUser(user_customer_id: "test-user-\(i)")
            
            let client = CFClient.initialize(config: config, user: user)
            XCTAssertTrue(CFClient.isInitialized())
            XCTAssertNotNil(CFClient.getInstance())
            XCTAssertTrue(client === CFClient.getInstance())
            
            // Shutdown
            CFClient.shutdownSingleton()
            XCTAssertFalse(CFClient.isInitialized())
            XCTAssertNil(CFClient.getInstance())
        }
    }
} 