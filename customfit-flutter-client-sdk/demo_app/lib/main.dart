import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customfit_provider.dart';
import 'screens/home_screen.dart';

// Global variables for direct access - updated to latest version (18)
String globalHeroText = 'CF Kotlin Flag Demo-18';
bool globalEnhancedToast = true;

void main() {
  // Set the global values immediately - updated to latest version
  globalHeroText = 'CF Kotlin Flag Demo-18';
  globalEnhancedToast = true;

  // Catch any Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter error: ${details.exception}');
    debugPrint('${details.stack}');
    // Still report to Flutter's console
    FlutterError.presentError(details);
  };

  // Catch any non-Flutter errors
  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stack) {
      debugPrint('🔴 Uncaught error: $error');
      debugPrint('$stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        // Create the provider and log when it changes
        final provider = CustomFitProvider();
        provider.addListener(() {
          debugPrint(
              '⭐ PROVIDER UPDATED: heroText=${provider.heroText}, enhancedToast=${provider.enhancedToast}');

          // Also update global variables when provider updates
          globalHeroText = provider.heroText;
          globalEnhancedToast = provider.enhancedToast;
        });
        // Start initialization and return the provider
        return provider..initialize();
      },
      child: MaterialApp(
        title: 'CustomFit Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
