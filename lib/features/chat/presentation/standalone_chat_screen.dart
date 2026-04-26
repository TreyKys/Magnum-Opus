import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/chat/models/chat_session_model.dart';
import 'package:magnum_opus/features/chat/providers/standalone_chat_provider.dart';
import 'package:magnum_opus/features/onboarding/providers/onboarding_provider.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/settings/widgets/complexity_dial.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/services/export_service.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';
import 'package:magnum_opus/features/settings/presentation/upgrade_screen.dart';

class StandaloneChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Uint8List? initialImageBytes;
  const StandaloneChatScreen({
    super.key,
    required this.sessionId,
    this.initialImageBytes,
  });

  @override
  ConsumerState<StandaloneChatScreen> createState() => _StandaloneChatScreenState();
}

class _StandaloneChatScreenState extends ConsumerState<StandaloneChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RewardedAd? _rewardedAd;
  bool _loadingAd = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
    if (widget.initialImageBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendImage(widget.initialImageBytes!);
      });
    }
  }

  void _sendImage(Uint8List bytes) {
    final energy = ref.read(energyProvider);
    if (energy <= 0) return;
    ref.read(energyProvider.notifier).consumeEnergy();
    ref.read(sessionMessagesProvider(widget.sessionId).notifier).sendMessage(
          'What\'s in this image?',
          imageBytes: bytes,
        );
    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    setState(() => _loadingAd = true);
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => setState(() { _rewardedAd = ad; _loadingAd = false; }),
        onAdFailedToLoad: (_) => setState(() => _loadingAd = false),
      ),
    );
  }

  void _showAd() {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadAd();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (_, __) => ref.read(energyProvider.notifier).refillEnergy(),
    );
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final energy = ref.read(energyProvider);
    if (energy <= 0) return;
    ref.read(energyProvider.notifier).consumeEnergy();
    final session = ref
        .read(standaloneChatProvider)
        .sessions
        .where((s) => s.id == widget.sessionId)
        .firstOrNull;
    ref.read(sessionMessagesProvider(widget.sessionId).notifier).sendMessage(
          text,
          attachedDocumentId: session?.attachedDocumentId,
        );
    _inputController.clear();
    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(sessionMessagesProvider(widget.sessionId));
    final energy = ref.watch(energyProvider);
    final displayName = ref.watch(onboardingProvider).displayName;
    final initials = _initials(displayName);

    // Get session info for title
    final sessionState = ref.watch(standaloneChatProvider);
    final session = sessionState.sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final hasDoc = session?.attachedDocumentId != null;

    ref.listen(sessionMessagesProvider(widget.sessionId), (_, __) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });

    // Export helper: convert StandaloneMessages to ChatMessages
    List<ChatMessage> toChatMessages(List<StandaloneMessage> msgs) => msgs
        .map((m) => ChatMessage(
              id: m.id,
              documentId: widget.sessionId,
              text: m.text,
              isUser: m.isUser,
              timestamp: m.timestamp,
            ))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session?.title ?? 'Chat',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              hasDoc
                  ? '${session!.attachedDocumentTitle ?? 'Document'} · RAG active'
                  : 'General chat',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              hasDoc ? Icons.link_off : Icons.attach_file,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: hasDoc ? 'Detach document' : 'Attach document',
            onPressed: () => hasDoc
                ? _detachDoc()
                : _showAttachSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: AppTheme.textSecondary, size: 20),
            tooltip: 'Export PDF',
            onPressed: messages.isEmpty
                ? null
                : () => ExportService.exportChatAsPdf(
                      context,
                      session?.title ?? 'Chat',
                      toChatMessages(messages),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const ComplexityMiniDial(),
          ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(isRag: hasDoc, docTitle: session?.attachedDocumentTitle)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: messages[i],
                      initials: initials,
                    ),
                  ),
          ),
          energy <= 0
              ? _NoEnergyBanner(
                  loadingAd: _loadingAd,
                  onWatchAd: _rewardedAd != null ? _showAd : null,
                )
              : _InputBar(
                  controller: _inputController,
                  energy: energy,
                  onSend: _send,
                ),
        ],
      ),
    );
  }

  void _detachDoc() {
    ref.read(standaloneChatProvider.notifier).detachDocument(widget.sessionId);
  }

  void _showAttachSheet(BuildContext context) {
    final docs = ref.read(vaultProvider).documents;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Attach Document',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No documents in vault yet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    return ListTile(
                      leading: Icon(
                        _docIcon(doc.fileType),
                        color: _docIconColor(doc.fileType),
                        size: 22,
                      ),
                      title: Text(
                        doc.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.fileType.toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(standaloneChatProvider.notifier)
                            .attachDocument(widget.sessionId, doc.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _docIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'docx': return Icons.description_outlined;
      case 'pptx': return Icons.slideshow_outlined;
      case 'xlsx': return Icons.table_chart_outlined;
      case 'epub': return Icons.menu_book_outlined;
      case 'audio': return Icons.audiotrack_outlined;
      case 'url': return Icons.link_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Color _docIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return AppTheme.badgePdf;
      case 'docx': return AppTheme.badgeDocx;
      case 'pptx': return AppTheme.badgePptx;
      case 'xlsx': return AppTheme.badgeXlsx;
      default: return AppTheme.textMuted;
    }
  }

  String _initials(String name) {
    if (name.isEmpty) return 'MO';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends ConsumerWidget {
  final StandaloneMessage message;
  final String initials;
  const _MessageBubble({required this.message, required this.initials});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complexity = ref.watch(complexityProvider);
    final depthLabel = complexityLabel(complexity);

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A3A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.accentBlue,
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final parsed = _parseSources(message.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'MAGNUM OPUS · $depthLabel DEPTH',
                style: const TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: MarkdownWidget(
                data: parsed.body,
                shrinkWrap: true,
                config: MarkdownConfig.darkConfig,
              ),
            ),
            for (final src in parsed.sources) _SourceChip(text: src),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  _ParsedMessage _parseSources(String text) {
    final pattern = RegExp(r'\[Source:[^\]]+\]', caseSensitive: false);
    final sources = pattern
        .allMatches(text)
        .map((m) => m.group(0)!
            .replaceAll(RegExp(r'^\[Source:\s*'), '')
            .replaceAll(']', '')
            .trim())
        .toList();
    return _ParsedMessage(body: text.replaceAll(pattern, '').trim(), sources: sources);
  }
}

class _ParsedMessage {
  final String body;
  final List<String> sources;
  const _ParsedMessage({required this.body, required this.sources});
}

class _SourceChip extends StatelessWidget {
  final String text;
  const _SourceChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.06),
        border: const Border(left: BorderSide(color: AppTheme.accentBlue, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Text('SRC',
              style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final int energy;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.energy, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: '$energy left',
                suffixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No energy banner ─────────────────────────────────────────────────────────

class _NoEnergyBanner extends StatelessWidget {
  final bool loadingAd;
  final VoidCallback? onWatchAd;
  const _NoEnergyBanner({required this.loadingAd, required this.onWatchAd});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('No queries left today',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          if (loadingAd)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
            )
          else
            TextButton(
              onPressed: onWatchAd,
              child: const Text('Watch Ad +2',
                  style: TextStyle(
                      color: AppTheme.accentBlueLight, fontWeight: FontWeight.w700)),
            ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpgradeScreen()),
            ),
            child: const Text('Upgrade',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isRag;
  final String? docTitle;
  const _EmptyState({required this.isRag, this.docTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppTheme.textMuted, size: 40),
            const SizedBox(height: 16),
            Text(
              isRag ? 'Ask about this document' : 'Ask me anything',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (docTitle != null) ...[
              const SizedBox(height: 8),
              Text(docTitle!,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
