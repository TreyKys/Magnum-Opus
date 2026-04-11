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
