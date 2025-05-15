import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customfit_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          if (!provider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    provider.trackEvent(
                      'button_clicked',
                      properties: {'button': 'showToast'},
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
                    provider.trackEvent(
                      'navigation',
                      properties: {'destination': 'SecondScreen'},
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feature Flags',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...provider.featureFlags.entries.map(
                          (entry) => ListTile(
                            title: Text(entry.key),
                            subtitle: Text(entry.value.toString()),
                          ),
                        ),
                      ],
                    ),
                  ),
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
