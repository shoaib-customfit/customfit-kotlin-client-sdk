// lib/src/analytics/summary/cf_config_request_summary.dart

import 'dart:convert';
import 'package:intl/intl.dart';

/// Mirrors Kotlin’s CFConfigRequestSummary data class
class CFConfigRequestSummary {
  final String? configId;
  final String? version;
  final String? userId;
  final String requestedTime;
  final String? variationId;
  final String userCustomerId;
  final String sessionId;
  final String? behaviourId;
  final String? experienceId;
  final String? ruleId;

  static final _formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSSX');

  CFConfigRequestSummary({
    this.configId,
    this.version,
    this.userId,
    required this.requestedTime,
    this.variationId,
    required this.userCustomerId,
    required this.sessionId,
    this.behaviourId,
    this.experienceId,
    this.ruleId,
  });

  /// Factory to construct from a config map, customer ID, and session ID
  factory CFConfigRequestSummary.fromConfig(
    Map<String, dynamic> config,
    String customerUserId,
    String sessionId,
  ) {
    return CFConfigRequestSummary(
      configId: config['config_id'] as String?,
      version: config['version'] as String?,
      userId: config['user_id'] as String?,
      requestedTime: _formatter.format(DateTime.now().toUtc()),
      variationId: config['variation_id'] as String?,
      userCustomerId: customerUserId,
      sessionId: sessionId,
      behaviourId: config['behaviour_id'] as String?,
      experienceId: config['experience_id'] as String?,
      ruleId: config['rule_id'] as String?,
    );
  }

  /// Convert to Map for JSON serialization
  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'config_id': configId,
      'version': version,
      'user_id': userId,
      'requested_time': requestedTime,
      'variation_id': variationId,
      'user_customer_id': userCustomerId,
      'session_id': sessionId,
      'behaviour_id': behaviourId,
      'experience_id': experienceId,
      'rule_id': ruleId,
    };
    m.removeWhere((k, v) => v == null);
    return m;
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Factory to create from a Map
  factory CFConfigRequestSummary.fromMap(Map<String, dynamic> m) {
    return CFConfigRequestSummary(
      configId: m['config_id'] as String?,
      version: m['version'] as String?,
      userId: m['user_id'] as String?,
      requestedTime: m['requested_time'] as String,
      variationId: m['variation_id'] as String?,
      userCustomerId: m['user_customer_id'] as String,
      sessionId: m['session_id'] as String,
      behaviourId: m['behaviour_id'] as String?,
      experienceId: m['experience_id'] as String?,
      ruleId: m['rule_id'] as String?,
    );
  }

  @override
  String toString() =>
      'CFConfigRequestSummary(configId: \$configId, experienceId: \$experienceId, variationId: \$variationId)';
}
