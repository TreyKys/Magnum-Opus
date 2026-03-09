import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:myapp/core/database/database_helper.dart';
import 'package:myapp/features/vault/models/document_model.dart';
import 'package:myapp/features/vault/services/document_extraction_service.dart';

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

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(() {
  return VaultNotifier();
});

class VaultNotifier extends Notifier<VaultState> {
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
      final newSet = Set<String>.from(state.indexingDocumentIds)..add(document.id);
      state = state.copyWith(indexingDocumentIds: newSet);
    }

    DocumentExtractionService.extractDocument(document, (completedId) {
      if (state.indexingDocumentIds.contains(completedId)) {
        final newSet = Set<String>.from(state.indexingDocumentIds)..remove(completedId);
        state = state.copyWith(indexingDocumentIds: newSet);
      }
    });
  }

  Future<void> ingestPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final originalFile = File(result.files.single.path!);

        // Get app document directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(originalFile.path);

        // Generate UUID
        final id = const Uuid().v4();

        // Copy to app's internal directory
        // Append UUID to avoid file name collision
        final newPath = p.join(appDir.path, '$id-$fileName');
        final savedFile = await originalFile.copy(newPath);

        // Extract metadata
        final bytes = await savedFile.readAsBytes();
        final fileSizeMb = bytes.lengthInBytes / (1024 * 1024);

        // Headless page count extraction using Syncfusion
        int totalPages = 0;
        PdfDocument? document;
        try {
          document = PdfDocument(inputBytes: bytes);
          totalPages = document.pages.count;
        } catch (e) {
          // Error extracting metadata
        } finally {
          document?.dispose();
        }

        final docModel = DocumentModel(
          id: id,
          title: fileName,
          filePath: savedFile.path,
          fileSizeMb: fileSizeMb,
          totalPages: totalPages,
          lastAccessed: DateTime.now(),
        );

        await DatabaseHelper.instance.insertDocument(docModel);

        final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
        state = state.copyWith(documents: updatedDocs);

        // Start extraction for the newly ingested document
        _startExtraction(docModel);
      }
    } catch (e) {
      // Error during ingestion
    }
  }

  Future<void> deleteDocument(String id, String filePath) async {
    try {
      // Delete from SQLite
      await DatabaseHelper.instance.deleteDocument(id);

      // Delete the actual file
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Refresh state
      final updatedDocs = await DatabaseHelper.instance.getAllDocuments();
      state = state.copyWith(documents: updatedDocs);
    } catch (e) {
      // Error deleting document
    }
  }
}
