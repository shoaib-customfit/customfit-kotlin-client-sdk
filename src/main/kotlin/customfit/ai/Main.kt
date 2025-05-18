package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.logging.Timber
import java.text.SimpleDateFormat
import java.util.Date
import kotlinx.coroutines.runBlocking

@Suppress("UNUSED_PARAMETER")
fun main(args: Array<String>) {
    runBlocking {
        val timestamp = { SimpleDateFormat("HH:mm:ss.SSS").format(Date()) }

        println("[${timestamp()}] Starting CustomFit SDK Test")
        // Test direct logging with Timber
        Timber.i("🔔 DIRECT TEST: Logging test via Timber")

        // Configure with a short settings check interval
        val clientKey =
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

        val config =
                CFConfig.Builder(clientKey)
                        .sdkSettingsCheckIntervalMs(20_000L)
                        .backgroundPollingIntervalMs(20_000L)
                        .reducedPollingIntervalMs(20_000L)
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

        // Add custom output to see SDK events
        println("[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs")

        println("[${timestamp()}] Waiting for initial SDK settings check...")
        cfClient.awaitSdkSettingsCheck() // Wait for the initial fetch to complete
        println("[${timestamp()}] Initial SDK settings check complete.")

       

        // Comment out event tracking to reduce POST calls
        println("\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests...")
        // cfClient.trackEvent("login_event", mapOf("source" to "app"))
        // cfClient.trackEvent("page_view", mapOf("page" to "home", "duration" to 30))
        // cfClient.trackEvent("button_click", mapOf("button_id" to "submit", "page" to "checkout"))

        // Register a listener to detect changes in real-time
        val flagListener: (String) -> Unit = { newValue ->
            println("[${timestamp()}] CHANGE DETECTED: hero_text updated to: $newValue")
        }
        cfClient.addConfigListener<String>("hero_text", flagListener)

        // Run normal check cycles with auto-refresh
        println("\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---")
        for (i in 1..3) {
            println("\n[${timestamp()}] Check cycle $i...")

            // Track event-i for each cycle and explicitly flush
            println("[${timestamp()}] About to track event-$i for cycle $i")
            val trackResult = cfClient.trackEvent("event-$i", mapOf("source" to "app"))
            println("[${timestamp()}] Result of tracking event-$i: ${trackResult is CFResult.Success}")
            println("[${timestamp()}] Tracked event-$i for cycle $i")
            
            // Force a flush of event queue to ensure events are sent immediately
            println("[${timestamp()}] About to flush event queue")
            val flushResult = cfClient.flushEvents()
            println("[${timestamp()}] Raw flush result: $flushResult")
            when (flushResult) {
                is CFResult.Success -> {
                    println("[${timestamp()}] Explicitly flushed ${flushResult.data} events")
                }
                is CFResult.Error -> {
                    println("[${timestamp()}] Failed to flush events: ${flushResult.error}")
                }
            }

            // Wait for next check - only wait 1 second to see more frequent updates
            println("[${timestamp()}] Waiting for SDK settings check...")
            Thread.sleep(5000)

            // Get current value
            val currentValue = cfClient.getString("hero_text", "default-value")
            println("[${timestamp()}] Value after check cycle $i: $currentValue")
        }

      
        // Clean up
        cfClient.shutdown()

        println("\n[${timestamp()}] Test completed after all check cycles")
        println("[${timestamp()}] Test complete. Press Enter to exit...")
        readLine()
    }
}
