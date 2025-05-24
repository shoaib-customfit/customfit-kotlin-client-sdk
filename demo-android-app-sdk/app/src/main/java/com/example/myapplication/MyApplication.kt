package com.example.myapplication

import android.app.Application
import android.os.StrictMode
import android.util.Log
import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.SupervisorJob
import java.net.InetAddress

class MyApplication : Application() {
    
    companion object {
        /**
         * Get the CFClient singleton instance
         * Returns null if not initialized yet
         */
        fun getCFClient(): CFClient? = CFClient.getInstance()
        
        /**
         * Check if the CFClient is initialized
         */
        fun isCFClientInitialized(): Boolean = CFClient.isInitialized()
    }
    
    // Application scope for coroutines
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()
        
        // Enable StrictMode to allow network on main thread (only for debugging)
        val policy = StrictMode.ThreadPolicy.Builder()
            .permitAll()
            .build()
        StrictMode.setThreadPolicy(policy)
        
        // Test connectivity
        testConnectivity()
        
        // Initialize CF Client using the new singleton pattern
        initializeCFClient()
    }
    
    private fun testConnectivity() {
        try {
            Thread {
                Log.d("CF_SDK", "Testing DNS resolution for sdk.customfit.ai...")
                try {
                    val address = InetAddress.getByName("sdk.customfit.ai")
                    Log.d("CF_SDK", "DNS resolution successful: ${address.hostAddress}")
                } catch (e: Exception) {
                    Log.e("CF_SDK", "DNS resolution failed: ${e.message}")
                }
                
                // Test Google as reference
                try {
                    val googleAddress = InetAddress.getByName("www.google.com")
                    Log.d("CF_SDK", "Google DNS resolution: ${googleAddress.hostAddress}")
                } catch (e: Exception) {
                    Log.e("CF_SDK", "Google DNS resolution failed: ${e.message}")
                }
            }.start()
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to test connectivity: ${e.message}")
        }
    }
    
    private fun initializeCFClient() {
        applicationScope.launch {
            try {
                // Client key from Main.kt
                val clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
                
                val config = CFConfig.Builder(clientKey)
                    .sdkSettingsCheckIntervalMs(2_000L)
                    .backgroundPollingIntervalMs(2_000L)
                    .reducedPollingIntervalMs(2_000L) // 2 seconds for settings check
                    .summariesFlushTimeSeconds(2)       // 2 seconds for summaries flush time
                    .summariesFlushIntervalMs(2_000L)   // 2 seconds for summaries flush interval
                    .eventsFlushTimeSeconds(30)          // 30 seconds for events flush time
                    .eventsFlushIntervalMs(30_000L)      // 30 seconds for events flush interval
                    .debugLoggingEnabled(true)
                    .networkConnectionTimeoutMs(30_000)  // 30 seconds connection timeout
                    .networkReadTimeoutMs(30_000)        // 30 seconds read timeout
                    .build()
                    
                // Create a user
                val user = CFUser.builder("android_user_" + System.currentTimeMillis())
                    .makeAnonymous(true)
                    .withStringProperty("platform", "android")
                    .withStringProperty("app_version", "1.0.0")
                    .build()
                
                // Initialize the client using the new singleton pattern
                val cfClient = CFClient.initialize(config, user)
                
                Log.d("CF_SDK", "CFClient singleton initialized successfully")
                
            } catch (e: Exception) {
                Log.e("CF_SDK", "Failed to initialize CFClient singleton: ${e.message}")
                e.printStackTrace()
            }
        }
    }
} 