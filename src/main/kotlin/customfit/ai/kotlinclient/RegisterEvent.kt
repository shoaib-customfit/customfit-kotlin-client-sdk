package customfit.ai.kotlinclient

data class RegisterEvent(
        val events: List<EventData>,
        val user: CFUser,
)
