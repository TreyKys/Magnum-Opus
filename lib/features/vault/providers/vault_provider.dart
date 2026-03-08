import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:myapp/core/database/database_helper.dart';
import 'package:myapp/features/vault/models/document_model.dart';

final vaultProvider = NotifierProvider<VaultNotifier, List<DocumentModel>>(() {
  return VaultNotifier();
});

class VaultNotifier extends Notifier<List<DocumentModel>> {
  @override
  List<DocumentModel> build() {
    _loadDocuments();
    return [];
  }

  Future<void> _loadDocuments() async {
    final docs = await DatabaseHelper.instance.getAllDocuments();
    state = docs;
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
        final newPath = p.join(appDir.path, '\$id-\$fileName');
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
        await _loadDocuments(); // Refresh state
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
      await _loadDocuments();
    } catch (e) {
      // Error deleting document
    }
  }
}
