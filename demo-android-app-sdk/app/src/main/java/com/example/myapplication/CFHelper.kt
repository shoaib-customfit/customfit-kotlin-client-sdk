package com.example.myapplication

import android.util.Log
import customfit.ai.kotlinclient.client.CFClient

/**
 * Helper class for CFClient usage examples using the singleton pattern
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
     * Record a simple event
     */
    fun recordSimpleEvent(eventName: String) {
        try {
            val client = getCFClient()
            if (client != null) {
                client.trackEvent(eventName)
                Log.d("CustomFit_SDK", "Recorded event: $eventName")
            } else {
                Log.w("CustomFit_SDK", "Cannot record event: CFClient not initialized")
            }
        } catch (e: Exception) {
            Log.e("CustomFit_SDK", "Failed to record event: ${e.message}")
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
                Log.d("CustomFit_SDK", "Recorded event: $eventName with properties: $properties")
            } else {
                Log.w("CustomFit_SDK", "Cannot record event: CFClient not initialized")
            }
        } catch (e: Exception) {
            Log.e("CustomFit_SDK", "Failed to record event: ${e.message}")
        }
    }
    
    /**
     * Example of using feature flags
     */
    fun getFeatureFlag(flagName: String, defaultValue: Boolean): Boolean {
        return try {
            val client = getCFClient()
            if (client != null) {
                val value = client.getBoolean(flagName, defaultValue)
                Log.d("CustomFit_SDK", "Feature flag $flagName: $value")
                value
            } else {
                Log.w("CustomFit_SDK", "Cannot get feature flag: CFClient not initialized, returning default")
                defaultValue
            }
        } catch (e: Exception) {
            Log.e("CustomFit_SDK", "Failed to get feature flag: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Get a string configuration value
     */
    fun getString(key: String, defaultValue: String): String {
        return try {
            val client = getCFClient()
            if (client != null) {
                val value = client.getString(key, defaultValue)
                Log.d("CF_SDK", "Config value $key: $value")
                value
            } else {
                Log.w("CF_SDK", "Cannot get string config: CFClient not initialized, returning default")
                defaultValue
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to get string config: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Add a config listener that will be triggered when the config value changes
     */
    fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit) {
        try {
            val client = getCFClient()
            if (client != null) {
                client.addConfigListener<T>(key, listener)
                Log.d("CF_SDK", "Added config listener for $key")
                
                // Store the listener for potential cleanup
                listeners[key] = listener
            } else {
                Log.w("CF_SDK", "Cannot add config listener: CFClient not initialized")
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to add config listener: ${e.message}")
        }
    }
    
    // Store listeners to be able to remove them later
    private val listeners = mutableMapOf<String, Any>()
    
    /**
     * Remove config listeners for a specific key
     */
    fun removeConfigListenersByKey(key: String) {
        try {
            val client = getCFClient()
            if (client != null) {
                // Get the stored listener for this key
                val listener = listeners[key]
                if (listener != null) {
                    // Clear the listeners for this key using the SDK's method
                    client.clearConfigListeners(key)
                    listeners.remove(key)
                    Log.d("CF_SDK", "Removed config listeners for $key")
                } else {
                    Log.d("CF_SDK", "No listeners found for key $key")
                }
            } else {
                Log.w("CF_SDK", "Cannot remove config listeners: CFClient not initialized")
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to remove config listeners: ${e.message}")
        }
    }
    
    /**
     * Check if the CFClient singleton is initialized
     */
    fun isInitialized(): Boolean {
        return CFClient.isInitialized()
    }
    
    /**
     * Get all feature flags (if available)
     */
    fun getAllFlags(): Map<String, Any> {
        return try {
            val client = getCFClient()
            if (client != null) {
                val flags = client.getAllFlags()
                Log.d("CF_SDK", "Retrieved ${flags.size} feature flags")
                flags
            } else {
                Log.w("CF_SDK", "Cannot get all flags: CFClient not initialized")
                emptyMap()
            }
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to get all flags: ${e.message}")
            emptyMap()
        }
    }
} 