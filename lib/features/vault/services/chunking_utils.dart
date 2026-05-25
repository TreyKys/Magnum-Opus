

class ChunkingUtils {
  static const int _charsPerToken = 4;
  static const int _maxTokens = 500;
  static const int _overlapTokens = 100;

  static const int _maxChars = _maxTokens * _charsPerToken;
  static const int _overlapChars = _overlapTokens * _charsPerToken;

  /// Chunks the input text into approx 500-token chunks with 100-token overlap,
  /// preferring to break on sentence boundaries (., !, ?).
  static List<String> strictChunkText(String text) {
    if (text.isEmpty) return [];

    final List<String> chunks = [];
    int start = 0;

    while (start < text.length) {
      int end = start + _maxChars;

      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      // Attempt to find a sentence boundary near the end limit
      int boundary = _findSentenceBoundary(text, end, start);

      if (boundary == -1) {
        // Fallback to nearest word boundary if no sentence boundary found
        boundary = _findWordBoundary(text, end, start);
      }

      if (boundary == -1) {
        // Hard cut if no word boundary found (rare)
        boundary = end;
      }

      chunks.add(text.substring(start, boundary).trim());

      // Calculate overlap: move start back by _overlapChars from the new start point
      // Actually, next start should be `boundary - _overlapChars`, but we must align to a sentence or word boundary as well
      int nextStartTarget = boundary - _overlapChars;
      if (nextStartTarget <= start) {
        // Prevent infinite loops if boundary didn't advance much
        nextStartTarget = start + (boundary - start) ~/ 2;
      }

      int nextStartBoundary = _findSentenceBoundaryForward(text, nextStartTarget, boundary);
      if (nextStartBoundary == -1) {
         nextStartBoundary = _findWordBoundaryForward(text, nextStartTarget, boundary);
      }

      if (nextStartBoundary != -1) {
        start = nextStartBoundary;
      } else {
        start = nextStartTarget;
      }
    }

    return chunks;
  }

  static int _findSentenceBoundary(String text, int searchFrom, int minBound) {
    for (int i = searchFrom; i > minBound; i--) {
      if ((text[i] == '.' || text[i] == '!' || text[i] == '?') &&
          (i + 1 == text.length || text[i+1] == ' ' || text[i+1] == '\n')) {
        return i + 1; // Include the punctuation
      }
    }
    return -1;
  }

  static int _findWordBoundary(String text, int searchFrom, int minBound) {
    for (int i = searchFrom; i > minBound; i--) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i;
      }
    }
    return -1;
  }

  static int _findSentenceBoundaryForward(String text, int searchFrom, int maxBound) {
    for (int i = searchFrom; i < maxBound; i++) {
      if ((text[i] == '.' || text[i] == '!' || text[i] == '?') &&
          (i + 1 == text.length || text[i+1] == ' ' || text[i+1] == '\n')) {
        return i + 1;
      }
    }
    return -1;
  }

  static int _findWordBoundaryForward(String text, int searchFrom, int maxBound) {
    for (int i = searchFrom; i < maxBound; i++) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i + 1;
      }
    }
    return -1;
  }
}
