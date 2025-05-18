import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customfit_provider.dart';
import 'screens/home_screen.dart';

void main() {
  // Catch any Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter error: ${details.exception}');
    debugPrint('${details.stack}');
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
        final provider = CustomFitProvider();
        provider.addListener(() {
          debugPrint(
              '⭐ PROVIDER UPDATED: heroText=${provider.heroText}, enhancedToast=${provider.enhancedToast}');
        });
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
