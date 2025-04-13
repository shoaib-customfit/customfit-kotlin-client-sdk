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

    // Provide a way to add attributes in config
    // One screen to another screen how things work ?
    // Make queue size 1
    // Can we do a builder of event properties like User properties
    // at any point user properties can be updated
    // client.getString("shoaib-1", "shoaib-default") should support callback methods
    // Add timer and test if values change

    val config = CFConfig(clientKey)

    val user =
            CFUser.builder("user123")
                    .makeAnonymous(false)
                    .withStringProperty("name", "john")
                    .build()

    println("Dimension ID - : ${config.dimensionId}")

    val client = CFClient.init(config, user)
    
    // Example of updating user properties with type-specific methods
    client.addStringProperty("email", "john.doe@example.com")
    client.addNumberProperty("age", 30)
    client.addBooleanProperty("premium_user", true)
    
    // ======= FEATURE FLAG RETRIEVAL WITH OPTIONAL CALLBACKS =======
    
    // Method 1: Traditional style (no callback)
    val stringValue = client.getString("string-flag", "default-value")
    println("Retrieved string flag: $stringValue")
    
    // Method 2: Using the callback parameter with lambda
    client.getString("string-flag", "default-value") { value ->
        println("Retrieved string flag via callback: $value")
    }
    
    // Method 3: Mixed usage - get the value and use a callback
    val boolValue = client.getBoolean("premium-feature", false) { enabled ->
        if (enabled) {
            println("Premium feature is enabled!")
        } else {
            println("Premium feature is disabled")
        }
    }
    println("Boolean value stored in variable: $boolValue")
    
    // Method 4: Pass null explicitly to skip callback
    val numberValue = client.getNumber("retry-count", 3, null)
    println("Number value without callback: $numberValue")
    
    // Method 5: Using a pre-defined function as callback
    val processConfig: (Map<String, Any>) -> Unit = { config ->
        println("Processing config: $config")
        val theme = config["theme"] as? String ?: "light"
        println("Using theme: $theme")
    }
    client.getJson("app-config", mapOf("theme" to "light"), processConfig)
    
    // ======= CONTINUOUS LISTENERS FOR UPDATES =======
    
    // Register a listener for continuous updates to a string flag
    val stringListener: (String) -> Unit = { newValue ->
        println("String flag updated: $newValue")
    }
    client.addConfigListener<String>("string-flag", stringListener)
    
    // Get initial values (both with and without callback)
    val value = client.getString("shoaib-1", "shoaib-default")
    client.getString("shoaib-2", "another-default") { value ->
        println("Flag 2 value: $value")
    }
    
    println("Initial flag value: $value")
    
    // Track an event
    client.trackEvent("s-1", mapOf("a" to "b"))
    
    // Keep the application running to receive updates
    println("Press Enter to exit...")
    readLine()
    
    // Clean up listeners when done
    client.removeConfigListener("string-flag", stringListener)
}
