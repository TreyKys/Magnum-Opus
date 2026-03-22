import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/onboarding/presentation/intro_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSettingsSection(
            context,
            'Preferences',
            [
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                subtitle: const Text('Vibrations for UI interactions.'),
                value: settingsState.enableHaptics,
                onChanged: settingsNotifier.toggleHaptics,
                activeThumbColor: Colors.cyanAccent,
              ),
              SwitchListTile(
                title: const Text('Reading Tips'),
                subtitle: const Text('Show helpful tips while loading documents.'),
                value: settingsState.showReadingTips,
                onChanged: settingsNotifier.toggleReadingTips,
                activeThumbColor: Colors.cyanAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            'Document Viewer',
            [
              ListTile(
                title: const Text('Default Zoom Level'),
                subtitle: Text('${settingsState.defaultZoomLevel.toStringAsFixed(2)}x'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (settingsState.defaultZoomLevel > 0.5) {
                          settingsNotifier.setZoomLevel(settingsState.defaultZoomLevel - 0.25);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (settingsState.defaultZoomLevel < 3.0) {
                          settingsNotifier.setZoomLevel(settingsState.defaultZoomLevel + 0.25);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            'About',
            [
              ListTile(
                title: const Text('How to Use'),
                subtitle: const Text('Replay the Magnum Opus tutorial.'),
                trailing: const Icon(Icons.help_outline, color: Colors.cyanAccent),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IntroScreen(fromSettings: true),
                    ),
                  );
                },
              ),
              const ListTile(
                title: Text('Version'),
                subtitle: Text('1.0.0 (Ignition Phase)'),
              ),
              const ListTile(
                title: Text('Intelligence Engine'),
                subtitle: Text('Gemini 2.5 Flash + Local RAG SQLite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.cyanAccent,
                ),
          ),
        ),
        Card(
          color: const Color(0xFF1A1A1A),
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
