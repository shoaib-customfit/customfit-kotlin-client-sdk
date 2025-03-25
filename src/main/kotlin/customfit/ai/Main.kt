package customfit.ai

import customfit.ai.kotlinclient.CFClient
import customfit.ai.kotlinclient.CFConfig
import customfit.ai.kotlinclient.CFUser

fun main() {
    val key =
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTIyM2Q0ZjAtNmRjYi0xMWVlLWI4YmMtOWI3N2RjOTAzN2Y4IiwicHJvamVjdF9pZCI6ImE5YTExOTQwLTZkY2ItMTFlZS1iOGJjLTliNzdkYzkwMzdmOCIsImVudmlyb25tZW50X2lkIjoiYTlhMWRjOTAtNmRjYi0xMWVlLWI4YmMtOWI3N2RjOTAzN2Y4IiwiZGltZW5zaW9uX2lkIjoiYTlhNWFkMjAtNmRjYi0xMWVlLWI4YmMtOWI3N2RjOTAzN2Y4IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImE5YjkwZTEwLTZkY2ItMTFlZS1iOGJjLTliNzdkYzkwMzdmOCIsImlzcyI6ImZBNGJHSVFTemt6QjRUUHdEMmpMdDNhNWJXdXV5RmpZIiwiaWF0IjoxNjk3NjQzMTk4fQ._Cfdy1LOFscC2NAInA7vvX41QEVN-64UZYDO7ngKw44"
    val config = CFConfig(key)

    val user =
            CFUser.builder("user123")
                    .makeAnonymous(false)
                    .withStringProperty("name", "John Doe")
                    .build()

    val client = CFClient.init(config, user)

    val value = client.getString("some-key", "my-default")
    println("Flag value: $value")
}
