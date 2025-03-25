package customfit.ai.kotlinclient

import com.fasterxml.jackson.core.JsonGenerator
import com.fasterxml.jackson.databind.JsonSerializer
import com.fasterxml.jackson.databind.SerializerProvider
import org.joda.time.DateTime
import java.io.IOException

class CustomDateSerializer : JsonSerializer<DateTime>() {
    @Throws(IOException::class)
    override fun serialize(value: DateTime, gen: JsonGenerator, serializers: SerializerProvider) {
        gen.writeString(value.toString("yyyy-MM-dd'T'HH:mm:ss.SSSZ")) // Format DateTime as string
    }
}
