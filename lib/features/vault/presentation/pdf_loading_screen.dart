import 'package:flutter/material.dart';
import 'package:myapp/features/vault/presentation/pdf_viewer_screen.dart';

class PdfLoadingScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfLoadingScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfLoadingScreen> createState() => _PdfLoadingScreenState();
}

class _PdfLoadingScreenState extends State<PdfLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _transitionToViewer();
  }

  Future<void> _transitionToViewer() async {
    // 1.5-second delay before seamlessly replacing the screen
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PdfViewerScreen(
          filePath: widget.filePath,
          title: widget.title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animation.value),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.description,
                size: 90,
                color: Colors.cyanAccent,
              ),
              const SizedBox(height: 32),
              Text(
                'Opening your document...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
