package customfit.ai

import customfit.ai.kotlinclient.CFClient
import customfit.ai.kotlinclient.CFConfig
import customfit.ai.kotlinclient.CFUser

fun main() {
    // Create a CFConfig object with the client key
    val config = CFConfig("my-secret-token")
    
    // Create a CFUser object with necessary attributes
    val user = CFUser.builder("user123")
        .makeAnonymous(false)
        .withStringProperty("name", "John Doe")
        .build()

    // Initialize the CFClient with the config and user
    val client = CFClient.init(config, user)

    // Call the getFlagValue method (You may need to define it)
    val value = client.getString("some-key", "my-default")
    println("Flag value: $value")
}
