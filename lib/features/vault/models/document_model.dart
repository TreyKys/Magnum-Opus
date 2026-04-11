class DocumentModel {
  final String id;
  final String title;
  final String filePath;
  final double fileSizeMb;
  final int totalPages;
  final DateTime lastAccessed;

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileSizeMb,
    required this.totalPages,
    required this.lastAccessed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file_path': filePath,
      'file_size_mb': fileSizeMb,
      'total_pages': totalPages,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'],
      title: map['title'],
      filePath: map['file_path'],
      fileSizeMb: map['file_size_mb'],
      totalPages: map['total_pages'],
      lastAccessed: DateTime.parse(map['last_accessed']),
    );
  }

  DocumentModel copyWith({
    String? id,
    String? title,
    String? filePath,
    double? fileSizeMb,
    int? totalPages,
    DateTime? lastAccessed,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      totalPages: totalPages ?? this.totalPages,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }
}
