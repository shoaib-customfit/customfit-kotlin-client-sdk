package customfit.ai.kotlinclient.events


import customfit.ai.kotlinclient.core.CFUser

data class RegisterEvent(
        val events: List<EventData>,
        val user: CFUser,
)
