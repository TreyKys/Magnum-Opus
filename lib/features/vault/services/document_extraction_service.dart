import 'dart:io';
import 'dart:isolate';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';

// ─── Isolate entry-points (top-level, free functions) ─────────────────────────
// Everything that touches `archive`, `html`, `excel`, or `syncfusion` MUST
// run inside one of these functions, which are passed to Isolate.run().
// The main thread only receives the final List<Map<String,dynamic>> result.

const _uuid = Uuid();
const int _chunkSize = 1500; // characters per text chunk
const int _pdfChunkPages = 20; // pages per PDF isolate batch

// ── PDF ───────────────────────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>> _extractPdfChunk(
    Map<String, dynamic> params) async {
  final String filePath = params['filePath'];
  final int startPage = params['startPage'];
  final int endPage = params['endPage'];
  final String documentId = params['documentId'];

  final file = File(filePath);
  if (!file.existsSync()) return [];
  final bytes = file.readAsBytesSync();
  PdfDocument? doc;
  final chunks = <Map<String, dynamic>>[];

  try {
    doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    for (int i = startPage; i <= endPage; i++) {
      String text = '';
      try {
        text = extractor.extractText(startPageIndex: i - 1, endPageIndex: i - 1);
      } catch (_) {}
      chunks.add({
        'id': '${DateTime.now().microsecondsSinceEpoch}$i',
        'document_id': documentId,
        'page_number': i,
        'extracted_text': text,
      });
    }
  } finally {
    doc?.dispose();
  }
  return chunks;
}

// ── EPUB ──────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractEpubSync(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];

  final bytes = File(filePath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final chunks = <Map<String, dynamic>>[];

  // Find the OPF file to get spine reading order
  ArchiveFile? opfFile;
  String opfBasePath = '';

  // First find container.xml
  final container = archive.findFile('META-INF/container.xml');
  if (container != null) {
    final containerXml = String.fromCharCodes(container.content as List<int>);
    final match = RegExp(r'full-path="([^"]+\.opf)"').firstMatch(containerXml);
    if (match != null) {
      final opfPath = match.group(1)!;
      opfFile = archive.findFile(opfPath);
      opfBasePath = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
          : '';
    }
  }

  List<String> contentFiles = [];

  if (opfFile != null) {
    final opfXml = String.fromCharCodes(opfFile.content as List<int>);
    // Parse spine itemrefs
    final spineMatches = RegExp(r'<itemref[^>]+idref="([^"]+)"')
        .allMatches(opfXml)
        .map((m) => m.group(1)!)
        .toList();
    // Map ids to hrefs
    final idToHref = <String, String>{};
    for (final m in RegExp(r'<item[^>]+id="([^"]+)"[^>]+href="([^"]+)"')
        .allMatches(opfXml)) {
      idToHref[m.group(1)!] = m.group(2)!;
    }
    for (final id in spineMatches) {
      final href = idToHref[id];
      if (href != null) contentFiles.add('$opfBasePath$href');
    }
  }

  // Fallback: just grab all xhtml/html files
  if (contentFiles.isEmpty) {
    contentFiles = archive.files
        .where((f) =>
            f.isFile &&
            (f.name.endsWith('.xhtml') ||
                f.name.endsWith('.html') ||
                f.name.endsWith('.htm')))
        .map((f) => f.name)
        .toList()
      ..sort();
  }

  int chunkIndex = 1;
  for (final filePath in contentFiles) {
    final file = archive.findFile(filePath);
    if (file == null) continue;
    final html = String.fromCharCodes(file.content as List<int>);
    final doc = html_parser.parse(html);
    // Remove nav/script/style
    for (final tag in ['script', 'style', 'nav']) {
      doc.querySelectorAll(tag).forEach((e) => e.remove());
    }
    final text = doc.body?.text ?? '';
    final clean =
        text.replaceAll(RegExp(r'\s{3,}'), '\n\n').trim();
    if (clean.isEmpty) continue;

    // Sub-chunk large chapters
    int start = 0;
    while (start < clean.length) {
      final end = (start + _chunkSize).clamp(0, clean.length);
      chunks.add({
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': chunkIndex,
        'extracted_text': clean.substring(start, end),
      });
      start = end;
      chunkIndex++;
    }
  }
  return chunks;
}

// ── DOCX ──────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractDocxSync(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];

  final bytes = File(filePath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final docXml = archive.findFile('word/document.xml');
  if (docXml == null) return [];

  final xmlStr = String.fromCharCodes(docXml.content as List<int>);
  // Extract all <w:t> text nodes
  final textNodes =
      RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true).allMatches(xmlStr);
  final buffer = StringBuffer();
  for (final m in textNodes) {
    buffer.write(m.group(1));
    buffer.write(' ');
  }
  final fullText = buffer.toString().trim();

  final chunks = <Map<String, dynamic>>[];
  int chunkIndex = 1;
  int start = 0;
  while (start < fullText.length) {
    final end = (start + _chunkSize).clamp(0, fullText.length);
    chunks.add({
      'id': _uuid.v4(),
      'document_id': documentId,
      'page_number': chunkIndex,
      'extracted_text': fullText.substring(start, end).trim(),
    });
    start = end;
    chunkIndex++;
  }
  return chunks;
}

