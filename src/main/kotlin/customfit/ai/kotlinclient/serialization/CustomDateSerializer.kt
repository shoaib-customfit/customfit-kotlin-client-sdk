package customfit.ai.kotlinclient.serialization

import com.fasterxml.jackson.core.JsonGenerator
import com.fasterxml.jackson.databind.JsonSerializer
import com.fasterxml.jackson.databind.SerializerProvider
import customfit.ai.kotlinclient.logging.Timber
import java.io.IOException
import java.time.Instant

class CustomDateSerializer : JsonSerializer<Instant>() {
    @Throws(IOException::class)
    override fun serialize(value: Instant?, gen: JsonGenerator?, serializers: SerializerProvider?) {
        try {
            if (value != null && gen != null) {
                gen.writeString(value.toString())
                return
            }
            
            if (gen == null) {
                Timber.e("Null JsonGenerator provided to CustomDateSerializer")
                return
            }
            
            if (value == null) {
                Timber.w("Null timestamp value encountered during serialization")
                gen.writeNull()
            }
        } catch (e: IOException) {
            Timber.e(e, "IO error during date serialization")
            throw e // Rethrow IOException as it's in the method signature
        } catch (e: Exception) {
            Timber.e(e, "Unexpected error serializing date. Using current time as fallback.")
            if (gen != null) {
                try {
                    gen.writeString(Instant.now().toString())
                } catch (innerEx: Exception) {
                    Timber.e(innerEx, "Failed to write fallback date")
                    gen.writeNull()
                }
            }
        }
    }
}
