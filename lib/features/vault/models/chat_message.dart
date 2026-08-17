/// AI-generated failure text that means the request never really ran, so the
/// user should not be charged a query for it.
///
/// Must stay in sync with AiService._friendlyError and the generic fallbacks
/// the chat notifiers insert — this matches on the rendered string because
/// generateRAGResponse swallows the exception and returns a friendly message
/// rather than throwing.
const _kRetryableAiMessages = {
  'The AI service is experiencing high demand right now. Please wait a moment and try again.',
  'AI service is temporarily unavailable. Please try again shortly.',
  'There was an issue with the AI connection. Please restart the app.',
  'No internet connection. Please check your network and try again.',
  'Something went wrong. Please try again in a moment.',
  'Something went wrong. Please try again.',
  'I could not generate a response. Please try again.',
};

bool isRetryableAiFailure(String text) =>
    _kRetryableAiMessages.contains(text.trim());

class ChatMessage {
  final String id;
  final String documentId;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isPinned;

  ChatMessage({
    required this.id,
    required this.documentId,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isPinned = false,
  });

  ChatMessage copyWith({
    String? id,
    String? documentId,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isPinned,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'message_text': text,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'is_pinned': isPinned ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      text: map['message_text'] as String,
      isUser: map['is_user'] == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isPinned: map['is_pinned'] == 1,
    );
  }
}
