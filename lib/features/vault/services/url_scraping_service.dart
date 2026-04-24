import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';

class UrlScrapingService {
  static const _uuid = Uuid();

  /// Fetches [url], strips HTML, generates an AI summary, stores as a single chunk.
  /// Returns 1 (the chunk count used as totalPages for the document).
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

    for (final tag in [
      'script', 'style', 'nav', 'footer', 'header', 'aside', 'noscript', 'iframe',
    ]) {
      document.querySelectorAll(tag).forEach((e) => e.remove());
    }

    final contentNode = document.querySelector('article') ??
        document.querySelector('main') ??
        document.body;

    final rawText = (contentNode?.text ?? '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    if (rawText.isEmpty) {
      throw Exception('No readable content found at $url');
    }

    final summary = await AiService().generateWebSummary(url, rawText);

    await DatabaseHelper.instance.insertDocumentChunksBatch([
      {
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': 1,
        'extracted_text': summary,
      }
    ]);

    return 1;
  }
}