// ── XLSX ──────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractXlsxSync(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];

  final bytes = File(filePath).readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final chunks = <Map<String, dynamic>>[];
  int chunkIndex = 1;

  for (final sheetName in excel.tables.keys) {
    final sheet = excel.tables[sheetName]!;
    final rows = sheet.rows;
    // Batch 100 rows per chunk
    for (int i = 0; i < rows.length; i += 100) {
      final end = (i + 100).clamp(0, rows.length);
      final buffer = StringBuffer();
      buffer.writeln('--- Sheet: $sheetName, Rows ${i + 1}–$end ---');
      for (final row in rows.sublist(i, end)) {
        final cells = row
            .map((c) => c?.value?.toString() ?? '')
            .where((v) => v.isNotEmpty)
            .join('\t');
        if (cells.isNotEmpty) buffer.writeln(cells);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) continue;
      chunks.add({
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': chunkIndex,
        'extracted_text': text,
      });
      chunkIndex++;
    }
  }
  return chunks;
}

// ── PPTX ──────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractPptxSync(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];

  final bytes = File(filePath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final chunks = <Map<String, dynamic>>[];

  final slideFiles = archive.files
      .where((f) =>
          f.isFile &&
          RegExp(r'ppt/slides/slide\d+\.xml').hasMatch(f.name))
      .toList()
    ..sort((a, b) {
      final na = int.tryParse(
              RegExp(r'slide(\d+)').firstMatch(a.name)?.group(1) ?? '0') ??
          0;
      final nb = int.tryParse(
              RegExp(r'slide(\d+)').firstMatch(b.name)?.group(1) ?? '0') ??
          0;
      return na.compareTo(nb);
    });

  for (int i = 0; i < slideFiles.length; i++) {
    final xmlStr =
        String.fromCharCodes(slideFiles[i].content as List<int>);
    final textNodes =
        RegExp(r'<a:t>(.*?)</a:t>', dotAll: true).allMatches(xmlStr);
    final buffer = StringBuffer();
    buffer.write('Slide ${i + 1}: ');
    for (final m in textNodes) {
      buffer.write(m.group(1));
      buffer.write(' ');
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) continue;
    chunks.add({
      'id': _uuid.v4(),
      'document_id': documentId,
      'page_number': i + 1,
      'extracted_text': text,
    });
  }
  return chunks;
}

// ── CSV / TXT ─────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractTextFileSync(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final String documentId = params['documentId'];
  final bool isCsv = params['isCsv'] == true;

  final content = File(filePath).readAsStringSync();
  final chunks = <Map<String, dynamic>>[];
  int chunkIndex = 1;

  if (isCsv) {
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i += 100) {
      final end = (i + 100).clamp(0, lines.length);
      final text = lines.sublist(i, end).join('\n').trim();
      if (text.isEmpty) continue;
      chunks.add({
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': chunkIndex,
        'extracted_text': text,
      });
      chunkIndex++;
    }
  } else {
    int start = 0;
    while (start < content.length) {
      final end = (start + _chunkSize).clamp(0, content.length);
      final text = content.substring(start, end).trim();
      if (text.isNotEmpty) {
        chunks.add({
          'id': _uuid.v4(),
          'document_id': documentId,
          'page_number': chunkIndex,
          'extracted_text': text,
        });
        chunkIndex++;
      }
      start = end;
    }
  }
  return chunks;
}

// ─── Main Service Class ───────────────────────────────────────────────────────

class DocumentExtractionService {
  static Future<void> extractDocument(
    DocumentModel document,
    Function(String) onComplete,
  ) async {
    try {
      switch (document.fileType) {
        case 'pdf':
          await _extractPdf(document);
          break;
        case 'epub':
          await _extractViaIsolate(
            _extractEpubSync,
            {'filePath': document.filePath, 'documentId': document.id},
          );
          break;
        case 'docx':
          await _extractViaIsolate(
            _extractDocxSync,
            {'filePath': document.filePath, 'documentId': document.id},
          );
          break;
        case 'xlsx':
          await _extractViaIsolate(
            _extractXlsxSync,
            {'filePath': document.filePath, 'documentId': document.id},
          );
          break;
        case 'pptx':
          await _extractViaIsolate(
            _extractPptxSync,
            {'filePath': document.filePath, 'documentId': document.id},
          );
          break;
        case 'csv':
          await _extractViaIsolate(
            _extractTextFileSync,
            {
              'filePath': document.filePath,
              'documentId': document.id,
              'isCsv': true,
            },
          );
          break;
        case 'txt':
          await _extractViaIsolate(
            _extractTextFileSync,
            {
              'filePath': document.filePath,
              'documentId': document.id,
              'isCsv': false,
            },
          );
          break;
        case 'audio':
        case 'url':
          // Already chunked during ingest — nothing to do here
          break;
      }

      // Generate global skeleton after extraction
      await _generateAndStoreSkeleton(document.id);
    } catch (_) {
      // Extraction errors are non-fatal — document is still queryable
    }

    onComplete(document.id);
  }

