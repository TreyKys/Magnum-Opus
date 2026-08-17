import 'package:flutter/material.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/chat/models/chat_session_model.dart';
import 'package:magnum_opus/features/chat/presentation/standalone_chat_screen.dart';

class ArchivedSessionsScreen extends StatefulWidget {
  const ArchivedSessionsScreen({super.key});

  @override
  State<ArchivedSessionsScreen> createState() => _ArchivedSessionsScreenState();
}

class _ArchivedSessionsScreenState extends State<ArchivedSessionsScreen> {
  List<ChatSessionModel> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance.getArchivedSessions();
    final sessions = <ChatSessionModel>[];
    for (final row in rows) {
      final preview = await DatabaseHelper.instance
          .getSessionPreviewMessages(row['id'] as String);
      sessions.add(ChatSessionModel.fromMap(
        row,
        recentMessages: preview.reversed
            .map(StandaloneMessage.fromMap)
            .toList(),
      ));
    }
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  Future<void> _restore(String id) async {
    await DatabaseHelper.instance.updateStandaloneSession(id, {'is_archived': 0});
    await _load();
  }

  Future<void> _delete(String id) async {
    await DatabaseHelper.instance.deleteStandaloneSession(id);
    await _load();
  }

  void _showOptions(BuildContext context, ChatSessionModel session) {
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
                  color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.unarchive_outlined, color: AppTheme.accentLight),
              title: const Text('Restore session', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _restore(session.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: AppTheme.textSecondary),
              title: const Text('Open session', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StandaloneChatScreen(sessionId: session.id)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.danger),
              title: const Text('Delete permanently', style: TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, session);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChatSessionModel session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete permanently?',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          '"${session.title}" will be permanently deleted.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: AppTheme.textPrimary),
            onPressed: () {
              Navigator.pop(ctx);
              _delete(session.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Archived Sessions',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inventory_2_outlined,
                            color: AppTheme.textMuted, size: 48),
                        SizedBox(height: 16),
                        Text('No archived sessions',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        Text(
                          'Sessions you archive will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _sessions.length,
                  itemBuilder: (_, i) {
                    final session = _sessions[i];
                    final hasDoc = session.attachedDocumentId != null;
                    final preview = session.recentMessages.isNotEmpty
                        ? session.recentMessages.last.text
                        : 'No messages yet';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showOptions(context, session),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textPrimary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    hasDoc
                                        ? Icons.description_outlined
                                        : Icons.chat_bubble_outline,
                                    color: AppTheme.textMuted,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        hasDoc
                                            ? 'RAG · ${session.attachedDocumentTitle ?? 'Document'}'
                                            : 'General chat',
                                        style: const TextStyle(
                                            color: AppTheme.textMuted, fontSize: 10),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _restore(session.id),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6)),
                                  child: const Text('Restore',
                                      style: TextStyle(
                                          color: AppTheme.accentLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
