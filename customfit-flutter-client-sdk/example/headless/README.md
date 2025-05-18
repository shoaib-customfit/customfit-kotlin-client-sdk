# CustomFit SDK - Headless Test

This directory contains tools for running the CustomFit SDK in a headless mode, without requiring a complete Flutter app.

## Purpose

The headless test allows you to:

1. Verify that the CustomFit SDK can connect to the backend
2. Test feature flag evaluations
3. Test event tracking
4. Monitor SDK settings checks

## Running the Headless Test

There are two ways to run the headless test:

### 1. Using the Shell Script (Recommended)

The `run_headless.sh` script will run the Kotlin implementation of the headless test directly:

```bash
chmod +x run_headless.sh
./run_headless.sh
```

This is the most reliable way to run the test as it doesn't depend on Flutter setup.

### 2. Using the Dart Implementation (Requires Flutter Setup)

If you have Flutter set up correctly, you can run the Dart version:

```bash
dart main.dart
```

Note: The Dart implementation might require additional setup if Flutter is not properly configured.

## Expected Output

When running the test, you should see output similar to:

```
Starting CustomFit SDK Test
Debug logging enabled - watch for SDK settings checks in logs
Waiting for initial SDK settings check...
Initial SDK settings check complete.

Testing event tracking is disabled to reduce POST requests...

--- PHASE 1: Normal SDK Settings Checks ---
Check cycle 1...
About to track event-1 for cycle 1
Result of tracking event-1: true
Tracked event-1 for cycle 1
Waiting for SDK settings check...
Value after check cycle 1: default-value or actual flag value

...

Test completed after all check cycles
```

## Troubleshooting

If you encounter issues with the Dart implementation, use the shell script instead, which runs the Kotlin implementation directly. 