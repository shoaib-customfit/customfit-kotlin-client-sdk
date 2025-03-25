package customfit.ai.kotlinclient

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import java.io.IOException
import org.joda.time.DateTime

class CustomDateDeserializer : JsonDeserializer<DateTime>() {
    @Throws(IOException::class)
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext?): DateTime {
        val dateString = p.text
        return DateTime.parse(dateString)
    }
}
