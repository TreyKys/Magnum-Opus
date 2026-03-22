import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/features/vault/presentation/dashboard_screen.dart'; // We'll create this later

class LoadingScreen extends ConsumerStatefulWidget {
  final bool isFirstLaunch;

  const LoadingScreen({super.key, required this.isFirstLaunch});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (widget.isFirstLaunch) {
          Navigator.pushReplacementNamed(context, '/intro');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.memory,
                size: 80,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(height: 24),
              Text(
                'MAGNUM OPUS',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  letterSpacing: 4.0,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'FILE INTELLIGENCE',
                style: TextStyle(
                  color: Color(0xFFB026FF),
                  letterSpacing: 2.0,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
