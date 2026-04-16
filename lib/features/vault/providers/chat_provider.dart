import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

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
    await _loadMessages(); // Reload — pinned messages survive
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

    // Record and display user message immediately
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
      // Step 1: Top-15 context fetch from SQLite
      final contextChunks =
          await DatabaseHelper.instance.getContextRichChunks(arg, query);

      // Step 2: Load global skeleton (macro-context)
      final skeleton = await DatabaseHelper.instance.getDocumentSkeleton(arg);

      // Step 3: Read current complexity level
      final complexity = ref.read(complexityProvider);

      // Step 4: Send to Gemini with full context
      final response = await _aiService.generateRAGResponse(
        contextChunks: contextChunks,
        userQuery: query,
        history: state.where((msg) => msg.id != userMessage.id).toList(),
        imageBytes: imageBytes,
        complexity: complexity,
        documentSkeleton: skeleton,
      );

      // Step 5: Record and display AI response
      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        documentId: arg,
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.instance.insertChatMessage(aiMessage.toMap());
      state = [...state, aiMessage];
    } catch (e) {
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        documentId: arg,
        text: 'Error communicating with intelligence module: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, errorMessage];
    } finally {
      isThinking = false;
    }
  }
}
