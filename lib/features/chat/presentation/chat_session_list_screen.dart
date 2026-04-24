import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/chat/models/chat_session_model.dart';
import 'package:magnum_opus/features/chat/presentation/standalone_chat_screen.dart';
import 'package:magnum_opus/features/chat/providers/standalone_chat_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';

class ChatSessionListScreen extends ConsumerWidget {
  const ChatSessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(standaloneChatProvider);
    final sessions = state.sessions;
    final atLimit = sessions.length >= 5;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        onPressed: () => _newSession(context, ref, atLimit),
        child: const Icon(Icons.add),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
          : sessions.isEmpty
              ? _EmptyState(onNew: () => _newSession(context, ref, false))
              : Column(
                  children: [
                    if (atLimit) _LimitBanner(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: sessions.length,
                        itemBuilder: (_, i) => _SessionCard(
                          session: sessions[i],
                          onTap: () => _openSession(context, sessions[i].id),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _newSession(BuildContext context, WidgetRef ref, bool atLimit) async {
    if (atLimit) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Session limit reached',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: const Text(
            'You have 5 active sessions (free tier). Delete or archive one to continue.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppTheme.accentBlueLight)),
            ),
          ],
        ),
      );
      return;
    }
    final id = await ref.read(standaloneChatProvider.notifier).createSession();
    if (id != null && context.mounted) {
      _openSession(context, id);
    }
  }

  void _openSession(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StandaloneChatScreen(sessionId: id)),
    ).then((_) {
      // Refresh session list on return
    });
  }
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends ConsumerWidget {
  final ChatSessionModel session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDoc = session.attachedDocumentId != null;
    final preview = session.recentMessages.isNotEmpty
        ? session.recentMessages.last.text
        : 'No messages yet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: () => _showOptions(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDoc ? Icons.description_outlined : Icons.chat_bubble_outline,
                    color: AppTheme.accentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ),
                          if (session.isPinned)
                            const Icon(Icons.push_pin, color: AppTheme.accentBlue, size: 14),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDoc
                            ? 'RAG · ${session.attachedDocumentTitle ?? 'Document'}'
                            : 'General chat',
                        style: const TextStyle(color: AppTheme.accentBlueLight, fontSize: 10),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(standaloneChatProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                session.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: AppTheme.accentBlueLight,
              ),
              title: Text(session.isPinned ? 'Unpin' : 'Pin',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                notifier.pinSession(session.id, !session.isPinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline, color: Colors.white70),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRename(context, notifier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: Colors.white70),
              title: const Text('Archive', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                notifier.archiveSession(session.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
              title: const Text('Delete', style: TextStyle(color: Color(0xFFFF5252))),
              onTap: () {
                Navigator.pop(context);
                notifier.deleteSession(session.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRename(BuildContext context, StandaloneChatNotifier notifier) {
    final ctrl = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rename session',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.accentBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) notifier.renameSession(session.id, name);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Limit banner ─────────────────────────────────────────────────────────────

class _LimitBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.accentBlueLight, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '5 / 5 sessions used (free tier). Archive or delete one to start new.',
              style: TextStyle(color: AppTheme.accentBlueLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppTheme.textMuted, size: 52),
            const SizedBox(height: 20),
            const Text('No chat sessions yet',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Start a general conversation or attach a document for RAG-powered answers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Session', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onNew,
            ),
          ],
        ),
      ),
    );
  }
}
