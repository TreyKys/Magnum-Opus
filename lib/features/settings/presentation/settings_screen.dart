import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/settings/widgets/complexity_dial.dart';

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
          // ── AI Intelligence ──────────────────────────────────────────────
          _buildSection(
            context,
            'Response Depth',
            [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Response Complexity',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Controls how deep and technical Magnum responds. Persists across sessions.',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    const ComplexityDial(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Preferences ──────────────────────────────────────────────────
          _buildSection(
            context,
            'Preferences',
            [
              SwitchListTile(
                title: const Text('Haptic Feedback',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Vibrations for UI interactions.',
                    style: TextStyle(color: AppTheme.textMuted)),
                value: settingsState.enableHaptics,
                onChanged: settingsNotifier.toggleHaptics,
              ),
              SwitchListTile(
                title: const Text('Reading Tips',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Show helpful tips while loading documents.',
                    style: TextStyle(color: AppTheme.textMuted)),
                value: settingsState.showReadingTips,
                onChanged: settingsNotifier.toggleReadingTips,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Document Viewer ───────────────────────────────────────────────
          _buildSection(
            context,
            'Document Viewer',
            [
              ListTile(
                title: const Text('Default Zoom Level',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${settingsState.defaultZoomLevel.toStringAsFixed(2)}x',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        if (settingsState.defaultZoomLevel > 0.5) {
                          settingsNotifier.setZoomLevel(
                              settingsState.defaultZoomLevel - 0.25);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        if (settingsState.defaultZoomLevel < 3.0) {
                          settingsNotifier.setZoomLevel(
                              settingsState.defaultZoomLevel + 0.25);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── About ─────────────────────────────────────────────────────────
          _buildSection(
            context,
            'About',
            [
              const ListTile(
                title: Text('Version',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text('2.0.0 (Magnum Opus)',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              const ListTile(
                title: Text('Magnum Engine',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                    'Proprietary · Local-first · v4',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              const ListTile(
                title: Text('Supported Formats',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                    'PDF · EPUB · DOCX · XLSX · PPTX · CSV · TXT · Audio · URL',
                    style: TextStyle(color: AppTheme.textMuted, height: 1.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.accentBlueLight,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
