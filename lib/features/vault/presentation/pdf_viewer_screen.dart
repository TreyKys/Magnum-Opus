import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;

import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/presentation/document_chat_screen.dart';

// ─── LaTeX rendering ──────────────────────────────────────────────────────────

class LatexSyntax extends m.InlineSyntax {
  LatexSyntax() : super(r'\$(.+?)\$');
  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final latex = match[1];
    if (latex != null) {
      parser.addNode(m.Element.text('latex', latex));
      return true;
    }
    return false;
  }
}

class LatexBlockSyntax extends m.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$(.*?)\$\$$', multiLine: true);
  @override
  m.Node parse(m.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    final latex = match?[1] ?? '';
    parser.advance();
    return m.Element.text('latexBlock', latex);
  }
}

class LatexBlockNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  LatexBlockNode(this.attributes, this.textContent);
  @override
  InlineSpan build() => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Math.tex(textContent,
              textStyle: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      );
}

class LatexBlockGenerator extends SpanNodeGeneratorWithTag {
  LatexBlockGenerator()
      : super(
            tag: 'latexBlock',
            generator: (e, config, visitor) =>
                LatexBlockNode(e.attributes, e.textContent));
  @override
  SpanNode build() => LatexBlockNode(const {}, '');
}

class LatexGenerator extends SpanNodeGeneratorWithTag {
  LatexGenerator()
      : super(
            tag: 'latex',
            generator: (e, config, visitor) =>
                LatexNode(e.attributes, e.textContent));
  @override
  SpanNode build() => LatexNode(const {}, '');
}

class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  LatexNode(this.attributes, this.textContent);
  @override
  InlineSpan build() => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(textContent,
            textStyle: const TextStyle(fontSize: 16, color: Colors.white)),
      );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class PdfViewerScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen>
    with TickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  bool _showLoadingScreen = true;
  int _quarterTurns = 0;
  bool _isFullScreen = false;

  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _selectedTip = '';

  static const List<String> _tips = [
    'Use active recall and spaced repetition to remember document content.',
    'Highlight sparingly; it helps important text stand out more effectively.',
    'Read the conclusion first to understand the author\'s destination.',
    'Skim headings before reading to build a mental map of the text.',
    'Summarize each section in your own words to improve comprehension.',
    'Take breaks every 25 minutes to maintain peak cognitive focus.',
    'Look up unfamiliar words immediately to avoid losing context.',
    'Discussing what you read with others solidifies your understanding.',
    'Ask questions of the text as you read to stay actively engaged.',
    'Create a glossary of key terms for complex or technical documents.',
    'Magnum Opus uses a Swarm Engine for high-performance background extraction.',
    'The vault never drops a frame, keeping your UI 100% responsive.',
    'All data stays on your device. Zero external servers. Complete privacy.',
    'Magnum Opus leverages Isolate spawning to handle massive documents efficiently.',
    'Our custom SQLite schema ensures instant recovery even if interrupted.',
    'The Complexity Dial scales from ELI5 to expert-level — try it!',
    'Magnum Opus dynamically chunks document data to prevent memory leaks.',
    'Your reading progress and recent documents are intelligently tracked.',
    'Background processes automatically retry if the app is unexpectedly closed.',
    'Powered by Riverpod state management for flawless, reactive UI updates.',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _pdfViewerController.zoomLevel = settings.defaultZoomLevel;
    });

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
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _hoverController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(
                widget.document.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: () {
                    _pdfViewerController.zoomLevel =
                        _pdfViewerController.zoomLevel + 0.25;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: () {
                    _pdfViewerController.zoomLevel =
                        _pdfViewerController.zoomLevel - 0.25;
                  },
                ),
              ],
            ),
      floatingActionButton: _isFullScreen || _isLoading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text('Chat',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentChatScreen(document: widget.document),
                ),
              ),
            ),
      body: Stack(
        children: [
          RotatedBox(
            quarterTurns: _quarterTurns,
            child: SfPdfViewer.file(
              File(widget.document.filePath),
              controller: _pdfViewerController,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  _pageCount = details.document.pages.count;
                  _isLoading = false;
                });
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) setState(() => _showLoadingScreen = false);
                });
                DatabaseHelper.instance
                    .updateDocumentLastAccessed(widget.document.id);
              },
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() => _currentPage = details.newPageNumber);
              },
            ),
          ),
          // Control bar (page count + rotate + fullscreen)
          if (!_isLoading && _pageCount > 0 && !_isFullScreen)
            Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen,
                            color: Colors.white70, size: 20),
                        onPressed: () =>
                            setState(() => _isFullScreen = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right,
                            color: Colors.white70, size: 20),
                        onPressed: () => setState(
                            () => _quarterTurns = (_quarterTurns + 1) % 4),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_currentPage / $_pageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Full-screen exit
          if (_isFullScreen)
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton(
                backgroundColor: Colors.black.withOpacity(0.5),
                elevation: 0,
                onPressed: () => setState(() => _isFullScreen = false),
                child: const Icon(Icons.fullscreen_exit,
                    color: Colors.white),
              ),
            ),
          // Loading screen
          if (_showLoadingScreen)
            AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Container(
                color: AppTheme.background,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _hoverAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _hoverAnimation.value),
                          child: child,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 90,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Opening your document...',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 48),
                      if (settings.showReadingTips)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _selectedTip,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white54,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
