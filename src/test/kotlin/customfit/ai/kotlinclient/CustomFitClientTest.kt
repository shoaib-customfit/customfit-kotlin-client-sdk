package customfit.ai.kotlinclient

import kotlin.test.Test
import kotlin.test.assertEquals

class CustomFitClientTest {

    @Test
    fun testGetFlagValue() {
        val client = CustomFitClient.init("dummy-token")
        val actualValue = client.getFlagValue("my-feature", "default-val")
        // For now, we expect our dummy logic to return "mocked-value-for-my-feature"
        assertEquals("mocked-value-for-my-feature", actualValue)
    }
}
