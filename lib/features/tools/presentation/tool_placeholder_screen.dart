import 'package:flutter/material.dart';

class ToolPlaceholderScreen extends StatelessWidget {
  final String toolName;
  final bool isPro;

  const ToolPlaceholderScreen({super.key, required this.toolName, this.isPro = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(toolName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: isPro ? const Color(0xFFB026FF) : const Color(0xFF00E5FF),
              ),
              const SizedBox(height: 24),
              Text(
                '$toolName is under construction.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              if (isPro) ...[
                const SizedBox(height: 16),
                const Text(
                  'Magnum Pro Feature',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
