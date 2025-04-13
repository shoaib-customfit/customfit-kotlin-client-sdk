package customfit.ai

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import timber.log.Timber

fun main() {
    Timber.plant(Timber.DebugTree())
    val clientKey =
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek"

    // Provide a way to add attributes in config
    // One screen to another screen how things work ?
    // Make queue size 1
    // Can we do a builder of event properties like User properties
    // at any point user properties can be updated
    // client.getString("shoaib-1", "shoaib-default") should support callback methods
    // Add timer and test if values change

    val config = CFConfig(clientKey)

    val user =
            CFUser.builder("user123")
                    .makeAnonymous(false)
                    .withStringProperty("name", "john")
                    .build()

    println("Dimension ID - : ${config.dimensionId}")

    val client = CFClient.init(config, user)

    val value = client.getString("shoaib-1", "shoaib-default")
    println("Flag value: $value")

    val value_2 = client.getString("shoaib-1", "shoaib-default")

    println("Flag value: $value_2")

    client.trackEvent("s-1", mapOf("a" to "b"))
}
