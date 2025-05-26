package com.example.myapplication

import android.util.Log
import customfit.ai.kotlinclient.client.CFClient

/**
 * Helper class for CFClient usage examples using the singleton pattern
 * 
 * Note: With the enhanced SDK, most listener management is now handled automatically.
 * This helper provides convenience methods for common operations.
 */
object CFHelper {
    
    /**
     * Get the CFClient singleton instance safely
     */
    private fun getCFClient(): CFClient? {
        return if (CFClient.isInitialized()) {
            CFClient.getInstance()
        } else {
            Log.w("CF_SDK", "CFClient singleton not initialized yet")
            null
        }
    }
    
    /**
     * Check if the CFClient singleton is initialized
     */
    fun isInitialized(): Boolean {
        return CFClient.isInitialized()
    }
    
    /**
     * Get the CFClient instance for direct access to instance methods
     */
    fun getCFClientInstance(): CFClient? {
        return getCFClient()
    }
    
    /**
     * Get a string configuration value with a default fallback
     */
    fun getString(key: String, defaultValue: String): String {
        return try {
            val client = getCFClient()
            if (client != null) {
                client.getString(key, defaultValue)
            } else {
                Log.d("CF_SDK", "CFClient not available, returning default value for $key")
                defaultValue
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Error getting string value for $key: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Get a boolean feature flag value with a default fallback
     */
    fun getFeatureFlag(key: String, defaultValue: Boolean): Boolean {
        return try {
            val client = getCFClient()
            if (client != null) {
                client.getBoolean(key, defaultValue)
            } else {
                Log.d("CF_SDK", "CFClient not available, returning default value for $key")
                defaultValue
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Error getting boolean value for $key: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Get a number configuration value with a default fallback
     */
    fun getNumber(key: String, defaultValue: Number): Number {
        return try {
            val client = getCFClient()
            if (client != null) {
                client.getNumber(key, defaultValue)
            } else {
                Log.d("CF_SDK", "CFClient not available, returning default value for $key")
                defaultValue
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Error getting number value for $key: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Record an event with properties
     */
    fun recordEventWithProperties(eventName: String, properties: Map<String, Any>) {
        try {
            val client = getCFClient()
            if (client != null) {
                client.trackEvent(eventName, properties)
                Log.d("CF_SDK", "Recorded event: $eventName")
            } else {
                Log.w("CF_SDK", "Cannot record event: CFClient not initialized")
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Error recording event $eventName: ${e.message}")
        }
    }
} 