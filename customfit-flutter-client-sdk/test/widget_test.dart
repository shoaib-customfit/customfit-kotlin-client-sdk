import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

void main() {
  test('SDK can be imported correctly', () {
    // Verify we can create basic SDK objects
    final user = CFUser(
      userCustomerId: 'test-user-123',
      anonymous: false,
      properties: {
        'name': 'Test User',
      },
    );

    final config = CFConfig.builder('test-client-key')
        .setDebugLoggingEnabled(true)
        .build();

    // If we reach this point without errors, the test passes
    expect(user.userCustomerId, equals('test-user-123'));
    expect(config.debugLoggingEnabled, isTrue);
  });
}

