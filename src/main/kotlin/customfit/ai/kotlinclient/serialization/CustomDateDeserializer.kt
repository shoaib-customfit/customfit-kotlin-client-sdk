package customfit.ai.kotlinclient.serialization

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import java.io.IOException
import java.time.Instant

class CustomDateDeserializer : JsonDeserializer<Instant>() {
    @Throws(IOException::class)
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext?): Instant {
        val dateString = p.text
        return Instant.parse(dateString)
    }
}
