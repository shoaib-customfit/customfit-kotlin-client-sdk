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

                println(
                        "[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs"
                )
                println("[${timestamp()}] Waiting for initial SDK settings check...")
                cfClient.awaitSdkSettingsCheck()
                println("[${timestamp()}] Initial SDK settings check complete.")

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
