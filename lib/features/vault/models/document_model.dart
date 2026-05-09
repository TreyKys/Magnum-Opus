import 'dart:convert';

class DocumentModel {
  final String id;
  final String title;
  final String filePath;
  final double fileSizeMb;
  final int totalPages;
  final DateTime lastAccessed;
  final String fileType; // 'pdf','epub','docx','xlsx','pptx','csv','txt','audio','url'
  final String? fileUri;           // Gemini Files API URI (PDFs only)
  final DateTime? fileUriUploadedAt; // when the File API upload completed
  final List<int>? brainPages;     // page numbers of the uploaded brain subset (Pipeline B)

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileSizeMb,
    required this.totalPages,
    required this.lastAccessed,
    this.fileType = 'pdf',
    this.fileUri,
    this.fileUriUploadedAt,
    this.brainPages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file_path': filePath,
      'file_size_mb': fileSizeMb,
      'total_pages': totalPages,
      'last_accessed': lastAccessed.toIso8601String(),
      'file_type': fileType,
      'file_uri': fileUri,
      'file_uri_uploaded_at': fileUriUploadedAt?.toIso8601String(),
      'brain_pages': brainPages != null ? jsonEncode(brainPages) : null,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    List<int>? brainPages;
    if (map['brain_pages'] != null) {
      brainPages = (jsonDecode(map['brain_pages'] as String) as List).cast<int>();
    }
    return DocumentModel(
      id: map['id'],
      title: map['title'],
      filePath: map['file_path'],
      fileSizeMb: (map['file_size_mb'] as num).toDouble(),
      totalPages: map['total_pages'],
      lastAccessed: DateTime.parse(map['last_accessed']),
      fileType: map['file_type'] as String? ?? 'pdf',
      fileUri: map['file_uri'] as String?,
      fileUriUploadedAt: map['file_uri_uploaded_at'] != null
          ? DateTime.parse(map['file_uri_uploaded_at'] as String)
          : null,
      brainPages: brainPages,
    );
  }

  DocumentModel copyWith({
    String? id,
    String? title,
    String? filePath,
    double? fileSizeMb,
    int? totalPages,
    DateTime? lastAccessed,
    String? fileType,
    String? fileUri,
    DateTime? fileUriUploadedAt,
    List<int>? brainPages,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      totalPages: totalPages ?? this.totalPages,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      fileType: fileType ?? this.fileType,
      fileUri: fileUri ?? this.fileUri,
      fileUriUploadedAt: fileUriUploadedAt ?? this.fileUriUploadedAt,
      brainPages: brainPages ?? this.brainPages,
    );
  }
}
