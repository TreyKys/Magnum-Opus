import 'dart:convert';
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
      version: 6,
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
      await db.execute(
        "ALTER TABLE documents ADD COLUMN file_type TEXT NOT NULL DEFAULT 'pdf'",
      );
      await db.execute(
        "ALTER TABLE documents ADD COLUMN skeleton TEXT",
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE standalone_sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_message_at TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  attached_document_id TEXT,
  FOREIGN KEY (attached_document_id) REFERENCES documents(id) ON DELETE SET NULL
)
''');
      await db.execute('''
CREATE TABLE standalone_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  text TEXT NOT NULL,
  is_user INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES standalone_sessions(id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE documents ADD COLUMN file_uri TEXT");
      await db.execute("ALTER TABLE documents ADD COLUMN file_uri_uploaded_at TEXT");
      await db.execute("ALTER TABLE documents ADD COLUMN brain_pages TEXT");
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
  skeleton TEXT,
  file_uri TEXT,
  file_uri_uploaded_at TEXT,
  brain_pages TEXT
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
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chunks_doc_id ON document_chunks(document_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chunks_doc_page ON document_chunks(document_id, page_number)');

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

    await db.execute('''
CREATE TABLE standalone_sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_message_at TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  attached_document_id TEXT,
  FOREIGN KEY (attached_document_id) REFERENCES documents(id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE standalone_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  text TEXT NOT NULL,
  is_user INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES standalone_sessions(id) ON DELETE CASCADE
)
''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_session ON standalone_messages(session_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sessions_archived ON standalone_sessions(is_archived)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sessions_pinned ON standalone_sessions(is_pinned)');
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

  Future<DocumentModel?> getDocumentById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return DocumentModel.fromMap(result.first);
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

  Future<void> updateDocumentFileUri(
      String id, String? fileUri, DateTime? uploadedAt) async {
    final db = await instance.database;
    await db.update(
      'documents',
      {
        'file_uri': fileUri,
        'file_uri_uploaded_at': uploadedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDocumentBrainPages(String id, List<int> pages) async {
    final db = await instance.database;
    await db.update(
      'documents',
      {'brain_pages': jsonEncode(pages)},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Returns all chunks for a document in page order — used by the document viewer.
  Future<List<Map<String, dynamic>>> getAllDocumentChunks(String documentId) async {
    final db = await database;
    return db.query(
      'document_chunks',
      columns: ['page_number', 'extracted_text'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
  }

  /// Returns page numbers of the top [limit] content-dense chunks (by character count).
  /// Used to identify brain pages for the Division System.
  Future<List<int>> getTopContentPages(String documentId,
      {int limit = 50}) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT page_number
      FROM document_chunks
      WHERE document_id = ?
      ORDER BY LENGTH(extracted_text) DESC
      LIMIT ?
    ''', [documentId, limit]);
    return result.map((r) => r['page_number'] as int).toList();
  }

  /// BM25-inspired semantic chunk retrieval with distributed fallback.
  ///
  /// [excludePages]: page numbers to skip (brain pages already covered by File API).
  Future<String> getContextRichChunks(String documentId, String query,
      {List<int>? excludePages}) async {
    final db = await instance.database;

    // Build WHERE clause — optionally exclude brain pages
    String where = 'document_id = ?';
    final args = <dynamic>[documentId];
    if (excludePages != null && excludePages.isNotEmpty) {
      final ph = excludePages.map((_) => '?').join(',');
      where += ' AND page_number NOT IN ($ph)';
      args.addAll(excludePages);
    }

    final allChunks = await db.query(
      'document_chunks',
      where: where,
      whereArgs: args,
      orderBy: 'page_number ASC',
    );
    if (allChunks.isEmpty) {
      return 'DOCUMENT_NOT_READY';
    }

    // --- Keyword extraction ---
    const stopWords = {
      'a', 'an', 'the', 'is', 'it', 'in', 'on', 'at', 'to', 'for',
      'of', 'and', 'or', 'but', 'not', 'be', 'do', 'if', 'we', 'my',
      'me', 'he', 'she', 'us', 'i', 'as', 'by', 'so', 'up', 'no',
      'was', 'are', 'has', 'had', 'did', 'get', 'got', 'its',
    };
    final queryLower = query.toLowerCase();
    final keywords = query
        .split(RegExp(r'\s+'))
        .map((w) => w.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''))
        .where((w) => w.length >= 2 && !stopWords.contains(w))
        .toSet()
        .toList();

    // --- Score every chunk ---
    final scored = <(int score, Map<String, dynamic> chunk)>[];
    for (final chunk in allChunks) {
      final text = (chunk['extracted_text'] as String).toLowerCase();
      int score = 0;

      if (text.contains(queryLower)) score += 10;

      for (final kw in keywords) {
        int idx = 0;
        while (true) {
          idx = text.indexOf(kw, idx);
          if (idx == -1) break;
          score++;
          idx += kw.length;
        }
      }
      scored.add((score, chunk));
    }

    final hasMatches = scored.any((e) => e.$1 > 0);

    if (!hasMatches) {
      // Generic query — return distributed sample
      final n = allChunks.length;
      final indices = <int>{};
      for (int i = 0; i < n && i < 6; i++) indices.add(i);
      final mid = n ~/ 2;
      for (int i = (mid - 2).clamp(0, n - 1);
          i <= (mid + 2).clamp(0, n - 1);
          i++) indices.add(i);
      for (int i = (n - 5).clamp(0, n - 1); i < n; i++) indices.add(i);

      final sample = (indices.toList()..sort()).map((i) => allChunks[i]).toList();
      final buf = StringBuffer();
      for (final row in sample) {
        buf.writeln('--- Page ${row['page_number']} ---');
        buf.writeln(row['extracted_text']);
        buf.writeln();
      }
      return buf.toString();
    }

    // --- Take top-20 matched chunks ---
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final top20 = scored
        .where((e) => e.$1 > 0)
        .take(20)
        .map((e) => e.$2)
        .toList();

    // --- Expand context: ±2 pages around each matched chunk ---
    final pageSet = <int>{};
    for (final chunk in top20) {
      final page = chunk['page_number'] as int;
      for (int d = -2; d <= 2; d++) {
        if (page + d >= 1) pageSet.add(page + d);
      }
    }

    // Respect excludePages in expansion too
    if (excludePages != null && excludePages.isNotEmpty) {
      pageSet.removeAll(excludePages);
    }

    final pageList = pageSet.toList()..sort();
    final placeholders = pageList.map((_) => '?').join(',');
    final contextChunks = await db.rawQuery(
      'SELECT * FROM document_chunks '
      'WHERE document_id = ? AND page_number IN ($placeholders) '
      'ORDER BY page_number ASC',
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

  // ─── Standalone Sessions ──────────────────────────────────────────────────

  Future<void> insertStandaloneSession(Map<String, dynamic> session) async {
    final db = await instance.database;
    await db.insert('standalone_sessions', session,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns non-archived sessions: pinned first, then by last_message_at DESC.
  Future<List<Map<String, dynamic>>> getAllStandaloneSessions() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT s.*, d.title as attached_document_title
      FROM standalone_sessions s
      LEFT JOIN documents d ON s.attached_document_id = d.id
      WHERE s.is_archived = 0
      ORDER BY s.is_pinned DESC, COALESCE(s.last_message_at, s.created_at) DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getArchivedSessions() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT s.*, d.title as attached_document_title
      FROM standalone_sessions s
      LEFT JOIN documents d ON s.attached_document_id = d.id
      WHERE s.is_archived = 1
      ORDER BY COALESCE(s.last_message_at, s.created_at) DESC
    ''');
  }

  Future<int> countActiveSessions() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM standalone_sessions WHERE is_archived = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updateStandaloneSession(
      String id, Map<String, dynamic> fields) async {
    final db = await instance.database;
    await db.update('standalone_sessions', fields,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteStandaloneSession(String id) async {
    final db = await instance.database;
    await db.delete('standalone_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Standalone Messages ──────────────────────────────────────────────────

  Future<void> insertStandaloneMessage(Map<String, dynamic> message) async {
    final db = await instance.database;
    await db.insert('standalone_messages', message,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSessionMessages(
      String sessionId) async {
    final db = await instance.database;
    return db.query(
      'standalone_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSessionPreviewMessages(
      String sessionId) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT * FROM standalone_messages
      WHERE session_id = ?
      ORDER BY timestamp DESC
      LIMIT 2
    ''', [sessionId]);
  }

  Future<void> clearSessionMessages(String sessionId) async {
    final db = await instance.database;
    await db.delete('standalone_messages',
        where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
