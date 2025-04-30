import 'connection_status.dart';

/// Detailed info about the SDK’s connection state
class ConnectionInformation {
  final ConnectionStatus status;
  final bool isOfflineMode;
  final String? lastError;
  final int lastSuccessfulConnectionTimeMs;
  final int failureCount;
  final int nextReconnectTimeMs;

  ConnectionInformation({
    required this.status,
    required this.isOfflineMode,
    this.lastError,
    this.lastSuccessfulConnectionTimeMs = 0,
    this.failureCount = 0,
    this.nextReconnectTimeMs = 0,
  });

  @override
  String toString() => 'ConnectionInformation(status: $status, '
      'offline: $isOfflineMode, lastError: $lastError, '
      'lastSuccess: $lastSuccessfulConnectionTimeMs, '
      'failures: $failureCount, nextReconnect: $nextReconnectTimeMs)';
}
