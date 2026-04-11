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

  Future<String> generateRAGResponse({
    required String contextChunks,
    required String userQuery,
    required List<ChatMessage> history,
    Uint8List? imageBytes,
  }) async {
    final systemInstruction =
        '''You are the Magnum Opus Intelligence. Append the SQLite chunks, then append the user's query. Send the payload using model.generateContent()
Your primary directive is to extract, synthesize, and clearly explain information based on the provided document chunks.

Tone & Style: Professional, articulate, and helpful. Provide exhaustive, clearly explained, and precise answers. You may use a natural, conversational tone, but eliminate unnecessary fluff. Format your responses with clean spacing, bullet points, and bold text for readability.

Fallback Protocol: You must always provide a highly useful response. If the exact answer to the user's query is NOT fully contained within the provided document chunks, you must clearly state that up front (e.g., 'The provided document does not explicitly state this, however...'). Then, seamlessly pivot to answering the question using your own verified, factual knowledge, tying it back to any related context that is in the document.

Precision Mandate: When analyzing or explaining complex, specialized data, you must prioritize absolute structural accuracy, logical flow, and exhaustive detail. This mandate applies to all advanced domains, specifically including but not limited to:

Smart contract architecture & decentralized protocols

Pharmacokinetics & compounding formulas

Cybersecurity vulnerability reports & zero-day exploits

Technical analysis & algorithmic trading models

Cryptographic encryption protocols

Quantum mechanics & particle physics

Constitutional law & legal precedents

Machine learning tensor operations & neural networks

Aerospace aerodynamics & orbital mechanics

Biochemical pathways & molecular biology

Civil engineering load calculations

Genetic sequencing & bioinformatics

Macroeconomic monetary policies

Distributed ledger consensus mechanisms

Software system architectures

Supply chain logistics & operations research

Thermodynamics & fluid dynamics

Tax code regulations & corporate compliance

Material science crystallography

Medical diagnostic imaging reports

Renewable energy grid distributions

Actuarial risk assessments

Epidemiological modeling

Geopolitical treaty frameworks

Organic chemistry syntheses

High-frequency trading algorithms

Nanotechnology schematics

Paleontological stratigraphy

Telecommunications frequency bands

Urban planning & zoning ordinances

Quantum computing qubit logic

Veterinary pathology reports

Agronomy & soil compositions

Behavioral psychology statistical analyses

Microprocessor architecture diagrams

Oceanographic & tectonic shift data

Linguistics & syntactic tree mapping

Smart money concepts (SMC) & liquidity mechanics

Artificial intelligence alignment frameworks

Advanced calculus & differential equations''';

    final prompt =
        '''
$systemInstruction

---
DOCUMENT CHUNKS:
$contextChunks

---
USER QUERY:
$userQuery
''';

    try {
      final List<Content> contents = [];

      // Append conversational memory
      for (final msg in history) {
        if (msg.isUser) {
          contents.add(Content.text(msg.text));
        } else {
          contents.add(Content.model([TextPart(msg.text)]));
        }
      }

      // Append newest query
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
      return response.text ??
          "I could not generate a response. Please try again.";
    } catch (e) {
      return "An error occurred while communicating with the AI: $e";
    }
  }
}
