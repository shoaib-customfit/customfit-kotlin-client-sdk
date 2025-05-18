package com.example.myapplication

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private lateinit var myHeroText: TextView
    private var enhancedToastEnabled = false
    
    private val heroTextListener: (String) -> Unit = { newValue ->
        // Update the UI on the main thread
        runOnUiThread {
            myHeroText.text = newValue
            Toast.makeText(
                this,
                "Configuration updated: hero_text = $newValue",
                Toast.LENGTH_SHORT
            ).show()
        }
    }
    
    private val enhancedToastListener: (Boolean) -> Unit = { isEnabled ->
        runOnUiThread {
            enhancedToastEnabled = isEnabled
            Toast.makeText(
                this,
                "Toast mode updated: ${if(isEnabled) "Enhanced" else "Standard"}",
                Toast.LENGTH_SHORT
            ).show()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        val showToastButton = findViewById<Button>(R.id.showToastButton)
        myHeroText = findViewById<TextView>(R.id.textView)
        
        // Get a string config from CF and set it as text
        updateHeroText()
        
        // Update initial toast mode
        updateToastMode()
        
        // Add config listeners to automatically update when values change
        setupConfigListeners()
        
        val secondScreenButton = findViewById<Button>(R.id.secondScreenButton)
        
        // Add a refresh button to manually check for config updates
        val refreshButton = findViewById<Button>(R.id.refreshButton)
        refreshButton?.setOnClickListener {
            // Force a refresh of the config
            CFHelper.recordEventWithProperties("kotlin_config_manual_refresh", 
                mapOf(
                    "config_key" to "hero_text", 
                    "refresh_source" to "user_action", 
                    "screen" to "main",
                    "platform" to "kotlin"
                )
            )
            Toast.makeText(this, "Refreshing configuration...", Toast.LENGTH_SHORT).show()
            updateHeroText()
            updateToastMode()
        }
        
        showToastButton.setOnClickListener {
            // Record button click event with more specific tracking
            CFHelper.recordEventWithProperties("kotlin_toast_button_interaction", 
                mapOf(
                    "action" to "click", 
                    "feature" to "toast_message",
                    "platform" to "kotlin"
                )
            )
            
            if (enhancedToastEnabled) {
                Toast.makeText(this, "Enhanced toast feature enabled!", Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "Button clicked!", Toast.LENGTH_SHORT).show()
            }
        }
        
        secondScreenButton.setOnClickListener {
            // Record navigation event with more specific tracking
            CFHelper.recordEventWithProperties("kotlin_screen_navigation", 
                mapOf(
                    "from" to "main_screen", 
                    "to" to "second_screen", 
                    "user_flow" to "primary_navigation",
                    "platform" to "kotlin"
                )
            )
            val intent = Intent(this, SecondActivity::class.java)
            startActivity(intent)
        }
    }
    
    private fun updateHeroText() {
        val heroText = CFHelper.getString("hero_text", "CF DEMO")
        myHeroText.text = heroText
    }
    
    private fun updateToastMode() {
        enhancedToastEnabled = CFHelper.getFeatureFlag("enhanced_toast", false)
    }
    
    private fun setupConfigListeners() {
        // Using the CFHelper to add the listeners
        CFHelper.addConfigListener<String>("hero_text", heroTextListener)
        CFHelper.addConfigListener<Boolean>("enhanced_toast", enhancedToastListener)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Remove listeners when the activity is destroyed
        CFHelper.removeConfigListenersByKey("hero_text")
        CFHelper.removeConfigListenersByKey("enhanced_toast")
    }
}