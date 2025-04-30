import 'package:flutter/foundation.dart';

@immutable
class SdkSettings {
  final Map<String, dynamic> cfConfigsJson;
  final Map<String, dynamic> cfActivePages;
  final Map<String, dynamic> cfRevenuePages;
  final Map<String, dynamic> cfBrowserVariables;
  final String? date;
  final String cfKey;
  final bool cfAccountEnabled;
  final String? cfPageElementsPathType;
  final String? cfLatestSdkVersion;
  final String? cfWhitelabelCompanyDisplayName;
  final String? cfDomainUrl;
  final String? cfJsevlType;
  final String? cfConfigReapplyTimers;
  final String? cfGa4SetupMode;
  final String? cfGtmDataVariableName;
  final String? cfAccountSource;
  final String? cfEventMergeConfig;
  final String? cfDimensionId;
  final bool cfIntelligentCodeEnabled;
  final bool cfPersonalizePostSdkTimeout;
  final bool isInbound;
  final bool isOutbound;
  final bool cfspa;
  final bool cfspaAutoDetectPageUrlChange;
  final bool isAutoFormCapture;
  final bool isAutoEmailCapture;
  final bool cfIsPageUpdateEnabled;
  final bool cfRetainTextValue;
  final bool cfIsWhitelabelAccount;
  final bool cfSkipSdk;
  final bool enableEventAnalyzer;
  final bool cfSkipDfs;
  final bool cfIsMsClarityEnabled;
  final bool cfIsHotjarEnabled;
  final bool cfIsShopifyIntegrated;
  final bool cfIsGaEnabled;
  final bool cfIsSegmentEnabled;
  final bool cfIsMixpanelEnabled;
  final bool cfIsMoengageEnabled;
  final bool cfIsClevertapEnabled;
  final bool cfIsWebengageEnabled;
  final bool cfIsNetcoreEnabled;
  final bool cfIsAmplitudeEnabled;
  final bool cfIsHeapEnabled;
  final bool cfIsGokwikEnabled;
  final bool cfIsShopfloEnabled;
  final bool cfSendErrorReport;
  final bool personalizedUsersLimitExceeded;
  final int cfSdkTimeoutInSeconds;
  final int cfInitialDelayInMs;
  final int cfLastVisitedProductUrl;
  final List<String> blacklistedPagePaths;
  final List<String> blacklistedReferrers;
  final List<String> cfSubdomains;
  final Map<String, dynamic> defaultConfig;
  final Map<String, dynamic> defaultExperience;
  final Map<String, dynamic> defaultBehaviour;
  final Map<String, dynamic> defaultVariation;

  const SdkSettings({
    required this.cfConfigsJson,
    required this.cfActivePages,
    required this.cfRevenuePages,
    required this.cfBrowserVariables,
    this.date,
    required this.cfKey,
    required this.cfAccountEnabled,
    this.cfPageElementsPathType,
    this.cfLatestSdkVersion,
    this.cfWhitelabelCompanyDisplayName,
    this.cfDomainUrl,
    this.cfJsevlType,
    this.cfConfigReapplyTimers,
    this.cfGa4SetupMode,
    this.cfGtmDataVariableName,
    this.cfAccountSource,
    this.cfEventMergeConfig,
    this.cfDimensionId,
    required this.cfIntelligentCodeEnabled,
    required this.cfPersonalizePostSdkTimeout,
    required this.isInbound,
    required this.isOutbound,
    required this.cfspa,
    required this.cfspaAutoDetectPageUrlChange,
    required this.isAutoFormCapture,
    required this.isAutoEmailCapture,
    required this.cfIsPageUpdateEnabled,
    required this.cfRetainTextValue,
    required this.cfIsWhitelabelAccount,
    required this.cfSkipSdk,
    required this.enableEventAnalyzer,
    required this.cfSkipDfs,
    required this.cfIsMsClarityEnabled,
    required this.cfIsHotjarEnabled,
    required this.cfIsShopifyIntegrated,
    required this.cfIsGaEnabled,
    required this.cfIsSegmentEnabled,
    required this.cfIsMixpanelEnabled,
    required this.cfIsMoengageEnabled,
    required this.cfIsClevertapEnabled,
    required this.cfIsWebengageEnabled,
    required this.cfIsNetcoreEnabled,
    required this.cfIsAmplitudeEnabled,
    required this.cfIsHeapEnabled,
    required this.cfIsGokwikEnabled,
    required this.cfIsShopfloEnabled,
    required this.cfSendErrorReport,
    required this.personalizedUsersLimitExceeded,
    required this.cfSdkTimeoutInSeconds,
    required this.cfInitialDelayInMs,
    required this.cfLastVisitedProductUrl,
    required this.blacklistedPagePaths,
    required this.blacklistedReferrers,
    required this.cfSubdomains,
    this.defaultConfig = const {},
    this.defaultExperience = const {},
    this.defaultBehaviour = const {},
    this.defaultVariation = const {},
  });

