package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import mu.KotlinLogging
import java.util.Date

private val logger = KotlinLogging.logger {}

fun main() {
    logger.info { "Starting CustomFit SDK" }
    val clientKey =
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

    // Method 1: Basic config with default values
    val basicCfConfig = CFConfig(clientKey)
    println("Basic config using defaults:")
    println("- Events Queue Size: ${basicCfConfig.eventsQueueSize}")
    println("- Events Flush Time: ${basicCfConfig.eventsFlushTimeSeconds} seconds")
    println("- Events Flush Interval: ${basicCfConfig.eventsFlushIntervalMs}ms")
    println("- SDK Settings Check Interval: ${basicCfConfig.sdkSettingsCheckIntervalMs}ms")
    println("- Network Connection Timeout: ${basicCfConfig.networkConnectionTimeoutMs}ms")
    println("- Network Read Timeout: ${basicCfConfig.networkReadTimeoutMs}ms")
    
    // Method 2: Config with some custom values using named parameters
    val customCfConfig = CFConfig(
        clientKey = clientKey,
        eventsQueueSize = 50,                    // Override default queue size
        eventsFlushTimeSeconds = 30,                // Override default flush time
        eventsFlushIntervalMs = 2000L,              // Override default flush interval
        sdkSettingsCheckIntervalMs = 600_000L // 10 minutes instead of 5
    )
    println("\nCustom config with specific overrides:")
    println("- Events Queue Size: ${customCfConfig.eventsQueueSize}")
    println("- Events Flush Time: ${customCfConfig.eventsFlushTimeSeconds} seconds")
    println("- Events Flush Interval: ${customCfConfig.eventsFlushIntervalMs}ms")
    println("- SDK Settings Check Interval: ${customCfConfig.sdkSettingsCheckIntervalMs}ms")
    
    // Method 3: Using the builder pattern for more readable configuration
    val builderCfConfig = CFConfig.Builder(clientKey)
        .eventsQueueSize(200)
        .eventsFlushTimeSeconds(45)
        .eventsFlushIntervalMs(5000L)
        .sdkSettingsCheckIntervalMs(180_000L) // 3 minutes
        .networkConnectionTimeoutMs(15_000)          // 15 seconds connection timeout
        .networkReadTimeoutMs(15_000)                // 15 seconds read timeout
        .debugLoggingEnabled(true)            // Enable debug logging
        .build()
        
    println("\nBuilder pattern config:")
    println("- Events Queue Size: ${builderCfConfig.eventsQueueSize}")
    println("- Events Flush Time: ${builderCfConfig.eventsFlushTimeSeconds} seconds")
    println("- Events Flush Interval: ${builderCfConfig.eventsFlushIntervalMs}ms")
    println("- SDK Settings Check Interval: ${builderCfConfig.sdkSettingsCheckIntervalMs}ms")
    println("- Network Connection Timeout: ${builderCfConfig.networkConnectionTimeoutMs}ms")
    println("- Network Read Timeout: ${builderCfConfig.networkReadTimeoutMs}ms")
    println("- Debug Logging Enabled: ${builderCfConfig.debugLoggingEnabled}")
    
    // Use one of the configs (we'll use the builder config for this example)
    val cfConfig = builderCfConfig
    println("\nUsing config with dimension ID: ${cfConfig.dimensionId}")

    val cfUser =
            CFUser.builder("user123")
                    .makeAnonymous(false)
                    .withStringProperty("name", "john")
                    .build()

    val cfClient = CFClient.init(cfConfig, cfUser)
    
    // Example of updating user properties with type-specific methods
    cfClient.addStringProperty("email", "john.doe@example.com")
    cfClient.addNumberProperty("age", 30)
    cfClient.addBooleanProperty("premium_user", true)
    
    // ======= FEATURE FLAG RETRIEVAL WITH OPTIONAL CALLBACKS =======
    
    // Method 1: Traditional style (no callback)
    val stringValue = cfClient.getString("string-flag", "default-value")
    println("Retrieved string flag: $stringValue")
    
    // Method 2: Using the callback parameter with lambda
    cfClient.getString("string-flag", "default-value") { value ->
        println("Retrieved string flag via callback: $value")
    }
    
    // Method 3: Mixed usage - get the value and use a callback
    val boolValue = cfClient.getBoolean("premium-feature", false) { enabled ->
        if (enabled) {
            println("Premium feature is enabled!")
        } else {
            println("Premium feature is disabled")
        }
    }
    println("Boolean value stored in variable: $boolValue")
    
    // Method 4: Pass null explicitly to skip callback
    val numberValue = cfClient.getNumber("retry-count", 3, null)
    println("Number value without callback: $numberValue")
    
    // Method 5: Using a pre-defined function as callback
    val processConfig: (Map<String, Any>) -> Unit = { config ->
        println("Processing config: $config")
        val theme = config["theme"] as? String ?: "light"
        println("Using theme: $theme")
    }
    cfClient.getJson("app-config", mapOf("theme" to "light"), processConfig)
    
    // ======= CONTINUOUS LISTENERS FOR UPDATES =======
    
    // Register a listener for continuous updates to a string flag
    val stringListener: (String) -> Unit = { newValue ->
        println("String flag updated: $newValue")
    }
    cfClient.addConfigListener<String>("string-flag", stringListener)
    
    // Get initial values (both with and without callback)
    val value = cfClient.getString("shoaib-1", "shoaib-default")
    cfClient.getString("shoaib-2", "another-default") { value ->
        println("Flag 2 value: $value")
    }
    
    println("Initial flag value: $value")
    
    // Track an event
    cfClient.trackEvent("s-1", mapOf("a" to "b"))
    
    // Keep the application running to receive updates
    println("Press Enter to exit...")
    readLine()
    
    // Clean up listeners when done
    cfClient.removeConfigListener("string-flag", stringListener)
}
