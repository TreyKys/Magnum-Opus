import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:magnum_opus/core/ai/gemini_file_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/services/document_extraction_service.dart';
import 'package:magnum_opus/features/vault/services/url_scraping_service.dart';
import 'package:magnum_opus/features/vault/services/audio_ingestion_service.dart';

class VaultState {
  final List<DocumentModel> documents;
  final Set<String> indexingDocumentIds;

  VaultState({
    this.documents = const [],
    this.indexingDocumentIds = const {},
  });

  VaultState copyWith({
    List<DocumentModel>? documents,
    Set<String>? indexingDocumentIds,
  }) {
    return VaultState(
      documents: documents ?? this.documents,
      indexingDocumentIds: indexingDocumentIds ?? this.indexingDocumentIds,
    );
  }
}

final vaultProvider =
    NotifierProvider<VaultNotifier, VaultState>(() => VaultNotifier());

class VaultNotifier extends Notifier<VaultState> {
  static const _uuid = Uuid();

  @override
  VaultState build() {
    _loadDocuments();
    return VaultState();
  }

  Future<void> _loadDocuments() async {
    final docs = await DatabaseHelper.instance.getAllDocuments();
    state = state.copyWith(documents: docs);
    _validateExtractions(docs);
  }

  Future<void> _validateExtractions(List<DocumentModel> docs) async {
    await DocumentExtractionService.validateAndResumeExtraction(
      docs,
      _startExtraction,
    );
  }

  void _startExtraction(DocumentModel document) {
    if (!state.indexingDocumentIds.contains(document.id)) {
      final newSet = Set<String>.from(state.indexingDocumentIds)
        ..add(document.id);
      state = state.copyWith(indexingDocumentIds: newSet);
    }

    DocumentExtractionService.extractDocument(document, (completedId) {
      if (state.indexingDocumentIds.contains(completedId)) {
        final newSet = Set<String>.from(state.indexingDocumentIds)
          ..remove(completedId);
        state = state.copyWith(indexingDocumentIds: newSet);
      }
    });
  }

  // ─── Ingest: Documents (PDF, EPUB, DOCX, TXT, CSV) ──────────────────────