  // ── PDF: multiple isolate batches ──────────────────────────────────────────
  static Future<void> _extractPdf(DocumentModel document) async {
    final int totalPages = document.totalPages;
    if (totalPages == 0) return;

    final dbCount =
        await DatabaseHelper.instance.getExtractedPageCount(document.id);
    if (dbCount >= totalPages) return;

    final futures = <Future<void>>[];
    for (int i = 1; i <= totalPages; i += _pdfChunkPages) {
      final start = i;
      final end = (i + _pdfChunkPages - 1).clamp(1, totalPages);
      futures.add(_processChunk({
        'filePath': document.filePath,
        'startPage': start,
        'endPage': end,
        'documentId': document.id,
      }));
    }
    await Future.wait(futures);
  }

  static Future<void> _processChunk(Map<String, dynamic> params) async {
    final chunks =
        await Isolate.run(() => _extractPdfChunk(params));
    if (chunks.isNotEmpty) {
      await DatabaseHelper.instance.insertDocumentChunksBatch(chunks);
    }
  }

  // ── Generic isolate runner for archive-based formats ──────────────────────
  static Future<void> _extractViaIsolate(
    Function(Map<String, dynamic>) extractFn,
    Map<String, dynamic> params,
  ) async {
    final chunks = await Isolate.run(() => extractFn(params));
    if (chunks.isNotEmpty) {
      await DatabaseHelper.instance.insertDocumentChunksBatch(chunks);
    }
  }

  // ── Global Skeleton ────────────────────────────────────────────────────────
  static Future<void> _generateAndStoreSkeleton(String documentId) async {
    try {
      // Sample chunks spread through the document
      final db = DatabaseHelper.instance;
      final totalChunks = await db.getExtractedPageCount(documentId);
      if (totalChunks == 0) return;

      // Already has a skeleton — skip
      final existing = await db.getDocumentSkeleton(documentId);
      if (existing != null && existing.isNotEmpty) return;

      // Pick representative pages: first 2, middle, 3/4, last 2
      final picks = <int>{};
      picks.add(1);
      picks.add(2);
      picks.add((totalChunks * 0.25).round().clamp(1, totalChunks));
      picks.add((totalChunks * 0.5).round().clamp(1, totalChunks));
      picks.add((totalChunks * 0.75).round().clamp(1, totalChunks));
      picks.add(totalChunks - 1);
      picks.add(totalChunks);

      final sampleText = await _getSampleText(documentId, picks.toList()..sort());
      if (sampleText.isEmpty) return;

      final skeleton = await AiService().generateSkeleton(sampleText);
      if (skeleton.isNotEmpty) {
        await db.updateDocumentSkeleton(documentId, skeleton);
      }
    } catch (_) {
      // Non-fatal — skeleton is an enhancement, not a requirement
    }
  }

  static Future<String> _getSampleText(
      String documentId, List<int> pages) async {
    final db = await DatabaseHelper.instance.database;
    final placeholders = pages.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      'SELECT extracted_text FROM document_chunks WHERE document_id = ? AND page_number IN ($placeholders) ORDER BY page_number ASC',
      [documentId, ...pages],
    );
    return rows
        .map((r) => (r['extracted_text'] as String).substring(
              0,
              (r['extracted_text'] as String).length.clamp(0, 300),
            ))
        .join('\n\n');
  }

  /// Public entry-point for skeleton generation (used by vault_provider for
  /// audio and URL documents that skip the normal extractDocument path).
  static Future<void> generateSkeletonForDocument(String documentId) async {
    await _generateAndStoreSkeleton(documentId);
  }

  // ── Validate & resume interrupted extractions ──────────────────────────────
  static Future<void> validateAndResumeExtraction(
    List<DocumentModel> documents,
    Function(DocumentModel) resumeExtraction,
  ) async {
    for (final doc in documents) {
      // audio and url are always fully extracted at ingest time
      if (doc.fileType == 'audio' || doc.fileType == 'url') continue;
      if (doc.totalPages <= 0) continue;

      final dbCount =
          await DatabaseHelper.instance.getExtractedPageCount(doc.id);
      if (dbCount > 0 && dbCount < doc.totalPages) {
        // Interrupted — restart from scratch
        await DatabaseHelper.instance.deleteDocumentChunks(doc.id);
        resumeExtraction(doc);
      } else if (dbCount == 0) {
        resumeExtraction(doc);
      }
    }
  }
}
