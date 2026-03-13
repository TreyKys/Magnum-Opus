import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:myapp/features/vault/models/document_model.dart';

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const idType = 'TEXT PRIMARY KEY';
      const textType = 'TEXT NOT NULL';
      const integerType = 'INTEGER NOT NULL';

      await db.execute('''
CREATE TABLE document_chunks (
  id $idType,
  document_id $textType,
  page_number $integerType,
  extracted_text $textType,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE documents (
  id $idType,
  title $textType,
  file_path $textType,
  file_size_mb $realType,
  total_pages $integerType,
  last_accessed $textType
)
''');

    await db.execute('''
CREATE TABLE document_chunks (
  id $idType,
  document_id $textType,
  page_number $integerType,
  extracted_text $textType,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
)
''');
  }

  Future<void> insertDocument(DocumentModel document) async {
    final db = await instance.database;
    await db.insert('documents', document.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertDocumentChunksBatch(List<Map<String, dynamic>> chunks) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final chunk in chunks) {
      batch.insert('document_chunks', chunk, conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.delete(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
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

  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'last_accessed DESC');
    return result.map((json) => DocumentModel.fromMap(json)).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await instance.database;
    await db.delete(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getContextRichChunks(String documentId, String query) async {
    final db = await instance.database;
    final keywords = query.split(' ').where((w) => w.length > 3).toList();

    if (keywords.isEmpty) return "No strong keywords found to search context.";

    int? matchedPage;
    // Basic search: Find the first chunk that matches any of the keywords
    for (final keyword in keywords) {
      final result = await db.query(
        'document_chunks',
        columns: ['page_number'],
        where: 'document_id = ? AND extracted_text LIKE ?',
        whereArgs: [documentId, '%$keyword%'],
        limit: 1,
      );
      if (result.isNotEmpty) {
        matchedPage = result.first['page_number'] as int;
        break;
      }
    }

    if (matchedPage == null) {
      return "No exact text match found in the document for the given query.";
    }

    // Get the matched chunk, plus the one before and the one after
    final chunks = await db.query(
      'document_chunks',
      where: 'document_id = ? AND page_number IN (?, ?, ?)',
      whereArgs: [documentId, matchedPage - 1, matchedPage, matchedPage + 1],
      orderBy: 'page_number ASC',
    );

    final buffer = StringBuffer();
    for (final row in chunks) {
      buffer.writeln('--- Page ${row['page_number']} ---');
      buffer.writeln(row['extracted_text']);
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
