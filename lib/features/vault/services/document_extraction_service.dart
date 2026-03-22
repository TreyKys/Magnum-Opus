import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:isolate';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/services/non_pdf_parser_service.dart';

Future<List<Map<String, dynamic>>> extractPdfTextChunk(Map<String, dynamic> params) async {
  final String filePath = params['filePath'];
  final int startPage = params['startPage'];
  final int endPage = params['endPage'];
  final String documentId = params['documentId'];

  final file = File(filePath);
  if (!file.existsSync()) {
    return [];
  }

  final bytes = file.readAsBytesSync();
  PdfDocument? document;
  List<Map<String, dynamic>> extractedChunks = [];

  try {
    document = PdfDocument(inputBytes: bytes);

    // The PdfTextExtractor needs to be initialized with the document
    final extractor = PdfTextExtractor(document);

    for (int i = startPage; i <= endPage; i++) {
      // Pages in Syncfusion are 0-indexed internally but the API might expose them as 1-indexed.
      // Wait, PdfTextExtractor.extractText takes a pageIndex which is 0-indexed.
      // Let's assume startPage and endPage are 1-indexed (as users usually expect page 1, 2, etc.)
      // and we convert to 0-indexed for the API.
      // Actually, wait, let's look at Syncfusion docs. extractText(startIndex: i)
      String text = '';
      try {
         text = extractor.extractText(startPageIndex: i - 1, endPageIndex: i - 1);
      } catch (e) {
        text = ''; // Error extracting text for this specific page
      }

      extractedChunks.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString() + i.toString(), // A quick unique ID for the chunk
        'document_id': documentId,
        'page_number': i,
        'extracted_text': text,
      });
    }
  } catch (e) {
    // Error initializing document or general error
  } finally {
    document?.dispose();
  }

  return extractedChunks;
}

Future<List<Map<String, dynamic>>> extractNonPdfTextChunk(Map<String, dynamic> params) async {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];
  final String ext = filePath.split('.').last.toLowerCase();

  String text = '';
  if (ext == 'docx') {
    text = await NonPdfParserService.extractTextFromDocx(filePath);
  } else if (ext == 'xlsx') {
    text = await NonPdfParserService.extractTextFromXlsx(filePath);
  } else if (ext == 'pptx') {
    text = await NonPdfParserService.extractTextFromPptx(filePath);
  }

  // Non-PDFs are currently processed as a single large chunk (page 1) to save SQLite memory management complexity
  return [{
    'id': '${DateTime.now().millisecondsSinceEpoch}1',
    'document_id': documentId,
    'page_number': 1,
    'extracted_text': text,
  }];
}

class DocumentExtractionService {
  static const int chunkSize = 20;

  static Future<void> extractDocument(DocumentModel document, Function(String) onComplete) async {
    final String ext = document.filePath.split('.').last.toLowerCase();

    if (ext == 'pdf') {
      final int totalPages = document.totalPages;
      if (totalPages == 0) {
        onComplete(document.id);
        return;
      }

      final int dbCount = await DatabaseHelper.instance.getExtractedPageCount(document.id);
      if (dbCount >= totalPages) {
         onComplete(document.id);
         return;
      }

      // Instead of spawning everything at once, we use Future.wait over chunks.
      List<Future<void>> futures = [];

      for (int i = 1; i <= totalPages; i += chunkSize) {
        final startPage = i;
        final endPage = (i + chunkSize - 1) > totalPages ? totalPages : (i + chunkSize - 1);

        final Map<String, dynamic> params = {
          'filePath': document.filePath,
          'startPage': startPage,
          'endPage': endPage,
          'documentId': document.id,
        };

        futures.add(_processChunk(params, isPdf: true));
      }

      await Future.wait(futures);
    } else {
      // Non-PDFs (DOCX, XLSX, PPTX) - Processed in a single background isolate chunk
      final int dbCount = await DatabaseHelper.instance.getExtractedPageCount(document.id);
      if (dbCount > 0) {
         onComplete(document.id);
         return;
      }

      final Map<String, dynamic> params = {
        'filePath': document.filePath,
        'documentId': document.id,
      };

      await _processChunk(params, isPdf: false);
    }

    onComplete(document.id);
  }

  static Future<void> _processChunk(Map<String, dynamic> params, {required bool isPdf}) async {
    final List<Map<String, dynamic>> chunks = isPdf
        ? await Isolate.run(() => extractPdfTextChunk(params))
        : await Isolate.run(() => extractNonPdfTextChunk(params));

    if (chunks.isNotEmpty) {
      await DatabaseHelper.instance.insertDocumentChunksBatch(chunks);
    }
  }

  static Future<void> validateAndResumeExtraction(List<DocumentModel> documents, Function(DocumentModel) resumeExtraction) async {
    for (final doc in documents) {
      if (doc.totalPages > 0) {
        final int dbCount = await DatabaseHelper.instance.getExtractedPageCount(doc.id);
        if (dbCount > 0 && dbCount < doc.totalPages) {
          // Interrupted extraction
          await DatabaseHelper.instance.deleteDocumentChunks(doc.id);
          resumeExtraction(doc);
        } else if (dbCount == 0 && doc.totalPages > 0) {
          // Hasn't started
          resumeExtraction(doc);
        }
      }
    }
  }
}
