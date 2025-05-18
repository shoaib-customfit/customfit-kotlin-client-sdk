package com.example.myapplication

import android.app.Application
import android.util.Log
import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser

class MyApplication : Application() {
    
    companion object {
        lateinit var cfClient: CFClient
            private set
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize CF Client
        try {
            // Client key from Main.kt
            val clientKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"
            
            val config = CFConfig.Builder(clientKey)
                .sdkSettingsCheckIntervalMs(2_000L) // 60 seconds for settings check
                .summariesFlushTimeSeconds(30)       // 30 seconds for summaries flush time
                .summariesFlushIntervalMs(30_000L)   // 30 seconds for summaries flush interval
                .eventsFlushTimeSeconds(30)          // 30 seconds for events flush time
                .eventsFlushIntervalMs(30_000L)      // 30 seconds for events flush interval
                .debugLoggingEnabled(true)
                .build()
                
            // Create a user
            val user = CFUser.builder("android_user_" + System.currentTimeMillis())
                .makeAnonymous(true)
                .build()
            
            // Initialize the client
            cfClient = CFClient.init(config, user)
            
            Log.d("CF_SDK", "CF Client initialized successfully")
            
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to initialize CF Client: ${e.message}")
            e.printStackTrace()
        }
    }
} 