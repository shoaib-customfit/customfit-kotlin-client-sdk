package customfit.ai

fun main() {
    val client = customfit.ai.kotlinclient.CustomFitClient.init("my-secret-token")
    val value = client.getFlagValue("some-key", "my-default")
    println("Flag value: $value")
}