package customfit.ai.kotlinclient.serialization

import com.fasterxml.jackson.core.JsonGenerator
import com.fasterxml.jackson.databind.JsonSerializer
import com.fasterxml.jackson.databind.SerializerProvider
import java.io.IOException
import java.time.Instant

class CustomDateSerializer : JsonSerializer<Instant>() {
    @Throws(IOException::class)
    override fun serialize(value: Instant?, gen: JsonGenerator?, serializers: SerializerProvider?) {
        if (value != null && gen != null) {
            gen.writeString(value.toString())
        } else if (gen != null) {
            gen.writeNull()
        }
    }
}
