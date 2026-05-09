import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

class AiService {
  late final GenerativeModel _model;

  AiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is missing from .env');
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  // ─── Retry with exponential backoff + jitter ──────────────────────────────

  Future<T> _withRetry<T>(Future<T> Function() fn, {int maxAttempts = 3}) async {
    Object? lastError;
    final rng = math.Random();
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == maxAttempts - 1) rethrow;
        final jitter = rng.nextInt(500);
        await Future.delayed(
            Duration(milliseconds: ((1 << attempt) * 1000) + jitter));
      }
    }
    throw lastError!;
  }

  bool _isRetryable(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('429') ||
        s.contains('quota') ||
        s.contains('resource_exhausted') ||
        s.contains('resourceexhausted') ||
        s.contains('503') ||
        s.contains('unavailable') ||
        s.contains('internal') ||
        s.contains('deadline_exceeded') ||
        s.contains('network');
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('429') || s.contains('quota') || s.contains('resource_exhausted') || s.contains('resourceexhausted')) {
      return 'The AI service is experiencing high demand right now. Please wait a moment and try again.';
    }
    if (s.contains('503') || s.contains('unavailable')) {
      return 'AI service is temporarily unavailable. Please try again shortly.';
    }
    if (s.contains('api key') || s.contains('authentication') || s.contains('unauthorized')) {
      return 'There was an issue with the AI connection. Please restart the app.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Something went wrong. Please try again in a moment.';
  }

  // ─── Complexity-Aware System Prompt ───────────────────────────────────────

  String _complexityInstruction(int complexity) {
    if (complexity <= 15) {
      return 'COMPLEXITY LEVEL: ELI5 (Explain Like I\'m 5). Use extremely simple language. '
          'Use everyday analogies and real-world comparisons a child could understand. '
          'Avoid all jargon and technical terms. Short sentences only.';
    } else if (complexity <= 35) {
      return 'COMPLEXITY LEVEL: Elementary. Explain clearly and accessibly for a general '
          'audience with no specialist background. Minimal jargon — define any technical '
          'terms you must use. Favour clarity over completeness.';
    } else if (complexity <= 60) {
      return 'COMPLEXITY LEVEL: Balanced. Professional, structured, and informative. '
          'Suitable for an educated adult. Use domain terminology where helpful but '
          'always explain it contextually.';
    } else if (complexity <= 80) {
      return 'COMPLEXITY LEVEL: Advanced. Provide in-depth technical analysis. '
          'Use precise domain terminology freely. Assume familiarity with the field. '
          'Include nuance, caveats, and methodological detail.';
    } else {
      return 'COMPLEXITY LEVEL: PhD / Expert. Respond at full academic rigour. '
          'Assume complete domain mastery. Use rigorous field-specific terminology, '
          'mathematical formulations where relevant, cite specific mechanisms, '
          'frameworks, or theoretical models. Do not simplify.';
    }
  }

  // ─── Main RAG Response ────────────────────────────────────────────────────

  Future<String> generateRAGResponse({
    required String contextChunks,
    required String userQuery,
    required List<ChatMessage> history,
    Uint8List? imageBytes,
    int complexity = 50,
    String? documentSkeleton,
    String? fileUri,        // Gemini File API URI (PDF brain)
    String? archiveChunks, // BM25 chunks for non-brain pages (Pipeline B)
  }) async {
    final complexityBlock = _complexityInstruction(complexity);

    final skeletonBlock = documentSkeleton != null && documentSkeleton.isNotEmpty
        ? '''
DOCUMENT OVERVIEW (Global Context — always keep this in mind):
$documentSkeleton

'''
        : '';

    final systemInstruction = '''
$complexityBlock

You are the Magnum Opus Intelligence Engine.
Your primary directive is to extract, synthesise, and clearly explain information based on the provided document context.

Tone & Style: Professional, articulate, and helpful. Provide exhaustive, clearly explained, and precise answers. Format responses with clean spacing, bullet points, and bold text for readability. Adapt depth strictly to the COMPLEXITY LEVEL above.

Fallback Protocol: Always provide a useful response. If the answer is NOT fully in the provided chunks, clearly state that, then pivot to answering using your own verified knowledge, tying back to related context.

Citation Mandate: Always end your response with a "Sources" section listing the specific pages you drew from, formatted as:
[Source: Page N · Document Title] or [Source: Page N]

Precision Mandate: Prioritise structural accuracy and logical flow across all advanced domains including but not limited to: smart contracts, pharmacokinetics, cybersecurity, algorithmic trading, cryptography, quantum mechanics, constitutional law, ML/neural networks, aerospace, biochemistry, civil engineering, genomics, macroeconomics, distributed systems, thermodynamics, tax law, materials science, medical imaging, renewable energy, actuarial science, epidemiology, organic chemistry, HFT, nanotechnology, paleontology, telecom, urban planning, quantum computing, veterinary pathology, agronomy, behavioural statistics, microprocessor architecture, oceanography, linguistics, SMC/liquidity mechanics, AI alignment, advanced calculus.''';

    final bool hasFileUri = fileUri != null && fileUri.isNotEmpty;

    final String prompt;
    if (hasFileUri) {
      final archiveSection =
          (archiveChunks != null && archiveChunks.isNotEmpty)
              ? '\nEXTENDED ARCHIVE (supplementary pages not in the core brain):\n$archiveChunks\n\n---\n'
              : '';
      prompt = '''
$systemInstruction

---
${skeletonBlock}The primary document is provided as an attached PDF. Answer based on the full document content.
$archiveSection
USER QUERY:
$userQuery
''';
    } else {
      prompt = '''
$systemInstruction

---
${skeletonBlock}DOCUMENT CHUNKS:
$contextChunks

---
USER QUERY:
$userQuery
''';
    }

    try {
      return await _withRetry(() async {
        final List<Content> contents = [];

        for (final msg in history) {
          if (msg.isUser) {
            contents.add(Content.text(msg.text));
          } else {
            contents.add(Content.model([TextPart(msg.text)]));
          }
        }

        Content newestContent;
        if (hasFileUri) {
          newestContent = Content.multi([
            FileData('application/pdf', fileUri!),
            TextPart(prompt),
            if (imageBytes != null) DataPart('image/png', imageBytes),
          ]);
        } else if (imageBytes != null) {
          newestContent = Content.multi([
            TextPart(prompt),
            DataPart('image/png', imageBytes),
          ]);
        } else {
          newestContent = Content.text(prompt);
        }
        contents.add(newestContent);

        final response = await _model.generateContent(contents);
        return response.text ?? 'I could not generate a response. Please try again.';
      });
    } catch (e) {
      return _friendlyError(e);
    }
  }

  // ─── General Chat (no document context) ──────────────────────────────────

  Future<String> generalChat({
    required String query,
    required List<ChatMessage> history,
    int complexity = 50,
    Uint8List? imageBytes,
  }) async {
    final complexityBlock = _complexityInstruction(complexity);

    final systemInstruction = '''
$complexityBlock

You are Magnum Opus — a highly capable AI assistant. You are helpful, articulate, and thorough.
Respond naturally to the user's message. Format your response with clean spacing, bullet points where appropriate, and bold text for key terms.
If the user attaches an image, analyse it carefully and answer their question about it.''';

    try {
      return await _withRetry(() async {
        final List<Content> contents = [];

        for (final msg in history) {
          if (msg.isUser) {
            contents.add(Content.text(msg.text));
          } else {
            contents.add(Content.model([TextPart(msg.text)]));
          }
        }

        Content newestContent;
        if (imageBytes != null) {
          newestContent = Content.multi([
            TextPart('$systemInstruction\n\n---\nUSER: $query'),
            DataPart('image/png', imageBytes),
          ]);
        } else {
          newestContent = Content.text('$systemInstruction\n\n---\nUSER: $query');
        }
        contents.add(newestContent);

        final response = await _model.generateContent(contents);
        return response.text ?? 'I could not generate a response. Please try again.';
      });
    } catch (e) {
      return _friendlyError(e);
    }
  }

  // ─── Web Summary Generator ────────────────────────────────────────────────

  Future<String> generateWebSummary(String url, String rawText) async {
    try {
      final truncated = rawText.length > 8000
          ? rawText.substring(0, 8000)
          : rawText;
      return await _withRetry(() async {
        final response = await _model.generateContent([
          Content.text(
            'You are given raw text scraped from the webpage at: $url\n\n'
            'Generate a comprehensive, well-structured knowledge document capturing all key information from this page.\n'
            'Structure: Start with the page title, then a 2-3 sentence overview, then main sections with ## headers, '
            'key facts/data as bullet points, and a brief conclusion.\n'
            'This document will be used as a queryable knowledge base — be thorough and precise.\n'
            'Target length: 400–800 words.\n\n'
            'RAW PAGE TEXT:\n$truncated',
          ),
        ]);
        return response.text ?? rawText.substring(0, rawText.length.clamp(0, 2000));
      });
    } catch (e) {
      return rawText.substring(0, rawText.length.clamp(0, 2000));
    }
  }

  // ─── Audio Transcription ──────────────────────────────────────────────────

  Future<String> transcribeAudio(Uint8List audioBytes, String mimeType) async {
    try {
      return await _withRetry(() async {
        final response = await _model.generateContent([
          Content.multi([
            TextPart(
              'Please transcribe this audio verbatim and completely. '
              'If multiple speakers are present, label them as Speaker 1, Speaker 2, etc. '
              'Format with timestamps every 60 seconds where possible (e.g. [00:60]). '
              'Do not summarise — output the full transcript.',
            ),
            DataPart(mimeType, audioBytes),
          ]),
        ]);
        return response.text ?? '';
      });
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ─── Global Skeleton Generator ────────────────────────────────────────────

  Future<String> generateSkeleton(String sampleChunks) async {
    try {
      return await _withRetry(() async {
        final response = await _model.generateContent([
          Content.text(
            'You are summarising a document for a RAG system. '
            'Based on the following text samples from throughout the document, '
            'write a concise 150–200 word overview that captures: '
            '(1) the document\'s core thesis or purpose, '
            '(2) the main topics covered, '
            '(3) the intended audience or context. '
            'Be precise — this summary will be prepended to every future AI query about this document.\n\n'
            'DOCUMENT SAMPLES:\n$sampleChunks',
          ),
        ]);
        return response.text ?? '';
      });
    } catch (e) {
      return ''; // Non-fatal — skeleton is a best-effort enhancement
    }
  }
}
