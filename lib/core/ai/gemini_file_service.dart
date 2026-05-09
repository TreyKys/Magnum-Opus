import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class GeminiFileService {
  static const _base = 'https://generativelanguage.googleapis.com';

  static String get _key {
    final k = dotenv.env['GEMINI_API_KEY'];
    if (k == null || k.isEmpty) throw Exception('GEMINI_API_KEY missing');
    return k;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Upload [pdfBytes] to the Gemini Files API. Returns the fileUri.
  static Future<String> uploadPdfWithRetry(
          Uint8List pdfBytes, String displayName) =>
      _withRetry(() => _uploadPdf(pdfBytes, displayName));

  /// Build a new PDF containing only the specified [pageNumbers] (1-indexed).
  /// Pages are sorted into document order in the output. Runs in an Isolate.
  static Future<Uint8List> extractSpecificPages(
      Uint8List allBytes, List<int> pageNumbers) {
    return Isolate.run(
      () => _extractSpecificPagesIsolate({
        'bytes': allBytes,
        'pages': pageNumbers,
      }),
    );
  }

  // ── Upload: 2-step resumable protocol ─────────────────────────────────────

  static Future<String> _uploadPdf(Uint8List bytes, String displayName) async {
    // Step 1: initiate
    final initRes = await http
        .post(
          Uri.parse('$_base/upload/v1beta/files?key=$_key'),
          headers: {
            'X-Goog-Upload-Protocol': 'resumable',
            'X-Goog-Upload-Command': 'start',
            'X-Goog-Upload-Header-Content-Length': '${bytes.length}',
            'X-Goog-Upload-Header-Content-Type': 'application/pdf',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'file': {'display_name': displayName}}),
        )
        .timeout(const Duration(seconds: 30));

    if (initRes.statusCode != 200) {
      throw Exception(
          'File upload initiation failed: ${initRes.statusCode} ${initRes.body}');
    }
    final uploadUrl = initRes.headers['x-goog-upload-url'];
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('Missing x-goog-upload-url in response headers');
    }

    // Step 2: upload bytes and finalize
    final uploadRes = await http
        .post(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Length': '${bytes.length}',
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command': 'upload, finalize',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 120));

    if (uploadRes.statusCode != 200) {
      throw Exception(
          'File upload failed: ${uploadRes.statusCode} ${uploadRes.body}');
    }

    final responseJson =
        jsonDecode(uploadRes.body) as Map<String, dynamic>;
    final file = responseJson['file'] as Map<String, dynamic>;
    final uri = file['uri'] as String;
    final name = file['name'] as String;
    final state = file['state'] as String? ?? 'ACTIVE';

    return state == 'PROCESSING'
        ? await _pollUntilActive(name, uri)
        : uri;
  }

  static Future<String> _pollUntilActive(
      String name, String fallbackUri) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final res = await http
            .get(Uri.parse('$_base/v1beta/$name?key=$_key'))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          if (json['state'] == 'ACTIVE') {
            return json['uri'] as String? ?? fallbackUri;
          }
        }
      } catch (_) {}
    }
    return fallbackUri;
  }

  // ── PDF page subset extractor (runs in Isolate) ───────────────────────────

  static Future<Uint8List> _extractSpecificPagesIsolate(
      Map<String, dynamic> params) async {
    final Uint8List allBytes = params['bytes'] as Uint8List;
    final List<int> pages = (params['pages'] as List).cast<int>();
    // Sort pages into document order for the output PDF
    final sorted = List<int>.from(pages)..sort();

    PdfDocument? src;
    PdfDocument? dst;
    try {
      src = PdfDocument(inputBytes: allBytes);
      dst = PdfDocument();
      final total = src.pages.count;
      for (final pageNum in sorted) {
        if (pageNum >= 1 && pageNum <= total) {
          dst.pages.importPage(src.pages[pageNum - 1]);
        }
      }
      return Uint8List.fromList(await dst.save());
    } finally {
      dst?.dispose();
      src?.dispose();
    }
  }

  // ── Retry with jitter ─────────────────────────────────────────────────────

  static Future<T> _withRetry<T>(Future<T> Function() fn,
      {int maxAttempts = 3}) async {
    Object? lastError;
    final rng = Random();
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts - 1) rethrow;
        final jitter = rng.nextInt(500);
        await Future.delayed(
            Duration(milliseconds: ((1 << attempt) * 1000) + jitter));
      }
    }
    throw lastError!;
  }
}
