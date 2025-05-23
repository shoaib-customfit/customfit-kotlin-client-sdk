import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customfit_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _previousMessage;
  bool _forceShowUI = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    // Add a safety timeout - if loading takes more than 10 seconds, show UI anyway
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_forceShowUI) {
        setState(() {
          _forceShowUI = true;
          debugPrint('⚠️ Timeout reached, forcing UI to show');
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize with provider values and check for config changes
    final provider = Provider.of<CustomFitProvider>(context);
    _previousMessage = provider.lastConfigChangeMessage;

    if (provider.isInitialized &&
        provider.hasNewConfigMessage &&
        provider.lastConfigChangeMessage != _previousMessage) {
      _previousMessage = provider.lastConfigChangeMessage;

      // Show notification after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.lastConfigChangeMessage ?? ''),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<CustomFitProvider>(
          builder: (context, provider, _) {
            return Text(provider.heroText);
          },
        ),
        actions: [
          Consumer<CustomFitProvider>(
            builder: (context, provider, _) {
              return Switch(
                value: provider.isOffline,
                onChanged: (value) => provider.toggleOfflineMode(),
                activeColor: Colors.red,
                inactiveTrackColor: Colors.green,
              );
            },
          ),
        ],
      ),
      body: Consumer<CustomFitProvider>(
        builder: (context, provider, _) {
          if (!provider.isInitialized && !_forceShowUI) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading CustomFit...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _forceShowUI = true;
                      });
                    },
                    child: const Text('Show UI anyway'),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Use more specific event name and properties with flutter prefix
                    provider.trackEvent(
                      'flutter_toast_button_interaction',
                      properties: {
                        'action': 'click',
                        'feature': 'toast_message',
                        'platform': 'flutter'
                      },
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.enhancedToast
                              ? 'Enhanced toast feature enabled!'
                              : 'Button clicked!',
                        ),
                        duration: provider.enhancedToast
                            ? const Duration(seconds: 3)
                            : const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text('Show Toast'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Use more specific event name and properties with flutter prefix
                    provider.trackEvent(
                      'flutter_screen_navigation',
                      properties: {
                        'from': 'main_screen',
                        'to': 'second_screen',
                        'user_flow': 'primary_navigation',
                        'platform': 'flutter'
                      },
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecondScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to Second Screen'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isRefreshing
                      ? null
                      : () async {
                          setState(() {
                            _isRefreshing = true;
                          });

                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing configuration...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Call the refresh method with flutter prefix
                          await provider.refreshFeatureFlags(
                              'flutter_config_manual_refresh');

                          setState(() {
                            _isRefreshing = false;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isRefreshing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Refreshing Config...'),
                          ],
                        )
                      : const Text('Refresh Config'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Screen'),
      ),
      body: const Center(
        child: Text('This is the second screen'),
      ),
    );
  }
}
