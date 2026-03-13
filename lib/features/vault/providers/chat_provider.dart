import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/ai/ai_service.dart';
import 'package:myapp/core/database/database_helper.dart';
import 'package:myapp/features/vault/models/chat_message.dart';

final chatProvider = StateNotifierProvider.autoDispose.family<ChatNotifier, List<ChatMessage>, String>((ref, documentId) {
  return ChatNotifier(documentId);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final String documentId;
  final AiService _aiService = AiService();
  bool isThinking = false;

  ChatNotifier(this.documentId) : super([]);

  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    // Instantly add user message
    state = [...state, ChatMessage(text: query, isUser: true)];
    isThinking = true;

    try {
      // Step 1: Run getContextRichChunks from SQLite
      final contextChunks = await DatabaseHelper.instance.getContextRichChunks(documentId, query);

      // Step 2: Send payload to Gemini
      final response = await _aiService.generateRAGResponse(
        contextChunks: contextChunks,
        userQuery: query,
      );

      // Step 3: Display response
      state = [...state, ChatMessage(text: response, isUser: false)];
    } catch (e) {
      state = [...state, ChatMessage(text: "Error communicating with intelligence module: $e", isUser: false)];
    } finally {
      isThinking = false;
    }
  }
}
