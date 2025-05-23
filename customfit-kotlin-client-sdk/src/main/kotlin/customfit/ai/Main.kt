package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.session.SessionManager
import customfit.ai.kotlinclient.core.session.SessionConfig
import customfit.ai.kotlinclient.core.session.SessionRotationListener
import customfit.ai.kotlinclient.core.session.RotationReason
import customfit.ai.kotlinclient.logging.Timber
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.runBlocking

@Suppress("UNUSED_PARAMETER")
fun main(args: Array<String>) {
        runBlocking {
                val timestamp = { SimpleDateFormat("HH:mm:ss.SSS").format(Date()) }

                println("[${timestamp()}] Starting CustomFit SDK Test with SessionManager Demo")
                
                // First run the SessionManager demo
                demonstrateSessionManager(timestamp)
                
                // Then run the original demo
                Timber.i("🔔 DIRECT TEST: Logging test via Timber")

                val clientKey =
                        "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

                val config =
                        CFConfig.Builder(clientKey)
                                .sdkSettingsCheckIntervalMs(2_000L)
                                .backgroundPollingIntervalMs(2_000L)
                                .reducedPollingIntervalMs(2_000L)
                                .summariesFlushTimeSeconds(3)
                                .summariesFlushIntervalMs(3_000L)
                                .eventsFlushTimeSeconds(3)
                                .eventsFlushIntervalMs(3_000L)
                                .debugLoggingEnabled(true)
                                .build()

                println("\n[${timestamp()}] Test config for SDK settings check:")
                println(
                        "[${timestamp()}] - SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms"
                )

                val user =
                        CFUser(
                                user_customer_id = "user123",
                                anonymous = false,
                                properties = mapOf("name" to "john")
                        )

                println("\n[${timestamp()}] Initializing CFClient with test config...")
                val cfClient = CFClient.init(config, user)
                
                // Test SessionManager integration with CFClient
                println("\n[${timestamp()}] Testing SessionManager integration with CFClient...")
                val clientSessionId = cfClient.getCurrentSessionId()
                println("[${timestamp()}] CFClient session ID: $clientSessionId")

                println(
                        "[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs"
                )
                println("[${timestamp()}] SDK initialization complete.")

                println(
                        "\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests..."
                )

                val flagListener: (String) -> Unit = { newValue ->
                        println("[${timestamp()}] CHANGE DETECTED: hero_text updated to: $newValue")
                }
                cfClient.addConfigListener<String>("hero_text", flagListener)

                println("\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---")
                for (i in 1..3) {
                        println("\n[${timestamp()}] Check cycle $i...")

                        println("[${timestamp()}] About to track event-$i for cycle $i")
                        val trackResult = cfClient.trackEvent("event-$i", mapOf("source" to "app"))
                        println(
                                "[${timestamp()}] Result of tracking event-$i: ${trackResult is CFResult.Success<*>}"
                        )
                        println("[${timestamp()}] Tracked event-$i for cycle $i")

                        println("[${timestamp()}] Waiting for SDK settings check...")
                        Thread.sleep(5000)

                        val currentValue = cfClient.getString("hero_text", "default-value")
                        println("[${timestamp()}] Value after check cycle $i: $currentValue")
                }

                cfClient.shutdown()

                println("\n[${timestamp()}] Test completed after all check cycles")
                println("[${timestamp()}] Test complete. Press Enter to exit...")
                readLine()
        }
}

suspend fun demonstrateSessionManager(timestamp: () -> String) {
    println("\n[${timestamp()}] ========== SessionManager Demo ==========")
    
    try {
        // Create custom session configuration
        val sessionConfig = SessionConfig(
            maxSessionDurationMs = TimeUnit.MINUTES.toMillis(30), // 30 minutes
            minSessionDurationMs = TimeUnit.MINUTES.toMillis(2),  // 2 minutes
            backgroundThresholdMs = TimeUnit.MINUTES.toMillis(5), // 5 minutes
            rotateOnAppRestart = true,
            rotateOnAuthChange = true,
            sessionIdPrefix = "demo_session",
            enableTimeBasedRotation = true
        )
        
        println("[${timestamp()}] Initializing SessionManager with custom config...")
        
        // Initialize SessionManager
        val result = SessionManager.initialize(sessionConfig)
        when (result) {
            is CFResult.Success -> {
                val sessionManager = result.data
                
                // Add a rotation listener
                sessionManager.addListener(object : SessionRotationListener {
                    override fun onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
                        println("[${timestamp()}] 🔄 Session rotated: $oldSessionId -> $newSessionId (${reason.description})")
                    }
                    
                    override fun onSessionRestored(sessionId: String) {
                        println("[${timestamp()}] 🔄 Session restored: $sessionId")
                    }
                    
                    override fun onSessionError(error: String) {
                        println("[${timestamp()}] ❌ Session error: $error")
                    }
                })
                
                // Get current session
                val sessionId = sessionManager.getCurrentSessionId()
                println("[${timestamp()}] 📍 Current session ID: $sessionId")
                
                // Get session statistics
                val stats = sessionManager.getSessionStats()
                println("[${timestamp()}] 📊 Session stats: $stats")
                
                // Simulate user activity
                println("[${timestamp()}] 👤 Simulating user activity...")
                sessionManager.updateActivity()
                
                // Simulate authentication change
                println("[${timestamp()}] 🔐 Simulating authentication change...")
                sessionManager.onAuthenticationChange("user_123")
                
                // Get new session ID after auth change
                val newSessionId = sessionManager.getCurrentSessionId()
                println("[${timestamp()}] 📍 New session ID after auth change: $newSessionId")
                
                // Force manual rotation
                println("[${timestamp()}] 🔄 Forcing manual session rotation...")
                val manualRotationId = sessionManager.forceRotation()
                println("[${timestamp()}] 📍 Session ID after manual rotation: $manualRotationId")
                
                println("[${timestamp()}] ✅ SessionManager demo completed successfully")
            }
            is CFResult.Error -> {
                println("[${timestamp()}] ❌ Failed to initialize SessionManager: ${result.error}")
            }
        }
    } catch (e: Exception) {
        println("[${timestamp()}] ❌ SessionManager demo failed: ${e.message}")
    }
    
    println("[${timestamp()}] ========== End SessionManager Demo ==========\n")
}
