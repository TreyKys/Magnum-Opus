import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/ai/gemini_file_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/chat/models/chat_session_model.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';

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
        final doc = await DatabaseHelper.instance
            .getDocumentById(attachedDocumentId);
        final skeleton = await DatabaseHelper.instance
            .getDocumentSkeleton(attachedDocumentId);

        final bool isPdf = doc?.fileType == 'pdf';
        final String? fileUri = doc?.fileUri;
        final bool hasFileUri = fileUri != null && fileUri.isNotEmpty;

        if (isPdf && hasFileUri) {
          final uploadedAt = doc!.fileUriUploadedAt;
          final bool isExpired = uploadedAt == null ||
              DateTime.now().difference(uploadedAt).inHours >= 47;

          if (isExpired) {
            _triggerBackgroundResync(doc);

            final resyncNotice = StandaloneMessage(
              id: _uuid.v4(),
              sessionId: sessionId,
              text: 'Re-syncing document with AI — using cached excerpts for this query.',
              isUser: false,
              timestamp: DateTime.now(),
            );
            await DatabaseHelper.instance
                .insertStandaloneMessage(resyncNotice.toMap());
            state = [...state, resyncNotice];

            final contextChunks = await DatabaseHelper.instance
                .getContextRichChunks(attachedDocumentId, text);
            if (contextChunks == 'DOCUMENT_NOT_READY') {
              await _appendNotReady();
              isSending = false;
              return;
            }
            aiText = await _ai.generateRAGResponse(
              contextChunks: contextChunks,
              userQuery: text,
              history: history,
              imageBytes: imageBytes,
              complexity: complexity,
              documentSkeleton: skeleton,
            );
          } else {
            // Valid File API path
            String? archiveChunks;
            if (doc.totalPages > 50) {
              final brainPages = doc.brainPages ?? [];
              final archive = await DatabaseHelper.instance
                  .getContextRichChunks(attachedDocumentId, text,
                      excludePages: brainPages);
              archiveChunks =
                  archive == 'DOCUMENT_NOT_READY' ? null : archive;
            }
            aiText = await _ai.generateRAGResponse(
              contextChunks: '',
              userQuery: text,
              history: history,
              imageBytes: imageBytes,
              complexity: complexity,
              documentSkeleton: skeleton,
              fileUri: fileUri,
              archiveChunks: archiveChunks,
            );
          }
        } else {
          // BM25 path (non-PDF or no fileUri)
          final contextChunks = await DatabaseHelper.instance
              .getContextRichChunks(attachedDocumentId, text);
          if (contextChunks == 'DOCUMENT_NOT_READY') {
            await _appendNotReady();
            isSending = false;
            return;
          }
          aiText = await _ai.generateRAGResponse(
            contextChunks: contextChunks,
            userQuery: text,
            history: history,
            imageBytes: imageBytes,
            complexity: complexity,
            documentSkeleton: skeleton,
          );
        }
      } else {
        // No document attached — general chat
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
        text: 'Something went wrong. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.instance.insertStandaloneMessage(errMsg.toMap());
      state = [...state, errMsg];
    } finally {
      isSending = false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _appendNotReady() async {
    final msg = StandaloneMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      text: 'This document is still being processed. Please wait a moment and try again.',
      isUser: false,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertStandaloneMessage(msg.toMap());
    state = [...state, msg];
  }

  void _triggerBackgroundResync(DocumentModel doc) {
    Future(() async {
      final bytes = await File(doc.filePath).readAsBytes();
      final Uint8List uploadBytes;
      final brainPages = doc.brainPages;
      if (doc.totalPages > 50 && brainPages != null && brainPages.isNotEmpty) {
        uploadBytes =
            await GeminiFileService.extractSpecificPages(bytes, brainPages);
      } else {
        uploadBytes = bytes;
      }
      final newUri =
          await GeminiFileService.uploadPdfWithRetry(uploadBytes, doc.title);
      await DatabaseHelper.instance
          .updateDocumentFileUri(doc.id, newUri, DateTime.now());
    }).catchError((_) {});
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

  Future<void> detachDocument(String sessionId) async {
    await DatabaseHelper.instance.updateStandaloneSession(
        sessionId, {'attached_document_id': null});
    await _loadSessions();
  }

  Future<void> restoreSession(String id) async {
    await DatabaseHelper.instance
        .updateStandaloneSession(id, {'is_archived': 0});
    await _loadSessions();
  }
}
