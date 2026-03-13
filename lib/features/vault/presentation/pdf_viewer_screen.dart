import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:myapp/core/database/database_helper.dart';
import 'package:myapp/features/vault/providers/chat_provider.dart';
import 'package:myapp/features/settings/providers/settings_provider.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String id;
  final String filePath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.id,
    required this.filePath,
    required this.title,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> with TickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
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

    // Defer reading settings until after the first frame
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

  void _showIntelSheet() {
    if (_isFullScreen) {
      setState(() {
        _isFullScreen = false;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final chatMessages = ref.watch(chatProvider(widget.id));
            final chatNotifier = ref.read(chatProvider(widget.id).notifier);

            // Auto-scroll to bottom when messages update
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_chatScrollController.hasClients) {
                _chatScrollController.animateTo(
                  _chatScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: chatMessages.length + (chatNotifier.isThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chatMessages.length && chatNotifier.isThinking) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
                                ),
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                              ),
                            );
                          }

                          final msg = chatMessages[index];
                          return Align(
                            alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: msg.isUser ? Colors.cyanAccent : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
                                  bottomLeft: !msg.isUser ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isUser ? Colors.black : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  chatNotifier.sendMessage(value);
                                  _chatController.clear();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "Ask the document...",
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF0A0A0A),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.cyanAccent),
                            onPressed: () {
                              if (_chatController.text.trim().isNotEmpty) {
                                chatNotifier.sendMessage(_chatController.text);
                                _chatController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _hoverController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        title: Text(
          widget.title,
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
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RotatedBox(
            quarterTurns: _quarterTurns,
            child: SfPdfViewer.file(
              File(widget.filePath),
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
                if (mounted) {
                  setState(() {
                    _showLoadingScreen = false;
                  });
                }
              });

                // According to Task 1 Requirement: Always update lastAccessed timestamp when a document is successfully opened.
                DatabaseHelper.instance.updateDocumentLastAccessed(widget.id);
              },
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() {
                  _currentPage = details.newPageNumber;
                });
              },
            ),
          ),
          if (!_isLoading && _pageCount > 0 && !_isFullScreen)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        onPressed: () {
                          setState(() {
                            _isFullScreen = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _quarterTurns = (_quarterTurns + 1) % 4;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_currentPage / $_pageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: FloatingActionButton(
                          mini: true,
                          elevation: 0,
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          onPressed: _showIntelSheet,
                          child: const Icon(Icons.auto_awesome, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isFullScreen)
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton(
                backgroundColor: Colors.black.withOpacity(0.5),
                elevation: 0,
                onPressed: () {
                  setState(() {
                    _isFullScreen = false;
                  });
                },
                child: const Icon(Icons.fullscreen_exit, color: Colors.white),
              ),
            ),
          if (_showLoadingScreen)
            AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Container(
                color: const Color(0xFF0A0A0A),
                child: Center(
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
                      if (settings.showReadingTips)
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
              ),
            ),
        ],
      ),
    );
  }
}
