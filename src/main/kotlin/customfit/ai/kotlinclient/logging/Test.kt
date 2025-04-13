package customfit.ai.kotlinclient.logging

/**
 * Simple test program to verify Timber logging implementation
 */
fun main() {
    // Test basic logging
    Timber.d("This is a debug message")
    Timber.i("This is an info message")
    Timber.w("This is a warning message")
    Timber.e("This is an error message")
    
    // Test logging with exceptions
    try {
        throw RuntimeException("Test exception")
    } catch (e: Exception) {
        Timber.e(e, "Caught exception")
    }
    
    // Test logging with lambdas
    Timber.warn { "This is a warning from a lambda" }
    
    println("Logging test completed. Check your logs!")
} 