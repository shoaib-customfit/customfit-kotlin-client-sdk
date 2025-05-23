package customfit.ai.kotlinclient.serialization

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import customfit.ai.kotlinclient.logging.Timber
import java.io.IOException
import java.time.Instant
import java.time.format.DateTimeParseException

class CustomDateDeserializer : JsonDeserializer<Instant>() {
    @Throws(IOException::class)
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext?): Instant {
        val dateString = p.text
        try {
            return Instant.parse(dateString)
        } catch (e: DateTimeParseException) {
            Timber.e(e, "Failed to parse date string: '$dateString'. Using current time as fallback.")
            return Instant.now()
        } catch (e: Exception) {
            Timber.e(e, "Unexpected error deserializing date: '$dateString'. Using current time as fallback.")
            return Instant.now()
        }
    }
}
