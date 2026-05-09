import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/ai/gemini_file_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';

final chatProvider = NotifierProvider.autoDispose
    .family<ChatNotifier, List<ChatMessage>, String>(
      (arg) => ChatNotifier(arg),
    );

class ChatNotifier extends Notifier<List<ChatMessage>> {
  final String arg; // documentId
  ChatNotifier(this.arg);

  final AiService _aiService = AiService();
  final Uuid _uuid = const Uuid();
  bool isThinking = false;

  @override
  List<ChatMessage> build() {
    _loadMessages();
    return [];
  }

  Future<void> _loadMessages() async {
    final data = await DatabaseHelper.instance.getChatHistory(arg);
    state = data.map((json) => ChatMessage.fromMap(json)).toList();
  }

  Future<void> clearChat() async {
    await DatabaseHelper.instance.clearChatHistory(arg);
    await _loadMessages();
  }

  Future<void> togglePin(String messageId, bool isPinned) async {
    await DatabaseHelper.instance.togglePinChatMessage(messageId, isPinned);
    state = state.map((msg) {
      if (msg.id == messageId) return msg.copyWith(isPinned: isPinned);
      return msg;
    }).toList();
  }

  Future<void> sendMessage(String query, {Uint8List? imageBytes}) async {
    if (query.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      documentId: arg,
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertChatMessage(userMessage.toMap());
    state = [...state, userMessage];
    isThinking = true;

    try {
      final doc = await DatabaseHelper.instance.getDocumentById(arg);
      final complexity = ref.read(complexityProvider);
      final skeleton = await DatabaseHelper.instance.getDocumentSkeleton(arg);
      final history = state.where((m) => m.id != userMessage.id).toList();

      final bool isPdf = doc?.fileType == 'pdf';
      final String? fileUri = doc?.fileUri;
      final bool hasFileUri = fileUri != null && fileUri.isNotEmpty;

      String response;

      if (isPdf && hasFileUri) {
        final uploadedAt = doc!.fileUriUploadedAt;
        final bool isExpired = uploadedAt == null ||
            DateTime.now().difference(uploadedAt).inHours >= 47;

        if (isExpired) {
          // Trigger background re-sync; fall back to BM25 for this query
          _triggerBackgroundResync(doc);

          final notice = ChatMessage(
            id: _uuid.v4(),
            documentId: arg,
            text: 'Re-syncing document with AI — using cached excerpts for this query. '
                'Future queries will use the full document.',
            isUser: false,
            timestamp: DateTime.now(),
          );
          await DatabaseHelper.instance.insertChatMessage(notice.toMap());
          state = [...state, notice];

          final chunks = await DatabaseHelper.instance
              .getContextRichChunks(arg, query);
          if (chunks == 'DOCUMENT_NOT_READY') {
            await _appendNotReady();
            return;
          }
          response = await _aiService.generateRAGResponse(
            contextChunks: chunks,
            userQuery: query,
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
                .getContextRichChunks(arg, query, excludePages: brainPages);
            archiveChunks =
                archive == 'DOCUMENT_NOT_READY' ? null : archive;
          }
          response = await _aiService.generateRAGResponse(
            contextChunks: '',
            userQuery: query,
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
        final chunks = await DatabaseHelper.instance
            .getContextRichChunks(arg, query);
        if (chunks == 'DOCUMENT_NOT_READY') {
          await _appendNotReady();
          return;
        }
        response = await _aiService.generateRAGResponse(
          contextChunks: chunks,
          userQuery: query,
          history: history,
          imageBytes: imageBytes,
          complexity: complexity,
          documentSkeleton: skeleton,
        );
      }

      await _appendAiMessage(response);
    } catch (e) {
      await _appendError();
    } finally {
      isThinking = false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _appendAiMessage(String text) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      documentId: arg,
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertChatMessage(msg.toMap());
    state = [...state, msg];
  }

  Future<void> _appendNotReady() async {
    const text =
        'This document is still being processed. Please wait a moment and try again.';
    final msg = ChatMessage(
      id: _uuid.v4(),
      documentId: arg,
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertChatMessage(msg.toMap());
    state = [...state, msg];
  }

  Future<void> _appendError() async {
    state = [
      ...state,
      ChatMessage(
        id: _uuid.v4(),
        documentId: arg,
        text: 'Something went wrong. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }

  /// Re-uploads the PDF brain in the background and updates the stored fileUri.
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
    }).catchError((_) {
      // Silent — next query will retry
    });
  }
}
