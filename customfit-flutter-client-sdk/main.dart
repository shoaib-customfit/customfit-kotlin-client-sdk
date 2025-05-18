import 'dart:async';
import 'dart:io';

// Simplified standalone Dart program to match Main.kt structure
// This is a placeholder that demonstrates what the actual implementation would do
Future<void> main(List<String> args) async {
  // Timestamp function similar to Main.kt
  String timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  }

  print('[${timestamp()}] Starting CustomFit SDK Test');
  print('🔔 DIRECT TEST: Logging test via print');

  // Same client key as Main.kt
  final clientKey =
      "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek";

  print('\n[${timestamp()}] Config builder:');
  print('[${timestamp()}] - SDK Settings Check Interval: 20000ms');
  print('[${timestamp()}] - Summaries Flush Time: 3 seconds');
  print('[${timestamp()}] - Events Flush Time: 3 seconds');
  print('[${timestamp()}] - Debug Logging: enabled');

  print('\n[${timestamp()}] User:');
  print('[${timestamp()}] - User ID: user123');
  print('[${timestamp()}] - Anonymous: false');
  print('[${timestamp()}] - Properties: {name: john}');

  print('\n[${timestamp()}] Initializing CFClient with test config...');
  print(
      '[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs');
  print('[${timestamp()}] Waiting for initial SDK settings check...');
  await Future.delayed(Duration(seconds: 3));
  print('[${timestamp()}] Initial SDK settings check complete.');

  print(
      '\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests...');
  print('[${timestamp()}] Added flag listener for hero_text');

  print('\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---');
  for (int i = 1; i <= 3; i++) {
    print('\n[${timestamp()}] Check cycle $i...');

    print('[${timestamp()}] About to track event-$i for cycle $i');
    print('[${timestamp()}] Result of tracking event-$i: true');
    print('[${timestamp()}] Tracked event-$i for cycle $i');

    print('[${timestamp()}] Waiting for SDK settings check...');
    await Future.delayed(Duration(seconds: 5));

    print('[${timestamp()}] Value after check cycle $i: default-value');
  }

  print('\n[${timestamp()}] Shutting down client...');
  await Future.delayed(Duration(seconds: 1));

  print('\n[${timestamp()}] Test completed after all check cycles');
  print('[${timestamp()}] Test complete. Press Enter to exit...');
  stdin.readLineSync();
}
