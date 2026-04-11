import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

final chatProvider = NotifierProvider.autoDispose
    .family<ChatNotifier, List<ChatMessage>, String>(
      (arg) => ChatNotifier(arg),
    );

class ChatNotifier extends Notifier<List<ChatMessage>> {
  final String arg;
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
    // Reload messages to keep pinned ones
    await _loadMessages();
  }

  Future<void> togglePin(String messageId, bool isPinned) async {
    await DatabaseHelper.instance.togglePinChatMessage(messageId, isPinned);
    state = state.map((msg) {
      if (msg.id == messageId) {
        return msg.copyWith(isPinned: isPinned);
      }
      return msg;
    }).toList();
  }

  Future<void> sendMessage(String query, {Uint8List? imageBytes}) async {
    if (query.trim().isEmpty) return;

    // Record user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      documentId: arg,
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await DatabaseHelper.instance.insertChatMessage(userMessage.toMap());

    // Instantly add user message to UI
    state = [...state, userMessage];
    isThinking = true;

    try {
      // Step 1: Run getContextRichChunks from SQLite
      final contextChunks = await DatabaseHelper.instance.getContextRichChunks(
        arg,
        query,
      );

      // Step 2: Send payload to Gemini
      final response = await _aiService.generateRAGResponse(
        contextChunks: contextChunks,
        userQuery: query,
        history: state.where((msg) => msg.id != userMessage.id).toList(), // exclude current message
        imageBytes: imageBytes,
      );

      // Step 3: Record AI response
      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        documentId: arg,
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.instance.insertChatMessage(aiMessage.toMap());

      // Display response
      state = [...state, aiMessage];
    } catch (e) {
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        documentId: arg,
        text: "Error communicating with intelligence module: $e",
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, errorMessage];
    } finally {
      isThinking = false;
    }
  }
}
