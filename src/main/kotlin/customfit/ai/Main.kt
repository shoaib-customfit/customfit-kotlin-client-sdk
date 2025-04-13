package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import java.lang.Thread
import java.lang.reflect.Field
import java.util.Date
import java.text.SimpleDateFormat

fun main(args: Array<String>) {
    val timestamp = { SimpleDateFormat("HH:mm:ss.SSS").format(Date()) }
    
    println("[${timestamp()}] Starting CustomFit SDK Test")
    
    // Configure with a short settings check interval
    val clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
    
    val config = CFConfig.Builder(clientKey)
        .sdkSettingsCheckIntervalMs(5_000L) // 5 seconds for quick testing
        .debugLoggingEnabled(true)
        .build()
        
    println("\n[${timestamp()}] Test config for SDK settings check:")
    println("[${timestamp()}] - SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms")
    println("[${timestamp()}] - Debug Logging Enabled: ${config.debugLoggingEnabled}")
    
    // Create a user
    val user = CFUser.builder("user123")
            .makeAnonymous(false)
            .withStringProperty("name", "john")
            .build()

    println("\n[${timestamp()}] Initializing CFClient with test config...")
    val cfClient = CFClient.init(config, user)
    
    // Test a feature flag
    val initialValue = cfClient.getString("shoaib-1", "default-value")
    println("[${timestamp()}] Initial value of shoaib-1: $initialValue")
    
    // Register a listener to detect changes in real-time
    val flagListener: (String) -> Unit = { newValue ->
        println("[${timestamp()}] CHANGE DETECTED: shoaib-1 updated to: $newValue")
    }
    cfClient.addConfigListener<String>("shoaib-1", flagListener)
    
    // Run normal check cycles
    println("\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---")
    for (i in 1..3) {
        println("\n[${timestamp()}] Check cycle $i...")
        
        // Wait for next check
        println("[${timestamp()}] Waiting for SDK settings check...")
        Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)
        
        // Get current value
        val currentValue = cfClient.getString("shoaib-1", "default-value")
        println("[${timestamp()}] Value after check cycle $i: $currentValue")
    }
    
    // Force a metadata refresh using reflection
    println("\n[${timestamp()}] --- PHASE 2: Forcing Metadata Refresh ---")
    println("[${timestamp()}] Attempting to reset previousLastModified field using reflection...")
    
    try {
        val previousLastModifiedField = CFClient::class.java.getDeclaredField("previousLastModified")
        previousLastModifiedField.isAccessible = true
        val previousValue = previousLastModifiedField.get(cfClient)
        println("[${timestamp()}] Current previousLastModified value: $previousValue")
        
        // Set to null to force a refresh on next check
        previousLastModifiedField.set(cfClient, null)
        println("[${timestamp()}] Reset previousLastModified to null")
        
        // Wait for the next check cycle
        println("[${timestamp()}] Waiting for forced refresh check cycle...")
        Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)
        
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
        
        // Wait for next check
        println("[${timestamp()}] Waiting for SDK settings check...")
        Thread.sleep(config.sdkSettingsCheckIntervalMs + 1000)
        
        // Get current value
        val currentValue = cfClient.getString("shoaib-1", "default-value")
        println("[${timestamp()}] Value after check cycle $i: $currentValue")
    }
    
    println("\n[${timestamp()}] Test completed after 5 check cycles")
    println("[${timestamp()}] Test complete. Press Enter to exit...")
    readLine()
}