  Future<void> ingestDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'docx', 'txt', 'csv'],
      );
      if (result == null || result.files.single.path == null) return;
      await _ingestFile(result.files.single.path!);
    } catch (_) {}
  }

  // ─── Ingest: Data & Slides (XLSX, PPTX) ─────────────────────────────────

  Future<void> ingestData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'pptx'],
      );
      if (result == null || result.files.single.path == null) return;
      await _ingestFile(result.files.single.path!);
    } catch (_) {}
  }

  // ─── Ingest: Audio (MP3, M4A, WAV) ──────────────────────────────────────

  Future<void> ingestAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result == null || result.files.single.path == null) return;

      final originalFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(originalFile.path);
      final id = _uuid.v4();
      final newPath = p.join(appDir.path, '$id-$fileName');
      final savedFile = await originalFile.copy(newPath);
      final fileSizeMb =
          await savedFile.length() / (1024 * 1024);

      final docModel = DocumentModel(
        id: id,
        title: fileName,
        filePath: savedFile.path,
        fileSizeMb: fileSizeMb,
        totalPages: 0,
        lastAccessed: DateTime.now(),
        fileType: 'audio',
      );
      await DatabaseHelper.instance.insertDocument(docModel);

      final indexingSet = Set<String>.from(state.indexingDocumentIds)..add(id);
      final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
      state = state.copyWith(
          documents: updatedDocs, indexingDocumentIds: indexingSet);

      AudioIngestionService.transcribeAndChunk(savedFile.path, id).then((chunkCount) async {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'documents',
          {'total_pages': chunkCount},
          where: 'id = ?',
          whereArgs: [id],
        );
        await DocumentExtractionService.generateSkeletonForDocument(id);
        final newSet = Set<String>.from(state.indexingDocumentIds)..remove(id);
        final refreshed = await DatabaseHelper.instance.getAllDocuments();
        state = state.copyWith(documents: refreshed, indexingDocumentIds: newSet);
      }).catchError((_) {
        final newSet = Set<String>.from(state.indexingDocumentIds)..remove(id);
        state = state.copyWith(indexingDocumentIds: newSet);
      });
    } catch (_) {}
  }

  // ─── Ingest: URL ─────────────────────────────────────────────────────────

  Future<void> ingestUrl(String url) async {
    try {
      final id = _uuid.v4();
      final title = _titleFromUrl(url);

      final docModel = DocumentModel(
        id: id,
        title: title,
        filePath: url,
        fileSizeMb: 0,
        totalPages: 0,
        lastAccessed: DateTime.now(),
        fileType: 'url',
      );
      await DatabaseHelper.instance.insertDocument(docModel);

      final indexingSet = Set<String>.from(state.indexingDocumentIds)..add(id);
      final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
      state = state.copyWith(
          documents: updatedDocs, indexingDocumentIds: indexingSet);

      UrlScrapingService.scrapeAndChunk(url, id).then((chunkCount) async {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'documents',
          {'total_pages': chunkCount},
          where: 'id = ?',
          whereArgs: [id],
        );
        await DocumentExtractionService.generateSkeletonForDocument(id);
        final newSet = Set<String>.from(state.indexingDocumentIds)..remove(id);
        final refreshed = await DatabaseHelper.instance.getAllDocuments();
        state = state.copyWith(documents: refreshed, indexingDocumentIds: newSet);
      }).catchError((_) {
        final newSet = Set<String>.from(state.indexingDocumentIds)..remove(id);
        state = state.copyWith(indexingDocumentIds: newSet);
      });
    } catch (_) {}
  }

  // ─── Shared file ingest helper ───────────────────────────────────────────

  Future<void> _ingestFile(String originalPath) async {
    final originalFile = File(originalPath);
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(originalFile.path);
    final id = _uuid.v4();
    final newPath = p.join(appDir.path, '$id-$fileName');
    final savedFile = await originalFile.copy(newPath);
    final bytes = await savedFile.readAsBytes();
    final fileSizeMb = bytes.lengthInBytes / (1024 * 1024);
    final fileType = _fileTypeFromExtension(p.extension(fileName).toLowerCase());

    int totalPages = 0;
    if (fileType == 'pdf') {
      // Run PdfDocument on an isolate to avoid blocking the main thread
      try {
        totalPages = await Isolate.run(() {
          PdfDocument? doc;
          try {
            doc = PdfDocument(inputBytes: bytes);
            return doc.pages.count;
          } catch (_) {
            return 0;
          } finally {
            doc?.dispose();
          }
        });
      } catch (_) {
        totalPages = 0;
      }
    }

    final docModel = DocumentModel(
      id: id,
      title: fileName,
      filePath: savedFile.path,
      fileSizeMb: fileSizeMb,
      totalPages: totalPages,
      lastAccessed: DateTime.now(),
      fileType: fileType,
    );

    await DatabaseHelper.instance.insertDocument(docModel);
    final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
    state = state.copyWith(documents: updatedDocs);

    if (fileType == 'pdf' && totalPages > 0) {
      _routePdfDivision(docModel, bytes, totalPages);
    } else {
      _startExtraction(docModel);
    }
  }

  // ─── Division System ─────────────────────────────────────────────────────

  void _routePdfDivision(DocumentModel doc, Uint8List bytes, int totalPages) {
    final indexingSet = Set<String>.from(state.indexingDocumentIds)
      ..add(doc.id);
    state = state.copyWith(indexingDocumentIds: indexingSet);

    _runPdfDivision(doc, bytes, totalPages).catchError((_) {
      // File API failed — chunks were extracted via extractDocument, doc is still usable
      final newSet = Set<String>.from(state.indexingDocumentIds)
        ..remove(doc.id);
      DatabaseHelper.instance.getAllDocuments().then((docs) {
        state = state.copyWith(documents: docs, indexingDocumentIds: newSet);
      });
    });
  }

  Future<void> _runPdfDivision(
      DocumentModel doc, Uint8List bytes, int totalPages) async {
    // Step 1: Extract ALL pages as chunks (BM25 fallback + skeleton)
    await DocumentExtractionService.extractDocument(doc, (_) {});

    // Step 2: Select brain pages and upload to Gemini File API
    if (totalPages <= 50) {
      // Pipeline A: entire PDF is the brain
      final fileUri =
          await GeminiFileService.uploadPdfWithRetry(bytes, doc.title);
      await DatabaseHelper.instance
          .updateDocumentFileUri(doc.id, fileUri, DateTime.now());
      // For Pipeline A, all pages are in the File API — no brainPages stored
    } else {
      // Pipeline B: top 50 content-dense pages are the brain
      final topPages = await DatabaseHelper.instance
          .getTopContentPages(doc.id, limit: 50);
      if (topPages.isNotEmpty) {
        final brainBytes =
            await GeminiFileService.extractSpecificPages(bytes, topPages);
        final fileUri = await GeminiFileService.uploadPdfWithRetry(
            brainBytes, '${doc.title} [Core]');
        await DatabaseHelper.instance
            .updateDocumentFileUri(doc.id, fileUri, DateTime.now());
        await DatabaseHelper.instance
            .updateDocumentBrainPages(doc.id, topPages);
      }
    }

    final newSet = Set<String>.from(state.indexingDocumentIds)
      ..remove(doc.id);
    final refreshed = await DatabaseHelper.instance.getAllDocuments();
    state = state.copyWith(
        documents: refreshed, indexingDocumentIds: newSet);
  }

  // ─── Delete ──────────────────────────────────────────────────────────────

  Future<void> deleteDocument(String id, String filePath) async {
    try {
      await DatabaseHelper.instance.deleteDocument(id);
      if (!filePath.startsWith('http')) {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      }
      final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
      state = state.copyWith(documents: updatedDocs);
    } catch (_) {}
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String _fileTypeFromExtension(String ext) {
    switch (ext) {
      case '.pdf':
        return 'pdf';
      case '.epub':
        return 'epub';
      case '.docx':
        return 'docx';
      case '.xlsx':
        return 'xlsx';
      case '.pptx':
        return 'pptx';
      case '.csv':
        return 'csv';
      case '.txt':
        return 'txt';
      case '.mp3':
      case '.m4a':
      case '.wav':
      case '.ogg':
      case '.flac':
        return 'audio';
      default:
        return 'txt';
    }
  }

  static String _titleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (_) {
      return 'Web Document';
    }
  }
}
