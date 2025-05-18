package com.example.myapplication

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        val showToastButton = findViewById<Button>(R.id.showToastButton)
        val myHeroText = findViewById<TextView>(R.id.textView)
        
        // Get a string config from CF and set it as text
        val heroText = CFHelper.getString("hero_text", "CF DEMO")
        myHeroText.setText(heroText)
        
        val secondScreenButton = findViewById<Button>(R.id.secondScreenButton)
        
        // Use a feature flag to conditionally show a toast
        val shouldShowEnhancedToast = CFHelper.getFeatureFlag("enhanced_toast", false)
        
        showToastButton.setOnClickListener {
            // Record button click event
            CFHelper.recordEventWithProperties("button_clicked", mapOf("button" to "showToast"))
            
            if (shouldShowEnhancedToast) {
                Toast.makeText(this, "Enhanced toast feature enabled!", Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "Button clicked!", Toast.LENGTH_SHORT).show()
            }
        }
        
        secondScreenButton.setOnClickListener {
            // Record navigation event
            CFHelper.recordEventWithProperties("navigation", mapOf("destination" to "SecondActivity"))
            val intent = Intent(this, SecondActivity::class.java)
            startActivity(intent)
        }
    }
}