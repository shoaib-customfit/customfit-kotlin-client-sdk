package customfit.ai.kotlinclient.core.model

import kotlinx.serialization.Serializable

/**
 * Simplified SdkSettings model with only essential flags
 * Only includes fields that are needed for core SDK functionality
 */
@Serializable
data class SdkSettings(
    val cf_account_enabled: Boolean = true,
    val cf_skip_sdk: Boolean = false
)
