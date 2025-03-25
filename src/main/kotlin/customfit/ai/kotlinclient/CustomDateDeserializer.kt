package customfit.ai.kotlinclient

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import org.joda.time.DateTime
import java.io.IOException

class CustomDateDeserializer : JsonDeserializer<DateTime>() {
    @Throws(IOException::class)
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext?): DateTime {
        val dateString = p.text
        return DateTime.parse(dateString) // Parse date string to DateTime
    }
}
