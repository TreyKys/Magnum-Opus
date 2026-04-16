import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('magnum_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE document_chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  extracted_text TEXT NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE chat_history (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  message_text TEXT NOT NULL,
  is_user INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  is_pinned INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 4) {
      // Add file_type column (default 'pdf' for existing documents)
      await db.execute(
        "ALTER TABLE documents ADD COLUMN file_type TEXT NOT NULL DEFAULT 'pdf'",
      );
      // Add skeleton column (nullable — generated after extraction)
      await db.execute(
        "ALTER TABLE documents ADD COLUMN skeleton TEXT",
      );
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size_mb REAL NOT NULL,
  total_pages INTEGER NOT NULL,
  last_accessed TEXT NOT NULL,
  file_type TEXT NOT NULL DEFAULT 'pdf',
  skeleton TEXT
)
''');

    await db.execute('''
CREATE TABLE document_chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  extracted_text TEXT NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE chat_history (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  message_text TEXT NOT NULL,
  is_user INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  is_pinned INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');
  }

  // ─── Documents ────────────────────────────────────────────────────────────

  Future<void> insertDocument(DocumentModel document) async {
    final db = await instance.database;
    await db.insert('documents', document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'last_accessed DESC');
    return result.map((json) => DocumentModel.fromMap(json)).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await instance.database;
    // Cascade via FK handles document_chunks and chat_history
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateDocumentLastAccessed(String documentId) async {
    final db = await instance.database;
    await db.update(
      'documents',
      {'last_accessed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> updateDocumentSkeleton(String id, String skeleton) async {
    final db = await instance.database;
    await db.update(
      'documents',
      {'skeleton': skeleton},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getDocumentSkeleton(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      columns: ['skeleton'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return result.first['skeleton'] as String?;
  }

  // ─── Chunks ───────────────────────────────────────────────────────────────

  Future<void> insertDocumentChunksBatch(
      List<Map<String, dynamic>> chunks) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final chunk in chunks) {
      batch.insert('document_chunks', chunk,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> getExtractedPageCount(String documentId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT page_number) as count FROM document_chunks WHERE document_id = ?',
      [documentId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteDocumentChunks(String documentId) async {
    final db = await instance.database;
    await db.delete('document_chunks',
        where: 'document_id = ?', whereArgs: [documentId]);
  }

  /// Top-15 Semantic Fetch with context overlap.
  ///
  /// 1. Score every chunk by keyword hit count.
  /// 2. Take the top-15 highest-scoring chunks.
  /// 3. For each, include the page immediately before and after (context overlap).
  /// 4. Deduplicate and return ordered by page number.
  Future<String> getContextRichChunks(String documentId, String query) async {
    final db = await instance.database;

    // Extract meaningful keywords (>3 chars)
    final keywords =
        query.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();

    if (keywords.isEmpty) {
      // Fall back to first 3 chunks if no strong keywords
      final fallback = await db.query(
        'document_chunks',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'page_number ASC',
        limit: 3,
      );
      if (fallback.isEmpty) return 'No content found in this document.';
      return fallback
          .map((r) => '--- Page ${r['page_number']} ---\n${r['extracted_text']}')
          .join('\n\n');
    }

    // Score all chunks by keyword frequency
    final allChunks = await db.query(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    final scored = <Map<String, dynamic>>[];
    for (final chunk in allChunks) {
      final text = (chunk['extracted_text'] as String).toLowerCase();
      int score = 0;
      for (final kw in keywords) {
        int idx = 0;
        while (true) {
          idx = text.indexOf(kw.toLowerCase(), idx);
          if (idx == -1) break;
          score++;
          idx += kw.length;
        }
      }
      if (score > 0) {
        scored.add({...chunk, '_score': score});
      }
    }

    if (scored.isEmpty) return 'No matching content found for this query.';

    // Sort by score descending, take top 15
    scored.sort((a, b) => (b['_score'] as int).compareTo(a['_score'] as int));
    final top15 = scored.take(15).toList();

    // Collect page numbers: matched pages + their neighbors
    final pageSet = <int>{};
    for (final chunk in top15) {
      final page = chunk['page_number'] as int;
      if (page > 1) pageSet.add(page - 1);
      pageSet.add(page);
      pageSet.add(page + 1);
    }

    // Fetch all needed pages in one query
    final pageList = pageSet.toList()..sort();
    final placeholders = pageList.map((_) => '?').join(',');
    final contextChunks = await db.rawQuery(
      'SELECT * FROM document_chunks WHERE document_id = ? AND page_number IN ($placeholders) ORDER BY page_number ASC',
      [documentId, ...pageList],
    );

    final buffer = StringBuffer();
    for (final row in contextChunks) {
      buffer.writeln('--- Page ${row['page_number']} ---');
      buffer.writeln(row['extracted_text']);
      buffer.writeln();
    }
    return buffer.toString();
  }

  // ─── Chat History ─────────────────────────────────────────────────────────

  Future<void> insertChatMessage(Map<String, dynamic> message) async {
    final db = await instance.database;
    await db.insert('chat_history', message,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String documentId) async {
    final db = await instance.database;
    return await db.query(
      'chat_history',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> clearChatHistory(String documentId) async {
    final db = await instance.database;
    await db.delete(
      'chat_history',
      where: 'document_id = ? AND is_pinned = 0',
      whereArgs: [documentId],
    );
  }

  Future<void> togglePinChatMessage(String messageId, bool isPinned) async {
    final db = await instance.database;
    await db.update(
      'chat_history',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
