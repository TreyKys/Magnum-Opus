import 'dart:math';
import 'package:flutter/material.dart';
import 'package:myapp/features/vault/presentation/pdf_viewer_screen.dart';

class PdfLoadingScreen extends StatefulWidget {
  final String id;
  final String filePath;
  final String title;

  const PdfLoadingScreen({
    super.key,
    required this.id,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfLoadingScreen> createState() => _PdfLoadingScreenState();
}

class _PdfLoadingScreenState extends State<PdfLoadingScreen> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _selectedTip = '';

  static const List<String> _tips = [
    // General Document Tips
    "Use active recall and spaced repetition to remember document content.",
    "Highlight sparingly; it helps important text stand out more effectively.",
    "Read the conclusion first to understand the author's destination.",
    "Skim headings before reading to build a mental map of the text.",
    "Summarize each section in your own words to improve comprehension.",
    "Take breaks every 25 minutes to maintain peak cognitive focus.",
    "Look up unfamiliar words immediately to avoid losing context.",
    "Discussing what you read with others solidifies your understanding.",
    "Ask questions of the text as you read to stay actively engaged.",
    "Create a glossary of key terms for complex or technical documents.",
    // Magnum Opus Specific Tips
    "Magnum Opus uses a Swarm Engine for high-performance background extraction.",
    "The vault never drops a frame, keeping your UI 100% responsive.",
    "All data stays on your device. Zero external servers. Complete privacy.",
    "Magnum Opus leverages Isolate spawning to handle massive documents efficiently.",
    "Our custom SQLite schema ensures instant recovery even if interrupted.",
    "Experience pure performance with the NeuroDev flat design system.",
    "Magnum Opus dynamically chunks document data to prevent memory leaks.",
    "Your reading progress and recent documents are intelligently tracked.",
    "Background processes automatically retry if the app is unexpectedly closed.",
    "Powered by Riverpod state management for flawless, reactive UI updates."
  ];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _hoverAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _selectedTip = _tips[Random().nextInt(_tips.length)];

    _fadeController.forward();
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
          id: widget.id,
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
    _hoverController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _hoverAnimation.value),
                  child: child,
                );
              },
              child: const Icon(
                Icons.description,
                size: 90,
                color: Colors.cyanAccent,
              ),
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
            const SizedBox(height: 48),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  _selectedTip,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
