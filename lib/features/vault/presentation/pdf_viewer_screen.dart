import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;

import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';
import 'package:magnum_opus/features/vault/providers/chat_provider.dart';
import 'package:magnum_opus/features/vault/services/export_service.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/settings/widgets/complexity_dial.dart';

// ─── LaTeX rendering (unchanged from v1) ─────────────────────────────────────

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

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen>
    with TickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final TextEditingController _chatController = TextEditingController();
  final GlobalKey _pdfViewerKey = GlobalKey();
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

  // Reading tips (preserved from v1, app-specific entries updated)
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
    'The Complexity Dial scales AI depth from ELI5 to full PhD — try it!',
    'Magnum Opus dynamically chunks document data to prevent memory leaks.',
    'Your reading progress and recent documents are intelligently tracked.',
    'Background processes automatically retry if the app is unexpectedly closed.',
    'Powered by Riverpod state management for flawless, reactive UI updates.',
  ];

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

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

  Future<Uint8List?> _capturePdfScreen() async {
    try {
      final boundary = _pdfViewerKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  void _loadRewardedAd() {
    const adUnitId = 'ca-app-pub-3940256099942544/5224354917';
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoaded = false;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _isAdLoaded = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (_) => _isAdLoaded = false,
      ),
    );
  }

  void _showIntelSheet() {
    if (_isFullScreen) setState(() => _isFullScreen = false);
    if (!_isAdLoaded) _loadRewardedAd();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final chatMessages = ref.watch(chatProvider(widget.id));
            final chatNotifier =
                ref.read(chatProvider(widget.id).notifier);
            final energy = ref.watch(energyProvider);
            final energyNotifier = ref.read(energyProvider.notifier);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_chatScrollController.hasClients) {
                _chatScrollController.animateTo(
                  _chatScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });

            Future<void> handleSend(String value) async {
              if (value.trim().isEmpty) return;
              if (energy <= 0) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Intel Depleted',
                        style: TextStyle(color: AppTheme.accentBlueLight)),
                    content: const Text(
                        'Supercharge the engine to continue.',
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (_isAdLoaded && _rewardedAd != null) {
                            _rewardedAd?.show(
                              onUserEarnedReward: (_, __) =>
                                  energyNotifier.refillEnergy(),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Engine charging... try again in a moment.')),
                            );
                            _loadRewardedAd();
                          }
                        },
                        child: const Text('SUPERCHARGE',
                            style: TextStyle(
                                color: AppTheme.accentBlueLight,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                return;
              }
              final imageBytes = await _capturePdfScreen();
              await energyNotifier.consumeEnergy();
              chatNotifier.sendMessage(value, imageBytes: imageBytes);
              _chatController.clear();
            }

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    // Header: energy + complexity + clear
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt,
                                      color: AppTheme.accentBlueLight,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$energy Energy',
                                    style: const TextStyle(
                                      color: AppTheme.accentBlueLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white54),
                                onPressed: () => chatNotifier.clearChat(),
                                tooltip: 'Clear Chat',
                              ),
                            ],
                          ),
                          const ComplexityMiniDial(),
                        ],
                      ),
                    ),
                    // Compile Report bar (only when messages exist)
                    if (chatMessages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        color: AppTheme.surfaceVariant,
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined,
                                color: AppTheme.textMuted, size: 14),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Compile this thread into a report',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => ExportService.exportChatAsPdf(
                                context,
                                widget.title,
                                chatMessages,
                              ),
                              child: const Text(
                                'Export PDF',
                                style: TextStyle(
                                  color: AppTheme.accentBlueLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(color: AppTheme.border, height: 1),
                    // Messages list
                    Expanded(
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: chatMessages.length +
                            (chatNotifier.isThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chatMessages.length &&
                              chatNotifier.isThinking) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(16).copyWith(
                                          bottomLeft: Radius.zero),
                                ),
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              ),
                            );
                          }
                          final msg = chatMessages[index];
                          return _buildMessageBubble(msg, chatNotifier);
                        },
                      ),
                    ),
                    // Input bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(
                            top: BorderSide(
                                color: AppTheme.border, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: handleSend,
                              decoration: InputDecoration(
                                hintText: 'Ask the document...',
                                hintStyle: const TextStyle(
                                    color: Colors.white54),
                                filled: true,
                                fillColor: AppTheme.background,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppTheme.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppTheme.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppTheme.accentBlue),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send,
                                color: AppTheme.accentBlue),
                            onPressed: () =>
                                handleSend(_chatController.text),
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

  Widget _buildMessageBubble(ChatMessage msg, ChatNotifier chatNotifier) {
    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isUser)
            IconButton(
              icon: Icon(
                msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: msg.isPinned
                    ? AppTheme.accentBlueLight
                    : Colors.white38,
                size: 18,
              ),
              onPressed: () =>
                  chatNotifier.togglePin(msg.id, !msg.isPinned),
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? AppTheme.accentBlue
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: msg.isUser
                      ? Radius.zero
                      : const Radius.circular(16),
                  bottomLeft: !msg.isUser
                      ? Radius.zero
                      : const Radius.circular(16),
                ),
              ),
              child: msg.isUser
                  ? Text(msg.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15))
                  : MarkdownWidget(
                      data: msg.text,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      config: MarkdownConfig.darkConfig,
                      markdownGenerator: MarkdownGenerator(
                        generators: [
                          LatexGenerator(),
                          LatexBlockGenerator()
                        ],
                        inlineSyntaxList: [LatexSyntax()],
                        blockSyntaxList: [LatexBlockSyntax()],
                      ),
                    ),
            ),
          ),
          if (msg.isUser)
            IconButton(
              icon: Icon(
                msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: msg.isPinned
                    ? AppTheme.accentBlueLight
                    : Colors.white54,
                size: 18,
              ),
              onPressed: () =>
                  chatNotifier.togglePin(msg.id, !msg.isPinned),
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _hoverController.dispose();
    _fadeController.dispose();
    _rewardedAd?.dispose();
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
      body: Stack(
        children: [
          // PDF Viewer
          RotatedBox(
            quarterTurns: _quarterTurns,
            child: RepaintBoundary(
              key: _pdfViewerKey,
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
                    if (mounted) setState(() => _showLoadingScreen = false);
                  });
                  DatabaseHelper.instance
                      .updateDocumentLastAccessed(widget.id);
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  setState(() => _currentPage = details.newPageNumber);
                },
              ),
            ),
          ),
          // Control bar
          if (!_isLoading && _pageCount > 0 && !_isFullScreen)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.fullscreen,
                            color: Colors.white70),
                        onPressed: () =>
                            setState(() => _isFullScreen = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right,
                            color: Colors.white70),
                        onPressed: () => setState(
                            () => _quarterTurns = (_quarterTurns + 1) % 4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_currentPage / $_pageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: FloatingActionButton(
                          mini: true,
                          elevation: 0,
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          onPressed: _showIntelSheet,
                          child: const Icon(Icons.auto_awesome),
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
                child: const Icon(Icons.fullscreen_exit, color: Colors.white),
              ),
            ),
          // Loading screen with tips (preserved from v1)
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40.0),
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
