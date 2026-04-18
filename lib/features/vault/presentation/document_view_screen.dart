import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;

import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';
import 'package:magnum_opus/features/vault/providers/chat_provider.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/services/export_service.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/settings/widgets/complexity_dial.dart';

// Reuse LaTeX syntax classes from pdf_viewer_screen
class _LatexSyntax extends m.InlineSyntax {
  _LatexSyntax() : super(r'\$(.+?)\$');
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

class _LatexBlockSyntax extends m.BlockSyntax {
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

class _LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  _LatexNode(this.attributes, this.textContent);
  @override
  InlineSpan build() => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(textContent,
            textStyle: const TextStyle(fontSize: 16, color: Colors.white)),
      );
}

class _LatexBlockNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  _LatexBlockNode(this.attributes, this.textContent);
  @override
  InlineSpan build() => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Math.tex(textContent,
              textStyle: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      );
}

class _LatexGenerator extends SpanNodeGeneratorWithTag {
  _LatexGenerator()
      : super(
            tag: 'latex',
            generator: (e, config, visitor) =>
                _LatexNode(e.attributes, e.textContent));
  @override
  SpanNode build() => _LatexNode(const {}, '');
}

class _LatexBlockGenerator extends SpanNodeGeneratorWithTag {
  _LatexBlockGenerator()
      : super(
            tag: 'latexBlock',
            generator: (e, config, visitor) =>
                _LatexBlockNode(e.attributes, e.textContent));
  @override
  SpanNode build() => _LatexBlockNode(const {}, '');
}

class DocumentViewScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const DocumentViewScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends ConsumerState<DocumentViewScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _contentKey = GlobalKey();

  bool _isIndexing = false;
  String _firstChunkPreview = '';

  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _selectedTip = '';
  bool _showLoadingScreen = true;

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

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
    'Magnum Opus uses a Swarm Engine for high-performance background extraction.',
    'The vault never drops a frame, keeping your UI 100% responsive.',
    'All data stays on your device. Zero external servers. Complete privacy.',
    'Magnum Opus leverages Isolate spawning to handle massive documents efficiently.',
    'Our custom SQLite schema ensures instant recovery even if interrupted.',
    'Background processes automatically retry if the app is unexpectedly closed.',
  ];

  @override
  void initState() {
    super.initState();

    _selectedTip = _tips[Random().nextInt(_tips.length)];

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _hoverAnimation = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();

    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final db = DatabaseHelper.instance;
    final chunks = await db.database.then((d) => d.query(
          'document_chunks',
          where: 'document_id = ?',
          whereArgs: [widget.document.id],
          orderBy: 'page_number ASC',
          limit: 1,
        ));

    String preview = '';
    if (chunks.isNotEmpty) {
      final text = chunks.first['extracted_text'] as String;
      preview = text.length > 800 ? '${text.substring(0, 800)}...' : text;
    }

    if (mounted) {
      setState(() {
        _firstChunkPreview = preview;
        _showLoadingScreen = preview.isEmpty; // Still loading if no content yet
      });

      if (!_showLoadingScreen) {
        DatabaseHelper.instance.updateDocumentLastAccessed(widget.document.id);
      }
    }
  }

  Future<Uint8List?> _captureContentScreen() async {
    try {
      final boundary = _contentKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
        onAdFailedToLoad: (_) {
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showIntelSheet() {
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
            final chatMessages = ref.watch(chatProvider(widget.document.id));
            final chatNotifier =
                ref.read(chatProvider(widget.document.id).notifier);
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
                    content: const Text('Supercharge the engine to continue.',
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
              final imageBytes = await _captureContentScreen();
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
                    // Header: energy + clear + complexity
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
                    // Compile Report bar
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
                                widget.document.title,
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
                    // Messages
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
                                  borderRadius: BorderRadius.circular(16)
                                      .copyWith(
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
                    // Input
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
                msg.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
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
                          _LatexGenerator(),
                          _LatexBlockGenerator()
                        ],
                        inlineSyntaxList: [_LatexSyntax()],
                        blockSyntaxList: [_LatexBlockSyntax()],
                      ),
                    ),
            ),
          ),
          if (msg.isUser)
            IconButton(
              icon: Icon(
                msg.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
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
    final vaultState = ref.watch(vaultProvider);
    _isIndexing = vaultState.indexingDocumentIds.contains(widget.document.id);

    // Once indexing finishes, reload preview
    if (!_isIndexing && _showLoadingScreen) {
      _loadPreview();
    }

    final fileTypeLabel = widget.document.fileType.toUpperCase();
    final fileTypeColor = _colorForType(widget.document.fileType);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
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
      ),
      body: Stack(
        children: [
          // Content
          RepaintBoundary(
            key: _contentKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: fileTypeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_iconForType(widget.document.fileType),
                              color: fileTypeColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.document.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: fileTypeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      fileTypeLabel,
                                      style: TextStyle(
                                        color: fileTypeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.document.fileSizeMb.toStringAsFixed(1)} MB',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.document.totalPages} chunks',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Content preview
                  if (_firstChunkPreview.isNotEmpty) ...[
                    const Text(
                      'CONTENT PREVIEW',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        _firstChunkPreview,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // Space for floating button
                ],
              ),
            ),
          ),
          // Intel button
          if (!_isIndexing)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16),
                      if (_isIndexing) ...[
                        const _PulsingDot(),
                        const SizedBox(width: 8),
                        const Text('Indexing...',
                            style: TextStyle(
                                color: AppTheme.accentBlueLight,
                                fontSize: 13)),
                        const SizedBox(width: 12),
                      ] else
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
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          // Loading / indexing screen
          if (_showLoadingScreen || _isIndexing)
            AnimatedOpacity(
              opacity: (_showLoadingScreen || _isIndexing) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Container(
                color: AppTheme.background,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _hoverAnimation,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _hoverAnimation.value),
                          child: child,
                        ),
                        child: Icon(
                          _iconForType(widget.document.fileType),
                          size: 80,
                          color: fileTypeColor,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _isIndexing
                            ? widget.document.fileType == 'audio'
                                ? 'Transcribing audio...'
                                : widget.document.fileType == 'url'
                                    ? 'Scraping content...'
                                    : 'Indexing document...'
                            : 'Loading...',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 40),
                      if (settings.showReadingTips)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _selectedTip,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  static Color _colorForType(String type) {
    switch (type) {
      case 'epub':
        return AppTheme.badgeEpub;
      case 'docx':
        return AppTheme.badgeDocx;
      case 'xlsx':
        return AppTheme.badgeXlsx;
      case 'pptx':
        return AppTheme.badgePptx;
      case 'csv':
        return AppTheme.badgeCsv;
      case 'txt':
        return AppTheme.badgeTxt;
      case 'audio':
        return AppTheme.badgeAudio;
      case 'url':
        return AppTheme.badgeUrl;
      default:
        return AppTheme.badgePdf;
    }
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'epub':
        return Icons.menu_book_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'csv':
        return Icons.grid_on_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      case 'audio':
        return Icons.headphones_outlined;
      case 'url':
        return Icons.language_outlined;
      default:
        return Icons.picture_as_pdf_outlined;
    }
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.3 + (_ctrl.value * 0.7),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.accentBlueLight,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
