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
} 