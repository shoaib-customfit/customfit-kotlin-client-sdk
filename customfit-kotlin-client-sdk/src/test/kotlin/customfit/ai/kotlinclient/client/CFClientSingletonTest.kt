package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import kotlinx.coroutines.*
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.time.Duration.Companion.seconds

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class CFClientSingletonTest {

    private lateinit var testConfig: CFConfig
    private lateinit var testUser: CFUser

    @BeforeEach
    fun setUp() {
        // Ensure clean state before each test
        runBlocking {
            CFClient.shutdown()
        }

        testConfig = CFConfig.Builder("test-client-key")
            .debugLoggingEnabled(true)
            .offlineMode(true) // Use offline mode for testing
            .build()

        testUser = CFUser.builder("test-user-123")
            .withStringProperty("platform", "test")
            .build()
    }

    @AfterEach
    fun tearDown() {
        // Clean up after each test
        runBlocking {
            CFClient.shutdown()
        }
    }

    @Test
    fun `test singleton creation returns same instance`() = runTest(timeout = 10.seconds) {
        // First call should create instance
        val client1 = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())
        assertNotNull(client1)

        // Second call should return same instance
        val client2 = CFClient.init(testConfig, testUser)
        assertSame(client1, client2)

        // getInstance should also return same instance
        val client3 = CFClient.getInstance()
        assertSame(client1, client3)
    }

    @Test
    fun `test singleton state before initialization`() = runTest {
        // Before initialization
        assertFalse(CFClient.isInitialized())
        assertNull(CFClient.getInstance())
        assertFalse(CFClient.isInitializing())
    }

    @Test
    fun `test singleton state during and after initialization`() = runTest {
        val initJob = async {
            CFClient.init(testConfig, testUser)
        }

        // Small delay to potentially catch initializing state
        delay(50)

        // Should be initialized by now (or initializing)
        val client = initJob.await()

        assertTrue(CFClient.isInitialized())
        assertNotNull(CFClient.getInstance())
        assertFalse(CFClient.isInitializing())
        assertSame(client, CFClient.getInstance())
    }

    @Test
    fun `test concurrent initialization returns same instance`() = runTest(timeout = 15.seconds) {
        val numberOfCoroutines = 10
        val clients = mutableListOf<CFClient>()
        val latch = CountDownLatch(numberOfCoroutines)

        // Launch multiple coroutines trying to initialize simultaneously
        repeat(numberOfCoroutines) {
            launch {
                try {
                    val client = CFClient.init(testConfig, testUser)
                    synchronized(clients) {
                        clients.add(client)
                    }
                } finally {
                    latch.countDown()
                }
            }
        }

        // Wait for all coroutines to complete
        withContext(Dispatchers.IO) {
            latch.await()
        }

        // All should have gotten the same instance
        assertEquals(numberOfCoroutines, clients.size)
        val firstClient = clients.first()
        clients.forEach { client ->
            assertSame(firstClient, client)
        }

        assertTrue(CFClient.isInitialized())
        assertSame(firstClient, CFClient.getInstance())
    }

    @Test
    fun `test concurrent initialization with different configurations`() = runTest(timeout = 15.seconds) {
        val config1 = CFConfig.Builder("client-key-1").offlineMode(true).build()
        val config2 = CFConfig.Builder("client-key-2").offlineMode(true).build()
        val user1 = CFUser.builder("user-1").build()
        val user2 = CFUser.builder("user-2").build()

        val clients = mutableListOf<CFClient>()
        val latch = CountDownLatch(4)

        // Launch coroutines with different configs - first one should win
        launch {
            try {
                val client = CFClient.init(config1, user1)
                synchronized(clients) { clients.add(client) }
            } finally {
                latch.countDown()
            }
        }

        launch {
            try {
                val client = CFClient.init(config2, user2)
                synchronized(clients) { clients.add(client) }
            } finally {
                latch.countDown()
            }
        }

        launch {
            try {
                val client = CFClient.init(config1, user1)
                synchronized(clients) { clients.add(client) }
            } finally {
                latch.countDown()
            }
        }

        launch {
            try {
                val client = CFClient.init(config2, user2)
                synchronized(clients) { clients.add(client) }
            } finally {
                latch.countDown()
            }
        }

        withContext(Dispatchers.IO) {
            latch.await()
        }

        // All should return the same instance (first one initialized)
        assertEquals(4, clients.size)
        val firstClient = clients.first()
        clients.forEach { client ->
            assertSame(firstClient, client)
        }
    }

    @Test
    fun `test shutdown clears singleton`() = runTest {
        // Create instance
        val client = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())
        assertSame(client, CFClient.getInstance())

        // Shutdown
        CFClient.shutdown()

        // Should be cleared
        assertFalse(CFClient.isInitialized())
        assertNull(CFClient.getInstance())
        assertFalse(CFClient.isInitializing())
    }

    @Test
    fun `test reinitialize creates new instance`() = runTest {
        // Create first instance
        val client1 = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())

        // Reinitialize with different config
        val newConfig = CFConfig.Builder("new-client-key").offlineMode(true).build()
        val newUser = CFUser.builder("new-user").build()
        val client2 = CFClient.reinitialize(newConfig, newUser)

        // Should be different instance
        assertNotSame(client1, client2)
        assertTrue(CFClient.isInitialized())
        assertSame(client2, CFClient.getInstance())
    }

    @Test
    fun `test createDetached bypasses singleton`() = runTest {
        // Create singleton instance
        val singletonClient = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())

        // Create detached instance
        val detachedClient = CFClient.createDetached(testConfig, testUser)

        // Should be different instances
        assertNotSame(singletonClient, detachedClient)

        // Singleton should still be intact
        assertTrue(CFClient.isInitialized())
        assertSame(singletonClient, CFClient.getInstance())
    }

    @Test
    fun `test thread safety with executor service`() = runTest(timeout = 20.seconds) {
        val numberOfThreads = 20
        val executor = Executors.newFixedThreadPool(numberOfThreads)
        val clients = mutableListOf<CFClient>()
        val initCount = AtomicInteger(0)
        val latch = CountDownLatch(numberOfThreads)

        repeat(numberOfThreads) { _ ->
            executor.submit {
                try {
                    runBlocking {
                        val client = CFClient.init(testConfig, testUser)
                        synchronized(clients) {
                            clients.add(client)
                        }
                        initCount.incrementAndGet()
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                } finally {
                    latch.countDown()
                }
            }
        }

        withContext(Dispatchers.IO) {
            latch.await()
        }

        executor.shutdown()

        // All threads should have gotten the same instance
        assertEquals(numberOfThreads, clients.size)
        assertEquals(numberOfThreads, initCount.get())

        val firstClient = clients.first()
        clients.forEach { client ->
            assertSame(firstClient, client, "All clients should be the same instance")
        }

        assertTrue(CFClient.isInitialized())
        assertSame(firstClient, CFClient.getInstance())
    }

    @Test
    fun `test initialization failure handling`() = runTest {
        // Test that even after multiple failed attempts to create instances with different configs,
        // once a valid instance is created, it remains the singleton
        
        // First ensure no singleton exists
        assertFalse(CFClient.isInitialized())
        assertNull(CFClient.getInstance())
        
        // Create a valid instance
        val validClient = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())
        assertSame(validClient, CFClient.getInstance())
        
        // Try to create another instance with different config - should return same instance
        val differentConfig = CFConfig.Builder("different-key").offlineMode(true).build()
        val differentUser = CFUser.builder("different-user").build()
        val secondClient = CFClient.init(differentConfig, differentUser)
        
        // Should return the same instance (singleton behavior)
        assertSame(validClient, secondClient)
        assertTrue(CFClient.isInitialized())
    }

    @Test
    fun `test singleton behavior across different initialization patterns`() = runTest {
        // Test various ways of trying to get instances all return the same singleton
        
        // Create initial instance
        val initialClient = CFClient.init(testConfig, testUser)
        assertTrue(CFClient.isInitialized())
        
        // Different configs should still return same instance
        val config2 = CFConfig.Builder("another-key").offlineMode(false).build()
        val user2 = CFUser.builder("another-user").withStringProperty("type", "test").build()
        val client2 = CFClient.init(config2, user2)
        
        // Instance method
        val client3 = CFClient.getInstance()
        
        // All should be the same
        assertSame(initialClient, client2)
        assertSame(initialClient, client3)
        
        // Only one instance should exist
        assertTrue(CFClient.isInitialized())
        assertFalse(CFClient.isInitializing())
    }
} 