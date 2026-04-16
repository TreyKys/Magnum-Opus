import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/database/database_helper.dart';

class UrlScrapingService {
  static const int _chunkSize = 1500;
  static const _uuid = Uuid();

  /// Fetches [url], strips HTML, chunks the body text, and stores it in SQLite.
  /// Returns the number of chunks stored (used as totalPages for the document).
  static Future<int> scrapeAndChunk(String url, String documentId) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; MagnumOpus/2.0; +https://magnumopus.app)',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: Failed to fetch $url');
    }

    final document = html_parser.parse(response.body);

    // Remove noise elements
    for (final tag in [
      'script',
      'style',
      'nav',
      'footer',
      'header',
      'aside',
      'noscript',
      'iframe',
    ]) {
      document.querySelectorAll(tag).forEach((e) => e.remove());
    }

    // Prefer <article> or <main> for content; fall back to <body>
    final contentNode = document.querySelector('article') ??
        document.querySelector('main') ??
        document.body;

    final rawText = contentNode?.text ?? '';

    // Collapse whitespace
    final cleanText = rawText
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    if (cleanText.isEmpty) {
      throw Exception('No readable content found at $url');
    }

    // Chunk into segments
    final chunks = <Map<String, dynamic>>[];
    int chunkIndex = 1;
    int start = 0;
    while (start < cleanText.length) {
      final end = (start + _chunkSize).clamp(0, cleanText.length);
      chunks.add({
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': chunkIndex,
        'extracted_text': cleanText.substring(start, end).trim(),
      });
      start = end;
      chunkIndex++;
    }

    if (chunks.isNotEmpty) {
      await DatabaseHelper.instance.insertDocumentChunksBatch(chunks);
    }

    return chunks.length;
  }
}