  factory SdkSettings.fromJson(Map<String, dynamic> json) {
    return SdkSettings(
      cfConfigsJson: Map<String, dynamic>.from(json['cf_configs_json'] ?? {}),
      cfActivePages: Map<String, dynamic>.from(json['cf_active_pages'] ?? {}),
      cfRevenuePages: Map<String, dynamic>.from(json['cf_revenue_pages'] ?? {}),
      cfBrowserVariables:
          Map<String, dynamic>.from(json['cf_browser_variables'] ?? {}),
      date: json['date'] as String?,
      cfKey: json['cf_key'] as String,
      cfAccountEnabled: json['cf_account_enabled'] as bool,
      cfPageElementsPathType: json['cf_page_elements_path_type'] as String?,
      cfLatestSdkVersion: json['cf_latest_sdk_version'] as String?,
      cfWhitelabelCompanyDisplayName:
          json['cf_whitelabel_company_display_name'] as String?,
      cfDomainUrl: json['cf_domain_url'] as String?,
      cfJsevlType: json['cf_jsevl_type'] as String?,
      cfConfigReapplyTimers: json['cf_config_reapply_timers'] as String?,
      cfGa4SetupMode: json['cf_ga4_setup_mode'] as String?,
      cfGtmDataVariableName: json['cf_gtm_data_variable_name'] as String?,
      cfAccountSource: json['cf_account_source'] as String?,
      cfEventMergeConfig: json['cf_event_merge_config'] as String?,
      cfDimensionId: json['cf_dimension_id'] as String?,
      cfIntelligentCodeEnabled: json['cf_intelligent_code_enabled'] as bool,
      cfPersonalizePostSdkTimeout:
          json['cf_personalize_post_sdk_timeout'] as bool,
      isInbound: json['is_inbound'] as bool,
      isOutbound: json['is_outbound'] as bool,
      cfspa: json['cfspa'] as bool,
      cfspaAutoDetectPageUrlChange:
          json['cfspa_auto_detect_page_url_change'] as bool,
      isAutoFormCapture: json['is_auto_form_capture'] as bool,
      isAutoEmailCapture: json['is_auto_email_capture'] as bool,
      cfIsPageUpdateEnabled: json['cf_is_page_update_enabled'] as bool,
      cfRetainTextValue: json['cf_retain_text_value'] as bool,
      cfIsWhitelabelAccount: json['cf_is_whitelabel_account'] as bool,
      cfSkipSdk: json['cf_skip_sdk'] as bool,
      enableEventAnalyzer: json['enable_event_analyzer'] as bool,
      cfSkipDfs: json['cf_skip_dfs'] as bool,
      cfIsMsClarityEnabled: json['cf_is_ms_clarity_enabled'] as bool,
      cfIsHotjarEnabled: json['cf_is_hotjar_enabled'] as bool,
      cfIsShopifyIntegrated: json['cf_is_shopify_integrated'] as bool,
      cfIsGaEnabled: json['cf_is_ga_enabled'] as bool,
      cfIsSegmentEnabled: json['cf_is_segment_enabled'] as bool,
      cfIsMixpanelEnabled: json['cf_is_mixpanel_enabled'] as bool,
      cfIsMoengageEnabled: json['cf_is_moengage_enabled'] as bool,
      cfIsClevertapEnabled: json['cf_is_clevertap_enabled'] as bool,
      cfIsWebengageEnabled: json['cf_is_webengage_enabled'] as bool,
      cfIsNetcoreEnabled: json['cf_is_netcore_enabled'] as bool,
      cfIsAmplitudeEnabled: json['cf_is_amplitude_enabled'] as bool,
      cfIsHeapEnabled: json['cf_is_heap_enabled'] as bool,
      cfIsGokwikEnabled: json['cf_is_gokwik_enabled'] as bool,
      cfIsShopfloEnabled: json['cf_is_shopflo_enabled'] as bool,
      cfSendErrorReport: json['cf_send_error_report'] as bool,
      personalizedUsersLimitExceeded:
          json['personalized_users_limit_exceeded'] as bool,
      cfSdkTimeoutInSeconds: json['cf_sdk_timeout_in_seconds'] as int,
      cfInitialDelayInMs: json['cf_initial_delay_in_ms'] as int,
      cfLastVisitedProductUrl: json['cf_last_visited_product_url'] as int,
      blacklistedPagePaths:
          List<String>.from(json['blacklisted_page_paths'] ?? []),
      blacklistedReferrers:
          List<String>.from(json['blacklisted_referrers'] ?? []),
      cfSubdomains: List<String>.from(json['cf_subdomains'] ?? []),
      defaultConfig: Map<String, dynamic>.from(json['defaultConfig'] ?? {}),
      defaultExperience:
          Map<String, dynamic>.from(json['defaultExperience'] ?? {}),
      defaultBehaviour:
          Map<String, dynamic>.from(json['defaultBehaviour'] ?? {}),
      defaultVariation:
          Map<String, dynamic>.from(json['defaultVariation'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cf_configs_json': cfConfigsJson,
      'cf_active_pages': cfActivePages,
      'cf_revenue_pages': cfRevenuePages,
      'cf_browser_variables': cfBrowserVariables,
      'date': date,
      'cf_key': cfKey,
      'cf_account_enabled': cfAccountEnabled,
      'cf_page_elements_path_type': cfPageElementsPathType,
      'cf_latest_sdk_version': cfLatestSdkVersion,
      'cf_whitelabel_company_display_name': cfWhitelabelCompanyDisplayName,
      'cf_domain_url': cfDomainUrl,
      'cf_jsevl_type': cfJsevlType,
      'cf_config_reapply_timers': cfConfigReapplyTimers,
      'cf_ga4_setup_mode': cfGa4SetupMode,
      'cf_gtm_data_variable_name': cfGtmDataVariableName,
      'cf_account_source': cfAccountSource,
      'cf_event_merge_config': cfEventMergeConfig,
      'cf_dimension_id': cfDimensionId,
      'cf_intelligent_code_enabled': cfIntelligentCodeEnabled,
      'cf_personalize_post_sdk_timeout': cfPersonalizePostSdkTimeout,
      'is_inbound': isInbound,
      'is_outbound': isOutbound,
      'cfspa': cfspa,
      'cfspa_auto_detect_page_url_change': cfspaAutoDetectPageUrlChange,
      'is_auto_form_capture': isAutoFormCapture,
      'is_auto_email_capture': isAutoEmailCapture,
      'cf_is_page_update_enabled': cfIsPageUpdateEnabled,
      'cf_retain_text_value': cfRetainTextValue,
      'cf_is_whitelabel_account': cfIsWhitelabelAccount,
      'cf_skip_sdk': cfSkipSdk,
      'enable_event_analyzer': enableEventAnalyzer,
      'cf_skip_dfs': cfSkipDfs,
      'cf_is_ms_clarity_enabled': cfIsMsClarityEnabled,
      'cf_is_hotjar_enabled': cfIsHotjarEnabled,
      'cf_is_shopify_integrated': cfIsShopifyIntegrated,
      'cf_is_ga_enabled': cfIsGaEnabled,
      'cf_is_segment_enabled': cfIsSegmentEnabled,
      'cf_is_mixpanel_enabled': cfIsMixpanelEnabled,
      'cf_is_moengage_enabled': cfIsMoengageEnabled,
      'cf_is_clevertap_enabled': cfIsClevertapEnabled,
      'cf_is_webengage_enabled': cfIsWebengageEnabled,
      'cf_is_netcore_enabled': cfIsNetcoreEnabled,
      'cf_is_amplitude_enabled': cfIsAmplitudeEnabled,
      'cf_is_heap_enabled': cfIsHeapEnabled,
      'cf_is_gokwik_enabled': cfIsGokwikEnabled,
      'cf_is_shopflo_enabled': cfIsShopfloEnabled,
      'cf_send_error_report': cfSendErrorReport,
      'personalized_users_limit_exceeded': personalizedUsersLimitExceeded,
      'cf_sdk_timeout_in_seconds': cfSdkTimeoutInSeconds,
      'cf_initial_delay_in_ms': cfInitialDelayInMs,
      'cf_last_visited_product_url': cfLastVisitedProductUrl,
      'blacklisted_page_paths': blacklistedPagePaths,
      'blacklisted_referrers': blacklistedReferrers,
      'cf_subdomains': cfSubdomains,
      'defaultConfig': defaultConfig,
      'defaultExperience': defaultExperience,
      'defaultBehaviour': defaultBehaviour,
      'defaultVariation': defaultVariation,
    };
  }
}
