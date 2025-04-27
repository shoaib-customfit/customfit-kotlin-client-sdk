package customfit.ai.kotlinclient.analytics.event

import customfit.ai.kotlinclient.core.model.CFUser

data class RegisterEvent(
        val events: List<EventData>,
        val user: CFUser,
)
