import 'connection_information.dart';
import 'connection_status.dart';

/// Callback for connection status changes
abstract class ConnectionStatusListener {
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info);
}
