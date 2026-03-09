import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/features/vault/models/document_model.dart';
import 'package:myapp/features/vault/presentation/pdf_viewer_screen.dart';
import 'package:myapp/features/vault/providers/vault_provider.dart';

class PdfLoadingScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const PdfLoadingScreen({
    super.key,
    required this.document,
  });

  @override
  ConsumerState<PdfLoadingScreen> createState() => _PdfLoadingScreenState();
}

class _PdfLoadingScreenState extends ConsumerState<PdfLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _transitionToViewer();
  }

  Future<void> _transitionToViewer() async {
    // 1.5 seconds delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Update lastAccessed
    ref.read(vaultProvider.notifier).openDocument(widget.document.id);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PdfViewerScreen(
          filePath: widget.document.filePath,
          title: widget.document.title,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              Icon(
                Icons.description,
                size: 80,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              Text(
                'Opening your document...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
