import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/features/economy/providers/economy_provider.dart';

class ProToolShell extends ConsumerWidget {
  final String toolName;
  final IconData icon;
  final VoidCallback onSimulatedAction;
  final String actionLabel;
  final String description;

  const ProToolShell({
    super.key,
    required this.toolName,
    required this.icon,
    required this.onSimulatedAction,
    required this.actionLabel,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(economyProvider).isPro;

    return Scaffold(
      appBar: AppBar(title: Text(toolName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: const Color(0xFFB026FF)),
              const SizedBox(height: 24),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (isPro)
                ElevatedButton(
                  onPressed: onSimulatedAction,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB026FF)),
                  child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
                )
              else
                Column(
                  children: [
                    const Icon(Icons.lock, color: Colors.amber, size: 40),
                    const SizedBox(height: 16),
                    const Text('Requires Magnum Pro', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Trigger test purchase flow
                        ref.read(economyProvider.notifier).upgradeToPro('magnum_pro_monthly');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      child: const Text('Unlock Pro (Test Env)', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
