import 'connection_information.dart';
import 'connection_status.dart';

/// Status of the connection
enum ConnectionStatusType {
  /// Connected to the network
  connected,
  
  /// Disconnected from the network
  disconnected,
  
  /// Connection is in an unknown state
  unknown
}

/// Information about the connection
class ConnectionStatusInfo {
  /// Whether the connection is available
  final bool isAvailable;
  
  /// Whether the connection is metered
  final bool isMetered;
  
  /// Type of connection
  final String connectionType;
  
  /// Create a new Information
  ConnectionStatusInfo({
    required this.isAvailable,
    required this.isMetered,
    required this.connectionType,
  });
}

/// Callback for connection status changes
abstract class ConnectionStatusListener {
  /// Called when the connection status changes
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info);
}
