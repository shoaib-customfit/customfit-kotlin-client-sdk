package com.example.myapplication

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

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
    
    private val enhancedToastListener: (Boolean) -> Unit = { newValue ->
        // Update the enhanced toast setting on the main thread
        runOnUiThread {
            enhancedToastEnabled = newValue
            Toast.makeText(
                this,
                "Configuration updated: enhanced_toast = $newValue",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Initialize views
        val showToastButton = findViewById<Button>(R.id.showToastButton)
        myHeroText = findViewById<TextView>(R.id.textView)
        
        // Set initial default values (will be updated by listeners when server values arrive)
        myHeroText.text = "CF DEMO"
        enhancedToastEnabled = false
        
        // Set up config listeners after a short delay to ensure CFClient is initialized
        setupConfigListeners()
        
        // Set up button listeners
        showToastButton.setOnClickListener {
            showToast()
        }
        
        val secondScreenButton = findViewById<Button>(R.id.secondScreenButton)
        secondScreenButton.setOnClickListener {
            val intent = Intent(this, SecondActivity::class.java)
            startActivity(intent)
        }
    }
    
    private fun setupConfigListeners() {
        // Use lifecycleScope to wait for CFClient initialization
        lifecycleScope.launch {
            // Wait for CFClient to be initialized
            var attempts = 0
            while (!CFHelper.isInitialized() && attempts < 50) { // Max 5 seconds
                delay(100)
                attempts++
            }
            
            if (CFHelper.isInitialized()) {
                // CFClient is ready, register listeners using the existing instance methods
                val client = CFHelper.getCFClientInstance()
                client?.let {
                    it.addConfigListener<String>("hero_text", heroTextListener)
                    it.addConfigListener<Boolean>("enhanced_toast", enhancedToastListener)
                    
                    // Update UI with current values
                    runOnUiThread {
                        myHeroText.text = CFHelper.getString("hero_text", "CF DEMO")
                        enhancedToastEnabled = CFHelper.getFeatureFlag("enhanced_toast", false)
                    }
                }
            } else {
                // Fallback: CFClient not ready, show message
                runOnUiThread {
                    Toast.makeText(this@MainActivity, "Configuration service not available", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun showToast() {
        val message = if (enhancedToastEnabled) {
            "🎉 Enhanced Toast is ON! 🎉"
        } else {
            "Regular toast message"
        }
        
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}