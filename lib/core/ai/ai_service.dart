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

    final prompt = '''
$systemInstruction

---
${skeletonBlock}DOCUMENT CHUNKS:
$contextChunks

---
USER QUERY:
$userQuery
''';

    try {
      final List<Content> contents = [];

      // Conversational memory
      for (final msg in history) {
        if (msg.isUser) {
          contents.add(Content.text(msg.text));
        } else {
          contents.add(Content.model([TextPart(msg.text)]));
        }
      }

      // Newest query — with optional Sniper Vision image
      Content newestContent;
      if (imageBytes != null) {
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
    } catch (e) {
      return 'An error occurred while communicating with the AI: $e';
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
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  // ─── Web Summary Generator ────────────────────────────────────────────────

  Future<String> generateWebSummary(String url, String rawText) async {
    try {
      final truncated = rawText.length > 8000
          ? rawText.substring(0, 8000)
          : rawText;
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
    } catch (e) {
      return rawText.substring(0, rawText.length.clamp(0, 2000));
    }
  }

  // ─── Audio Transcription ──────────────────────────────────────────────────

  /// Sends raw audio bytes to Gemini 2.5 Flash for native transcription.
  /// Returns the full transcript text.
  Future<String> transcribeAudio(Uint8List audioBytes, String mimeType) async {
    try {
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
    } catch (e) {
      throw Exception('Audio transcription failed: $e');
    }
  }

  // ─── Global Skeleton Generator ────────────────────────────────────────────

  /// Generates a 200-word macro-context summary of the document.
  /// Called once after extraction completes; stored in the documents table.
  Future<String> generateSkeleton(String sampleChunks) async {
    try {
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
    } catch (e) {
      return ''; // Non-fatal — skeleton is a best-effort enhancement
    }
  }
}
