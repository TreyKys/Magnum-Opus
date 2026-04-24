class StandaloneMessage {
  final String id;
  final String sessionId;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const StandaloneMessage({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  factory StandaloneMessage.fromMap(Map<String, dynamic> map) {
    return StandaloneMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      text: map['text'] as String,
      isUser: (map['is_user'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'text': text,
        'is_user': isUser ? 1 : 0,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ChatSessionModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final bool isPinned;
  final bool isArchived;
  final String? attachedDocumentId;
  final String? attachedDocumentTitle;
  final List<StandaloneMessage> recentMessages;

  const ChatSessionModel({
    required this.id,
    required this.title,
    required this.createdAt,
    this.lastMessageAt,
    this.isPinned = false,
    this.isArchived = false,
    this.attachedDocumentId,
    this.attachedDocumentTitle,
    this.recentMessages = const [],
  });

  factory ChatSessionModel.fromMap(
    Map<String, dynamic> map, {
    List<StandaloneMessage> recentMessages = const [],
  }) {
    return ChatSessionModel(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String)
          : null,
      isPinned: (map['is_pinned'] as int) == 1,
      isArchived: (map['is_archived'] as int) == 1,
      attachedDocumentId: map['attached_document_id'] as String?,
      attachedDocumentTitle: map['attached_document_title'] as String?,
      recentMessages: recentMessages,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'last_message_at': lastMessageAt?.toIso8601String(),
        'is_pinned': isPinned ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'attached_document_id': attachedDocumentId,
      };

  ChatSessionModel copyWith({
    String? title,
    DateTime? lastMessageAt,
    bool? isPinned,
    bool? isArchived,
    String? attachedDocumentId,
    String? attachedDocumentTitle,
    List<StandaloneMessage>? recentMessages,
  }) {
    return ChatSessionModel(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      attachedDocumentId: attachedDocumentId ?? this.attachedDocumentId,
      attachedDocumentTitle:
          attachedDocumentTitle ?? this.attachedDocumentTitle,
      recentMessages: recentMessages ?? this.recentMessages,
    );
  }
}
