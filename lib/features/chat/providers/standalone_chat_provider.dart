import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/chat/models/chat_session_model.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class StandaloneChatState {
  final List<ChatSessionModel> sessions;
  final bool isLoading;

  const StandaloneChatState({
    this.sessions = const [],
    this.isLoading = false,
  });

  StandaloneChatState copyWith({
    List<ChatSessionModel>? sessions,
    bool? isLoading,
  }) {
    return StandaloneChatState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Per-session messages provider ───────────────────────────────────────────

final sessionMessagesProvider = NotifierProvider.autoDispose
    .family<SessionMessagesNotifier, List<StandaloneMessage>, String>(
        (arg) => SessionMessagesNotifier(arg));

class SessionMessagesNotifier
    extends Notifier<List<StandaloneMessage>> {
  final String sessionId;
  bool isSending = false;
  SessionMessagesNotifier(this.sessionId);

  final _uuid = const Uuid();
  final _ai = AiService();

  @override
  List<StandaloneMessage> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getSessionMessages(sessionId);
    state = rows.map(StandaloneMessage.fromMap).toList();
  }

  Future<void> sendMessage(
    String text, {
    Uint8List? imageBytes,
    String? attachedDocumentId,
  }) async {
    if (text.trim().isEmpty) return;
    isSending = true;

    final userMsg = StandaloneMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertStandaloneMessage(userMsg.toMap());
    state = [...state, userMsg];

    // Update session last_message_at
    await DatabaseHelper.instance.updateStandaloneSession(sessionId, {
      'last_message_at': userMsg.timestamp.toIso8601String(),
    });

    // Auto-title from first user message
    final sessions = await DatabaseHelper.instance.getAllStandaloneSessions();
    final session =
        sessions.where((s) => s['id'] == sessionId).firstOrNull;
    if (session != null &&
        (session['title'] as String).startsWith('Session ')) {
      final preview = text.trim().length > 40
          ? '${text.trim().substring(0, 40)}…'
          : text.trim();
      await DatabaseHelper.instance.updateStandaloneSession(
          sessionId, {'title': preview});
    }

    try {
      final complexity = ref.read(complexityProvider);
      final history = state
          .where((m) => m.id != userMsg.id)
          .map((m) => ChatMessage(
                id: m.id,
                documentId: sessionId,
                text: m.text,
                isUser: m.isUser,
                timestamp: m.timestamp,
              ))
          .toList();

      String aiText;
      if (attachedDocumentId != null) {
        final contextChunks = await DatabaseHelper.instance
            .getContextRichChunks(attachedDocumentId, text);
        final skeleton = await DatabaseHelper.instance
            .getDocumentSkeleton(attachedDocumentId);
        aiText = await _ai.generateRAGResponse(
          contextChunks: contextChunks,
          userQuery: text,
          history: history,
          imageBytes: imageBytes,
          complexity: complexity,
          documentSkeleton: skeleton,
        );
      } else {
        aiText = await _ai.generalChat(
          query: text,
          history: history,
          complexity: complexity,
          imageBytes: imageBytes,
        );
      }

      final aiMsg = StandaloneMessage(
        id: _uuid.v4(),
        sessionId: sessionId,
        text: aiText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.instance.insertStandaloneMessage(aiMsg.toMap());
      await DatabaseHelper.instance.updateStandaloneSession(sessionId, {
        'last_message_at': aiMsg.timestamp.toIso8601String(),
      });
      state = [...state, aiMsg];
    } catch (e) {
      final errMsg = StandaloneMessage(
        id: _uuid.v4(),
        sessionId: sessionId,
        text: 'Error: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.instance.insertStandaloneMessage(errMsg.toMap());
      state = [...state, errMsg];
    } finally {
      isSending = false;
    }
  }
}

// ─── Session list provider ────────────────────────────────────────────────────

final standaloneChatProvider =
    NotifierProvider<StandaloneChatNotifier, StandaloneChatState>(
        () => StandaloneChatNotifier());

class StandaloneChatNotifier extends Notifier<StandaloneChatState> {
  static const int _maxFreeSessions = 5;
  final _uuid = const Uuid();

  @override
  StandaloneChatState build() {
    _loadSessions();
    return const StandaloneChatState(isLoading: true);
  }

  Future<void> _loadSessions() async {
    final rows = await DatabaseHelper.instance.getAllStandaloneSessions();
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
    state = StandaloneChatState(sessions: sessions);
  }

  Future<void> reload() => _loadSessions();

  /// Creates a new session. Returns the new session id, or null if limit reached.
  Future<String?> createSession({String? attachedDocumentId}) async {
    final count = await DatabaseHelper.instance.countActiveSessions();
    if (count >= _maxFreeSessions) return null;

    final id = _uuid.v4();
    final n = count + 1;
    final session = ChatSessionModel(
      id: id,
      title: 'Session $n',
      createdAt: DateTime.now(),
      attachedDocumentId: attachedDocumentId,
    );
    await DatabaseHelper.instance.insertStandaloneSession(session.toMap());
    await _loadSessions();
    // Consume a query slot
    await ref.read(energyProvider.notifier).consumeEnergy();
    return id;
  }

  Future<void> renameSession(String id, String title) async {
    await DatabaseHelper.instance
        .updateStandaloneSession(id, {'title': title.trim()});
    await _loadSessions();
  }

  Future<void> pinSession(String id, bool pinned) async {
    await DatabaseHelper.instance
        .updateStandaloneSession(id, {'is_pinned': pinned ? 1 : 0});
    await _loadSessions();
  }

  Future<void> archiveSession(String id) async {
    await DatabaseHelper.instance
        .updateStandaloneSession(id, {'is_archived': 1});
    await _loadSessions();
  }

  Future<void> deleteSession(String id) async {
    await DatabaseHelper.instance.deleteStandaloneSession(id);
    await _loadSessions();
  }

  Future<void> attachDocument(String sessionId, String documentId) async {
    await DatabaseHelper.instance.updateStandaloneSession(
        sessionId, {'attached_document_id': documentId});
    await _loadSessions();
  }
}
