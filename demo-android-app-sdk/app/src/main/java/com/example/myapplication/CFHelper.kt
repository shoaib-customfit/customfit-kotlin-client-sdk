package com.example.myapplication

import android.content.Context
import android.util.Log

/**
 * Helper class for CF Client usage examples
 */
object CFHelper {
    
    /**
     * Record a simple event
     */
    fun recordSimpleEvent(eventName: String) {
        try {
            MyApplication.cfClient.trackEvent(eventName)
            Log.d("CustomFit_SDK", "Recorded event: $eventName")
        } catch (e: Exception) {
            Log.e("CustomFit_SDK", "Failed to record event: ${e.message}")
        }
    }
    
    /**
     * Record an event with properties
     */
    fun recordEventWithProperties(eventName: String, properties: Map<String, Any>) {
        try {
            MyApplication.cfClient.trackEvent(eventName, properties)
            Log.d("CustomFit_SDK", "Recorded event: $eventName with properties: $properties")
        } catch (e: Exception) {
            Log.e("CustomFit_SDK", "Failed to record event: ${e.message}")
        }
    }
    
    /**
     * Example of using feature flags
     */
    fun getFeatureFlag(flagName: String, defaultValue: Boolean): Boolean {
        return try {
            val value = MyApplication.cfClient.getBoolean(flagName, defaultValue)
            Log.d("CustomFit_SDK", "Feature flag $flagName: $value")
            value
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
            val value = MyApplication.cfClient.getString(key, defaultValue)
            Log.d("CF_SDK", "Config value $key: $value")
            value
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to get string config: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * Add a config listener that will be triggered when the config value changes
     */
    inline fun <reified T : Any> addConfigListener(key: String, noinline listener: (T) -> Unit) {
        try {
            MyApplication.cfClient.addConfigListener<T>(key, listener)
            Log.d("CF_SDK", "Added config listener for $key")
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to add config listener: ${e.message}")
        }
    }
    
    // Store listeners to be able to remove them later
    private val listeners = mutableMapOf<String, Any>()
    
    /**
     * Remove config listeners for a specific key (without requiring the original listener)
     */
    fun removeConfigListenersByKey(key: String) {
        try {
            // This is a simplified approach; in real implementation, use proper listener management
            Log.d("CF_SDK", "Attempting to remove config listeners for $key")
        } catch (e: Exception) {
            Log.e("CF_SDK", "Failed to remove config listeners: ${e.message}")
        }
    }
} 