package com.example.myapplication

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class SecondActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_second)
        
        // Record page view event
        CFHelper.recordEventWithProperties("page_view", mapOf("page" to "SecondActivity"))
    }
} 