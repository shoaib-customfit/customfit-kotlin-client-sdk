package customfit.ai.kotlinclient

import org.joda.time.DateTime
import org.json.JSONObject

data class SdkSettings(
        val cf_key: String,
        val cf_account_enabled: Boolean,
        val cf_page_elements_path_type: String?,
        val cf_latest_sdk_version: String?,
        val cf_whitelabel_company_display_name: String?,
        val cf_domain_url: String?,
        val cf_jsevl_type: String?,
        val cf_config_reapply_timers: String?,
        val cf_ga4_setup_mode: String?,
        val cf_gtm_data_variable_name: String?,
        val cf_account_source: String?,
        val cf_event_merge_config: String?,
        val cf_dimension_id: String?,
        val cf_intelligent_code_enabled: Boolean,
        val cf_personalize_post_sdk_timeout: Boolean,
        val is_inbound: Boolean,
        val is_outbound: Boolean,
        val cfspa: Boolean,
        val cfspa_auto_detect_page_url_change: Boolean,
        val is_auto_form_capture: Boolean,
        val is_auto_email_capture: Boolean,
        val cf_is_page_update_enabled: Boolean,
        val cf_retain_text_value: Boolean,
        val cf_is_whitelabel_account: Boolean,
        val cf_skip_sdk: Boolean,
        val enable_event_analyzer: Boolean,
        val cf_skip_dfs: Boolean,
        val cf_is_ms_clarity_enabled: Boolean,
        val cf_is_hotjar_enabled: Boolean,
        val cf_is_shopify_integrated: Boolean,
        val cf_is_ga_enabled: Boolean,
        val cf_is_segment_enabled: Boolean,
        val cf_is_mixpanel_enabled: Boolean,
        val cf_is_moengage_enabled: Boolean,
        val cf_is_clevertap_enabled: Boolean,
        val cf_is_webengage_enabled: Boolean,
        val cf_is_netcore_enabled: Boolean,
        val cf_is_amplitude_enabled: Boolean,
        val cf_is_heap_enabled: Boolean,
        val cf_is_gokwik_enabled: Boolean,
        val cf_is_shopflo_enabled: Boolean,
        val cf_send_error_report: Boolean,
        val personalized_users_limit_exceeded: Boolean,
        val cf_sdk_timeout_in_seconds: Int,
        val cf_initial_delay_in_ms: Int,
        val cf_last_visited_product_url: Int,
        val blacklisted_page_paths: List<String>,
        val blacklisted_referrers: List<String>,
        val cf_subdomains: List<String>,
        val cf_configs_json: Map<String, Any>,
        val cf_active_pages: Map<String, Any>,
        val cf_revenue_pages: Map<String, Any>,
        val cf_browser_variables: Map<String, Any>,
        val date: DateTime?
) {
        companion object {
                fun fromJson(jsonResponse: JSONObject): SdkSettings? {
                        val dateTimeString = jsonResponse.optString("date", null)
                        val date = dateTimeString?.let { DateTime.parse(it) }

                        return SdkSettings(
                                cf_key = jsonResponse.getString("cf_key"),
                                cf_account_enabled = jsonResponse.getBoolean("cf_account_enabled"),
                                cf_page_elements_path_type =
                                        jsonResponse.optString("cf_page_elements_path_type", null),
                                cf_latest_sdk_version =
                                        jsonResponse.optString("cf_latest_sdk_version", null),
                                cf_whitelabel_company_display_name =
                                        jsonResponse.optString(
                                                "cf_whitelabel_company_display_name",
                                                null
                                        ),
                                cf_domain_url = jsonResponse.optString("cf_domain_url", null),
                                cf_jsevl_type = jsonResponse.optString("cf_jsevl_type", null),
                                cf_config_reapply_timers =
                                        jsonResponse.optString("cf_config_reapply_timers", null),
                                cf_ga4_setup_mode =
                                        jsonResponse.optString("cf_ga4_setup_mode", null),
                                cf_gtm_data_variable_name =
                                        jsonResponse.optString("cf_gtm_data_variable_name", null),
                                cf_account_source =
                                        jsonResponse.optString("cf_account_source", null),
                                cf_event_merge_config =
                                        jsonResponse.optString("cf_event_merge_config", null),
                                cf_dimension_id = jsonResponse.optString("cf_dimension_id", null),
                                cf_intelligent_code_enabled =
                                        jsonResponse.getBoolean("cf_intelligent_code_enabled"),
                                cf_personalize_post_sdk_timeout =
                                        jsonResponse.getBoolean("cf_personalize_post_sdk_timeout"),
                                is_inbound = jsonResponse.getBoolean("is_inbound"),
                                is_outbound = jsonResponse.getBoolean("is_outbound"),
                                cfspa = jsonResponse.getBoolean("cfspa"),
                                cfspa_auto_detect_page_url_change =
                                        jsonResponse.getBoolean(
                                                "cfspa_auto_detect_page_url_change"
                                        ),
                                is_auto_form_capture =
                                        jsonResponse.getBoolean("is_auto_form_capture"),
                                is_auto_email_capture =
                                        jsonResponse.getBoolean("is_auto_email_capture"),
                                cf_is_page_update_enabled =
                                        jsonResponse.getBoolean("cf_is_page_update_enabled"),
                                cf_retain_text_value =
                                        jsonResponse.getBoolean("cf_retain_text_value"),
                                cf_is_whitelabel_account =
                                        jsonResponse.getBoolean("cf_is_whitelabel_account"),
                                cf_skip_sdk = jsonResponse.getBoolean("cf_skip_sdk"),
                                enable_event_analyzer =
                                        jsonResponse.getBoolean("enable_event_analyzer"),
                                cf_skip_dfs = jsonResponse.getBoolean("cf_skip_dfs"),
                                cf_is_ms_clarity_enabled =
                                        jsonResponse.getBoolean("cf_is_ms_clarity_enabled"),
                                cf_is_hotjar_enabled =
                                        jsonResponse.getBoolean("cf_is_hotjar_enabled"),
                                cf_is_shopify_integrated =
                                        jsonResponse.getBoolean("cf_is_shopify_integrated"),
                                cf_is_ga_enabled = jsonResponse.getBoolean("cf_is_ga_enabled"),
                                cf_is_segment_enabled =
                                        jsonResponse.getBoolean("cf_is_segment_enabled"),
                                cf_is_mixpanel_enabled =
                                        jsonResponse.getBoolean("cf_is_mixpanel_enabled"),
                                cf_is_moengage_enabled =
                                        jsonResponse.getBoolean("cf_is_moengage_enabled"),
                                cf_is_clevertap_enabled =
                                        jsonResponse.getBoolean("cf_is_clevertap_enabled"),
                                cf_is_webengage_enabled =
                                        jsonResponse.getBoolean("cf_is_webengage_enabled"),
                                cf_is_netcore_enabled =
                                        jsonResponse.getBoolean("cf_is_netcore_enabled"),
                                cf_is_amplitude_enabled =
                                        jsonResponse.getBoolean("cf_is_amplitude_enabled"),
                                cf_is_heap_enabled = jsonResponse.getBoolean("cf_is_heap_enabled"),
                                cf_is_gokwik_enabled =
                                        jsonResponse.getBoolean("cf_is_gokwik_enabled"),
                                cf_is_shopflo_enabled =
                                        jsonResponse.getBoolean("cf_is_shopflo_enabled"),
                                cf_send_error_report =
                                        jsonResponse.getBoolean("cf_send_error_report"),
                                personalized_users_limit_exceeded =
                                        jsonResponse.getBoolean(
                                                "personalized_users_limit_exceeded"
                                        ),
                                cf_sdk_timeout_in_seconds =
                                        jsonResponse.getInt("cf_sdk_timeout_in_seconds"),
                                cf_initial_delay_in_ms =
                                        jsonResponse.getInt("cf_initial_delay_in_ms"),
                                cf_last_visited_product_url =
                                        jsonResponse.getInt("cf_last_visited_product_url"),
                                blacklisted_page_paths =
                                        jsonResponse.optJSONArray("blacklisted_page_paths")?.let {
                                                List(it.length()) { index -> it.getString(index) }
                                        }
                                                ?: emptyList(),
                                blacklisted_referrers =
                                        jsonResponse.optJSONArray("blacklisted_referrers")?.let {
                                                List(it.length()) { index -> it.getString(index) }
                                        }
                                                ?: emptyList(),
                                cf_subdomains =
                                        jsonResponse.optJSONArray("cf_subdomains")?.let {
                                                List(it.length()) { index -> it.getString(index) }
                                        }
                                                ?: emptyList(),
                                cf_configs_json =
                                        jsonResponse.optJSONObject("cf_configs_json")?.toMap()
                                                ?: emptyMap(),
                                cf_active_pages =
                                        jsonResponse.optJSONObject("cf_active_pages")?.toMap()
                                                ?: emptyMap(),
                                cf_revenue_pages =
                                        jsonResponse.optJSONObject("cf_revenue_pages")?.toMap()
                                                ?: emptyMap(),
                                cf_browser_variables =
                                        jsonResponse.optJSONObject("cf_browser_variables")?.toMap()
                                                ?: emptyMap(),
                                date = date
                        )
                }
        }
}
