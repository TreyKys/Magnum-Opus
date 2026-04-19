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

// ─── LaTeX rendering (identical to pdf_viewer_screen) ────────────────────────

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
        child: Padding(
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

// ─── Screen ───────────────────────────────────────────────────────────────────

class DocumentViewScreen extends ConsumerStatefulWidget {
  final DocumentModel document;
  const DocumentViewScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends ConsumerState<DocumentViewScreen>
    with TickerProviderStateMixin {
  // ── Content state ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _chunks = [];
  bool _isContentLoaded = false;
  bool _showLoadingScreen = true;

  // ── Slide viewer ───────────────────────────────────────────────────────────
  int _currentSlide = 0;
  final PageController _slideController = PageController();

  // ── Chat / intel sheet ─────────────────────────────────────────────────────
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _contentKey = GlobalKey();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _selectedTip = '';

  // ── Ads ────────────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  static const List<String> _tips = [
    'Use active recall and spaced repetition to remember document content.',
    'Highlight sparingly — it helps important text stand out more effectively.',
    'Read the conclusion first to understand the author\'s destination.',
    'Skim headings before reading to build a mental map of the text.',
    'Summarize each section in your own words to improve comprehension.',
    'Take breaks every 25 minutes to maintain peak cognitive focus.',
    'Look up unfamiliar words immediately to avoid losing context.',
    'Discussing what you read with others solidifies your understanding.',
    'Ask questions of the text as you read to stay actively engaged.',
    'Magnum Opus uses Isolate spawning to handle massive documents efficiently.',
    'The vault never drops a frame, keeping your UI 100% responsive.',
    'All data stays on your device. Zero external servers. Complete privacy.',
    'Our custom SQLite schema ensures instant recovery even if interrupted.',
    'Background processes automatically retry if the app is unexpectedly closed.',
    'The Complexity Dial scales from ELI5 to expert-level — try it!',
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    final chunks =
        await DatabaseHelper.instance.getAllDocumentChunks(widget.document.id);
    if (!mounted) return;
    setState(() {
      _chunks = chunks;
      _isContentLoaded = true;
      if (chunks.isNotEmpty) {
        _showLoadingScreen = false;
        DatabaseHelper.instance
            .updateDocumentLastAccessed(widget.document.id);
      }
    });
  }

  Future<Uint8List?> _captureContentScreen() async {
    try {
      final boundary = _contentKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
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
          _rewardedAd?.fullScreenContentCallback =
              FullScreenContentCallback(
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

  // ── Intel sheet ────────────────────────────────────────────────────────────

  void _showIntelSheet() {
    if (!_isAdLoaded) _loadRewardedAd();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (sheetContext, ref, _) {
            final chatMessages =
                ref.watch(chatProvider(widget.document.id));
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
                  context: sheetContext,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Out of Energy',
                        style:
                            TextStyle(color: AppTheme.accentBlueLight)),
                    content: const Text(
                        'Watch an ad to recharge and continue.',
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
                                      'Ad loading — try again in a moment.')),
                            );
                            _loadRewardedAd();
                          }
                        },
                        child: const Text('WATCH AD',
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
              heightFactor: 0.88,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(sheetContext).viewInsets.bottom),
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
                    // Header row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.bolt,
                                    color: AppTheme.accentBlueLight,
                                    size: 18),
                                const SizedBox(width: 4),
                                Text('$energy Energy',
                                    style: const TextStyle(
                                      color: AppTheme.accentBlueLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    )),
                              ]),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white54),
                                onPressed: chatNotifier.clearChat,
                                tooltip: 'Clear',
                              ),
                            ],
                          ),
                          const ComplexityMiniDial(),
                        ],
                      ),
                    ),
                    // Compile Report bar
                    if (chatMessages.isNotEmpty)
                      _CompileReportBar(
                        title: widget.document.title,
                        messages: chatMessages,
                        sheetContext: sheetContext,
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
                                margin:
                                    const EdgeInsets.only(bottom: 16),
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
                          return _buildMessageBubble(
                              chatMessages[index], chatNotifier);
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
                                hintText:
                                    'Ask about this document...',
                                hintStyle: const TextStyle(
                                    color: Colors.white38),
                                filled: true,
                                fillColor: AppTheme.background,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppTheme.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppTheme.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(24),
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

  Widget _buildMessageBubble(
      ChatMessage msg, ChatNotifier chatNotifier) {
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
                      physics:
                          const NeverScrollableScrollPhysics(),
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
    _slideController.dispose();
    _hoverController.dispose();
    _fadeController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final vaultState = ref.watch(vaultProvider);
    final isIndexing =
        vaultState.indexingDocumentIds.contains(widget.document.id);

    // When indexing finishes, reload chunks once.
    ref.listen<VaultState>(vaultProvider, (prev, next) {
      final was = prev?.indexingDocumentIds
              .contains(widget.document.id) ??
          false;
      final now =
          next.indexingDocumentIds.contains(widget.document.id);
      if (was && !now && _chunks.isEmpty) _loadChunks();
    });

    final typeColor = _colorForType(widget.document.fileType);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(typeColor),
      body: Stack(
        children: [
          // ── Main content ───────────────────────────────────────────
          RepaintBoundary(
            key: _contentKey,
            child: _isContentLoaded && _chunks.isNotEmpty
                ? _buildContent()
                : const SizedBox.shrink(),
          ),

          // ── Intel FAB ──────────────────────────────────────────────
          if (!isIndexing && !_showLoadingScreen)
            Positioned(
              bottom: 28,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'intel_fab_doc',
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                elevation: 6,
                onPressed: _showIntelSheet,
                child: const Icon(Icons.auto_awesome, size: 22),
              ),
            ),

          // ── Loading overlay ────────────────────────────────────────
          if (_showLoadingScreen || isIndexing)
            AnimatedOpacity(
              opacity: (_showLoadingScreen || isIndexing) ? 1.0 : 0.0,
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
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        isIndexing
                            ? widget.document.fileType == 'audio'
                                ? 'Transcribing audio...'
                                : widget.document.fileType == 'url'
                                    ? 'Scraping content...'
                                    : 'Reading document...'
                            : 'Loading...',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 40),
                      if (settings.showReadingTips)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40),
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

  PreferredSizeWidget _buildAppBar(Color typeColor) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.document.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (_chunks.isNotEmpty)
            Text(
              '${_chunks.length} sections · ${widget.document.fileSizeMb.toStringAsFixed(1)} MB',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
            ),
        ],
      ),
      actions: [
        Padding(
          padding:
              const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.document.fileType.toUpperCase(),
              style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Content routing ────────────────────────────────────────────────────────

  Widget _buildContent() {
    switch (widget.document.fileType) {
      case 'xlsx':
      case 'csv':
        return _buildTableViewer();
      case 'pptx':
        return _buildSlideViewer();
      default:
        return _buildTextReader();
    }
  }

  // ── Text reader (epub, docx, txt, url, audio) ──────────────────────────────

  Widget _buildTextReader() {
    final type = widget.document.fileType;
    return CustomScrollView(
      slivers: [
        // Optional type-specific banner
        if (type == 'audio' || type == 'url')
          SliverToBoxAdapter(child: _buildTypeBanner(type)),
        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final text =
                    _chunks[index]['extracted_text'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.72,
                      color: Color(0xFFE2E2E2),
                      letterSpacing: 0.15,
                    ),
                  ),
                );
              },
              childCount: _chunks.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBanner(String type) {
    final isAudio = type == 'audio';
    final color = _colorForType(type);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(isAudio ? Icons.mic_none : Icons.language_outlined,
              color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAudio
                  ? 'Auto-transcribed from audio'
                  : widget.document.filePath.startsWith('http')
                      ? 'Scraped from ${widget.document.filePath}'
                      : 'Web content',
              style: TextStyle(color: color, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Table viewer (xlsx, csv) ───────────────────────────────────────────────

  Widget _buildTableViewer() {
    final isCsv = widget.document.fileType == 'csv';
    final List<String> headers = [];
    final List<List<String>> rows = [];

    for (final chunk in _chunks) {
      final text = chunk['extracted_text'] as String;
      for (final line in text.split('\n')) {
        if (line.trim().isEmpty) continue;
        if (!isCsv && line.startsWith('---')) continue;

        final cells = isCsv
            ? _parseCsvLine(line)
            : line.split('\t').map((c) => c.trim()).toList();

        if (cells.isEmpty || cells.every((c) => c.isEmpty)) continue;

        if (headers.isEmpty) {
          headers.addAll(cells);
        } else {
          final padded = List<String>.generate(
            headers.length,
            (i) => i < cells.length ? cells[i] : '',
          );
          rows.add(padded);
        }
      }
    }

    if (headers.isEmpty && rows.isEmpty) return _buildEmptyState();

    final displayHeaders =
        headers.isNotEmpty ? headers : ['Column 1'];
    final cappedRows = rows.take(1000).toList();

    return Column(
      children: [
        // Info bar
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surfaceVariant,
          child: Row(children: [
            Icon(_iconForType(widget.document.fileType),
                color: _colorForType(widget.document.fileType),
                size: 15),
            const SizedBox(width: 8),
            Text(
              '${cappedRows.length} rows · ${displayHeaders.length} columns'
              '${rows.length > 1000 ? ' (showing first 1 000)' : ''}',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
          ]),
        ),
        // Scrollable table
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppTheme.surface),
                  dividerThickness: 0.5,
                  horizontalMargin: 14,
                  columnSpacing: 20,
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 56,
                  columns: displayHeaders
                      .map((h) => DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text(
                                h,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                  rows: cappedRows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        i.isEven
                            ? AppTheme.background
                            : AppTheme.surface
                                .withOpacity(0.6),
                      ),
                      cells: row
                          .map((cell) => DataCell(SizedBox(
                                width: 130,
                                child: Text(
                                  cell,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              )))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  // ── Slide viewer (pptx) ───────────────────────────────────────────────────

  Widget _buildSlideViewer() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _slideController,
            itemCount: _chunks.length,
            onPageChanged: (i) => setState(() => _currentSlide = i),
            itemBuilder: (context, index) {
              final text =
                  _chunks[index]['extracted_text'] as String;
              final content =
                  text.replaceFirst(RegExp(r'^Slide \d+:\s*'), '');

              return Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slide header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue
                              .withOpacity(0.12),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),
                          border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.accentBlue
                                      .withOpacity(0.25))),
                        ),
                        child: Row(children: [
                          const Icon(Icons.slideshow_outlined,
                              color: AppTheme.accentBlueLight,
                              size: 15),
                          const SizedBox(width: 8),
                          Text(
                            'Slide ${index + 1} / ${_chunks.length}',
                            style: const TextStyle(
                              color: AppTheme.accentBlueLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      ),
                      // Slide content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            content,
                            style: const TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 16,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Dot indicators
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildDots(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDots() {
    final n = _chunks.length;
    if (n <= 1) return [];

    Widget dot(int i) => GestureDetector(
          onTap: () => _slideController.animateToPage(i,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _currentSlide ? 20 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _currentSlide
                  ? AppTheme.accentBlue
                  : AppTheme.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );

    Widget ellipsis() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: const Text('···',
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        );

    if (n <= 7) return List.generate(n, dot);

    // Condensed indicators for large decks
    final widgets = <Widget>[];
    widgets.add(dot(0));
    if (_currentSlide > 2) widgets.add(ellipsis());
    for (int i = (_currentSlide - 1).clamp(1, n - 2);
        i <= (_currentSlide + 1).clamp(1, n - 2);
        i++) {
      widgets.add(dot(i));
    }
    if (_currentSlide < n - 3) widgets.add(ellipsis());
    widgets.add(dot(n - 1));
    return widgets;
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForType(widget.document.fileType),
                color: AppTheme.textMuted, size: 52),
            const SizedBox(height: 20),
            const Text('No content extracted yet',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('The document may still be processing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Color _colorForType(String type) {
    switch (type) {
      case 'epub':  return AppTheme.badgeEpub;
      case 'docx':  return AppTheme.badgeDocx;
      case 'xlsx':  return AppTheme.badgeXlsx;
      case 'pptx':  return AppTheme.badgePptx;
      case 'csv':   return AppTheme.badgeCsv;
      case 'txt':   return AppTheme.badgeTxt;
      case 'audio': return AppTheme.badgeAudio;
      case 'url':   return AppTheme.badgeUrl;
      default:      return AppTheme.badgePdf;
    }
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'epub':  return Icons.menu_book_outlined;
      case 'docx':  return Icons.description_outlined;
      case 'xlsx':  return Icons.table_chart_outlined;
      case 'pptx':  return Icons.slideshow_outlined;
      case 'csv':   return Icons.grid_on_outlined;
      case 'txt':   return Icons.text_snippet_outlined;
      case 'audio': return Icons.headphones_outlined;
      case 'url':   return Icons.language_outlined;
      default:      return Icons.picture_as_pdf_outlined;
    }
  }
}

// ─── Compile Report Bar ───────────────────────────────────────────────────────

class _CompileReportBar extends StatefulWidget {
  final String title;
  final List<ChatMessage> messages;
  final BuildContext sheetContext;

  const _CompileReportBar({
    required this.title,
    required this.messages,
    required this.sheetContext,
  });

  @override
  State<_CompileReportBar> createState() => _CompileReportBarState();
}

class _CompileReportBarState extends State<_CompileReportBar> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceVariant,
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined,
              color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Compile this thread into a report',
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentBlueLight,
                  ),
                )
              : TextButton(
                  onPressed: _handleExport,
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
    );
  }

  Future<void> _handleExport() async {
    setState(() => _exporting = true);
    try {
      await ExportService.exportChatAsPdf(
        widget.sheetContext,
        widget.title,
        widget.messages,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ─── Pulsing dot ─────────────────────────────────────────────────────────────

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
