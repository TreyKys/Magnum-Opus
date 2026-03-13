import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

final chatProvider = NotifierProvider.autoDispose.family<ChatNotifier, List<ChatMessage>, String>(
  (arg) => ChatNotifier(arg),
);

class ChatNotifier extends Notifier<List<ChatMessage>> {
  final String arg;
  ChatNotifier(this.arg);

  final AiService _aiService = AiService();
  bool isThinking = false;

  @override
  List<ChatMessage> build() {
    return [];
  }

  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    // Instantly add user message
    state = [...state, ChatMessage(text: query, isUser: true)];
    isThinking = true;

    try {
      // Step 1: Run getContextRichChunks from SQLite
      final contextChunks = await DatabaseHelper.instance.getContextRichChunks(arg, query);

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
