import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:magnum_opus/core/ai/ai_service.dart';
import 'package:magnum_opus/core/database/database_helper.dart';

class AudioIngestionService {
  static const int _wordsPerChunk = 400;
  static const _uuid = Uuid();

  /// Reads the audio file at [filePath], transcribes via Gemini,
  /// chunks the transcript, and stores it in SQLite.
  /// Returns the number of chunks stored (used as totalPages for the document).
  static Future<int> transcribeAndChunk(
    String filePath,
    String documentId,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $filePath');
    }

    final Uint8List audioBytes = await file.readAsBytes();
    final mimeType = _mimeTypeFromPath(filePath);

    final aiService = AiService();
    final transcript = await aiService.transcribeAudio(audioBytes, mimeType);

    if (transcript.trim().isEmpty) {
      throw Exception('Transcription returned empty content.');
    }

    // Split transcript into ~400-word chunks
    final words = transcript.split(RegExp(r'\s+'));
    final chunks = <Map<String, dynamic>>[];
    int chunkIndex = 1;

    for (int i = 0; i < words.length; i += _wordsPerChunk) {
      final end = (i + _wordsPerChunk).clamp(0, words.length);
      final chunkText = words.sublist(i, end).join(' ');
      chunks.add({
        'id': _uuid.v4(),
        'document_id': documentId,
        'page_number': chunkIndex,
        'extracted_text': chunkText,
      });
      chunkIndex++;
    }

    if (chunks.isNotEmpty) {
      await DatabaseHelper.instance.insertDocumentChunksBatch(chunks);
    }

    return chunks.length;
  }

  static String _mimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mp3';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }
}
