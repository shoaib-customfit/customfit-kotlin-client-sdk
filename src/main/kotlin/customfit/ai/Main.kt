package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import java.text.SimpleDateFormat
import java.util.Date
import kotlinx.coroutines.runBlocking

@Suppress("UNUSED_PARAMETER")
fun main(args: Array<String>) {
    runBlocking {
        val timestamp = { SimpleDateFormat("HH:mm:ss.SSS").format(Date()) }

        println("[${timestamp()}] Starting CustomFit SDK Test")

        // Configure with a short settings check interval
        val clientKey =
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

        val config =
                CFConfig.Builder(clientKey)
                        .sdkSettingsCheckIntervalMs(5_000L) // 5 seconds for quick testing
                        .summariesFlushTimeSeconds(3) // 3 seconds for summaries flush time
                        .summariesFlushIntervalMs(3_000L) // 3 seconds for summaries flush interval
                        .eventsFlushTimeSeconds(3) // 3 seconds for events flush time
                        .eventsFlushIntervalMs(3_000L) // 3 seconds for events flush interval
                        .debugLoggingEnabled(true)
                        .build()

        println("\n[${timestamp()}] Test config for SDK settings check:")
        println(
                "[${timestamp()}] - SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms"
        )
        println("[${timestamp()}] - Summaries Flush Time: ${config.summariesFlushTimeSeconds}s")
        println("[${timestamp()}] - Summaries Flush Interval: ${config.summariesFlushIntervalMs}ms")
        println("[${timestamp()}] - Events Flush Time: ${config.eventsFlushTimeSeconds}s")
        println("[${timestamp()}] - Events Flush Interval: ${config.eventsFlushIntervalMs}ms")
        println("[${timestamp()}] - Debug Logging Enabled: ${config.debugLoggingEnabled}")

        println("\n[${timestamp()}] --- Timing Parameters Explanation ---")
        println(
                "[${timestamp()}] Flush Time: Maximum time an item can stay in queue before forcing a flush"
        )
        println("[${timestamp()}] Flush Interval: How often the system checks for items to flush")

        // Create a user
        val user =
                CFUser(
                        user_customer_id = "user123",
                        anonymous = false,
                        properties = mapOf("name" to "john")
                )

        println("\n[${timestamp()}] Initializing CFClient with test config...")
        val cfClient = CFClient.init(config, user)

        println("[${timestamp()}] Waiting for initial SDK settings check...")
        cfClient.awaitSdkSettingsCheck() // Wait for the initial fetch to complete
        println("[${timestamp()}] Initial SDK settings check complete.")

        // Test a feature flag
        val initialValue = cfClient.getString("shoaib-1", "default-value")
        println("[${timestamp()}] Initial value of shoaib-1: $initialValue")

        // Track some events to test summary flush
        println("[${timestamp()}] Testing event tracking with summaries...")
        cfClient.trackEvent("login_event", mapOf("source" to "app"))
        cfClient.trackEvent("page_view", mapOf("page" to "home", "duration" to 30))
        cfClient.trackEvent("button_click", mapOf("button_id" to "submit", "page" to "checkout"))

        // Register a listener to detect changes in real-time
        val flagListener: (String) -> Unit = { newValue ->
            println("[${timestamp()}] CHANGE DETECTED: shoaib-1 updated to: $newValue")
        }
        cfClient.addConfigListener<String>("shoaib-1", flagListener)

        // Run normal check cycles
        println("\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---")
        for (i in 1..5) {
            println("\n[${timestamp()}] Check cycle $i...")

            // Track an event in each cycle
            cfClient.trackEvent("cycle_event", mapOf("cycle" to i, "phase" to 1))

            // Wait for next check
            println("[${timestamp()}] Waiting for SDK settings check...")
            Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)

            // Get current value
            val currentValue = cfClient.getString("shoaib-1", "default-value")
            println("[${timestamp()}] Value after check cycle $i: $currentValue")
        }

        // Force a metadata refresh using reflection
        println("\n[${timestamp()}] --- PHASE 2: Forcing Metadata Refresh ---")
        println(
                "[${timestamp()}] Attempting to reset previousLastModified field using reflection..."
        )

        try {
            val previousLastModifiedField =
                    CFClient::class.java.getDeclaredField("previousLastModified")
            previousLastModifiedField.isAccessible = true
            val previousValue = previousLastModifiedField.get(cfClient)
            println("[${timestamp()}] Current previousLastModified value: $previousValue")

            // Track events during forced refresh
            cfClient.trackEvent("forced_refresh", mapOf("timestamp" to System.currentTimeMillis()))

            // Set to null to force a refresh on next check
            previousLastModifiedField.set(cfClient, null)
            println("[${timestamp()}] Reset previousLastModified to null")

            // Wait for the next check cycle
            println("[${timestamp()}] Waiting for forced refresh check cycle...")
            Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)

            // Get current value
            val currentValue = cfClient.getString("shoaib-1", "default-value")
            println("[${timestamp()}] Value after forced refresh: $currentValue")

            // Check if previousLastModified has been updated
            val newValue = previousLastModifiedField.get(cfClient)
            println("[${timestamp()}] New previousLastModified value: $newValue")
        } catch (e: Exception) {
            println("[${timestamp()}] Failed to access previousLastModified field: ${e.message}")
            e.printStackTrace()
        }

        // Continue normal checking for a few more cycles
        println("\n[${timestamp()}] --- PHASE 3: Continuing Normal Checks ---")
        for (i in 4..5) {
            println("\n[${timestamp()}] Check cycle $i...")

            // Track an event in each cycle
            cfClient.trackEvent("cycle_event", mapOf("cycle" to i, "phase" to 3))

            // Wait for next check
            println("[${timestamp()}] Waiting for SDK settings check...")
            Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)

            // Get current value
            val currentValue = cfClient.getString("shoaib-1", "default-value")
            println("[${timestamp()}] Value after check cycle $i: $currentValue")
        }

        // Clean up
        cfClient.shutdown()

        println("\n[${timestamp()}] Test completed after 5 check cycles")
        println("[${timestamp()}] Test complete. Press Enter to exit...")
        readLine()
    }
}
