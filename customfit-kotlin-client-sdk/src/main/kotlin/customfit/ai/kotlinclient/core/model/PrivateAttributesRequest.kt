package customfit.ai.kotlinclient.core.model

import customfit.ai.kotlinclient.serialization.MapSerializer
import kotlinx.serialization.Contextual
import kotlinx.serialization.Serializable

@Serializable
data class PrivateAttributesRequest(
    val userFields: List<String> = emptyList(),
    @Contextual
    @Serializable(with = MapSerializer::class)
    val properties: Map<String, @Contextual Any> = emptyMap()
) 