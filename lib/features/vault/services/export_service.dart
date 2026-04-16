import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:magnum_opus/features/vault/models/chat_message.dart';

class ExportService {
  /// Exports the chat thread as a PDF and triggers the native Share Sheet.
  ///
  /// Strategy (3-tier, most-capable to most-resilient):
  ///   1. Printing.convertHtml() + KaTeX CDN  → genuine TeX rendering, branded fonts
  ///   2. pw.Document + Noto Sans             → Unicode-safe, raw LaTeX strings
  ///   3. pw.Document + Helvetica             → offline last resort, always succeeds
  static Future<void> exportChatAsPdf(
    BuildContext context,
    String documentTitle,
    List<ChatMessage> messages,
  ) async {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final safeTitle = documentTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final filename = '${safeTitle.isEmpty ? 'Report' : safeTitle} — Magnum Opus.pdf';

    // ── Tier 1: KaTeX HTML via platform WebView ──────────────────────────────
    try {
      final html = _buildHtml(documentTitle, dateStr, messages);
      final pdfBytes = await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: html,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      return;
    } catch (_) {
      // Network unavailable or WebView error — fall through to Tier 2
    }

    // ── Tier 2: pw.Document + Noto Sans ──────────────────────────────────────
    try {
      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      final monoFont = await PdfGoogleFonts.notoSansMonoRegular();
      final pdfBytes = await _buildPwDocument(
        documentTitle,
        dateStr,
        messages,
        regular: regularFont,
        bold: boldFont,
        mono: monoFont,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exported in offline mode — math rendered as text.'),
            backgroundColor: Color(0xFF1A1A1A),
          ),
        );
      }
      return;
    } catch (_) {
      // Google Fonts CDN also unavailable — fall through to Tier 3
    }

    // ── Tier 3: pw.Document + built-in Helvetica ──────────────────────────────
    try {
      final pdfBytes = await _buildPwDocument(
        documentTitle,
        dateStr,
        messages,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exported in offline mode — math rendered as text.'),
            backgroundColor: Color(0xFF1A1A1A),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  // ─── Tier 1: HTML builder ─────────────────────────────────────────────────

  static String _buildHtml(
    String title,
    String dateStr,
    List<ChatMessage> messages,
  ) {
    final messagesHtml = messages.map((msg) {
      final escaped = _escapeHtml(msg.text);
      if (msg.isUser) {
        return '<div class="bubble user-bubble"><span class="role">You</span>$escaped</div>';
      } else {
        return '<div class="bubble ai-bubble"><span class="role">Magnum Opus</span>$escaped</div>';
      }
    }).join('\n');

    final userCount = messages.where((m) => m.isUser).length;
    final aiCount = messages.where((m) => !m.isUser).length;

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- KaTeX — genuine TeX engine -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
<script>
  document.addEventListener("DOMContentLoaded", () => {
    renderMathInElement(document.body, {
      delimiters: [
        {left: "\$\$", right: "\$\$", display: true},
        {left: "\$", right: "\$", display: false}
      ],
      throwOnError: false
    });
  });
</script>

<!-- Fonts: Average (body) + Bricolage Grotesque (headers) -->
<link href="https://fonts.googleapis.com/css2?family=Average&family=Bricolage+Grotesque:wght@400;600;700&display=swap" rel="stylesheet">

<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Average', Georgia, serif;
    font-size: 13px;
    line-height: 1.7;
    color: #1a1a1a;
    background: #ffffff;
    padding: 32px 40px;
  }

  h1, h2, h3, .cover {
    font-family: 'Bricolage Grotesque', 'Segoe UI', sans-serif;
  }

  .cover {
    border-bottom: 3px solid #2563EB;
    padding-bottom: 20px;
    margin-bottom: 32px;
  }

  .cover .app-name {
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 2px;
    color: #2563EB;
    text-transform: uppercase;
    margin-bottom: 8px;
  }

  .cover h1 {
    font-size: 22px;
    font-weight: 700;
    color: #0a0a0a;
    margin-bottom: 12px;
    line-height: 1.3;
  }

  .cover .meta {
    font-size: 11px;
    color: #666;
    display: flex;
    gap: 20px;
  }

  .cover .meta span {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .bubble {
    margin-bottom: 18px;
    padding: 14px 18px;
    border-radius: 12px;
    page-break-inside: avoid;
  }

  .role {
    display: block;
    font-family: 'Bricolage Grotesque', sans-serif;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    margin-bottom: 6px;
  }

  .user-bubble {
    background: #EFF6FF;
    border-left: 4px solid #2563EB;
    margin-left: 40px;
  }

  .user-bubble .role { color: #2563EB; }

  .ai-bubble {
    background: #F9FAFB;
    border-left: 4px solid #E5E7EB;
  }

  .ai-bubble .role { color: #6B7280; }

  /* Source/citation lines */
  .ai-bubble p:last-child,
  .ai-bubble li:last-child {
    font-size: 11px;
    color: #6B7280;
  }

  pre, code {
    font-family: 'Courier New', monospace;
    font-size: 11.5px;
    background: #F3F4F6;
    border-radius: 4px;
  }

  pre { padding: 12px; overflow: hidden; }
  code { padding: 1px 4px; }

  .footer {
    margin-top: 40px;
    padding-top: 16px;
    border-top: 1px solid #E5E7EB;
    font-family: 'Bricolage Grotesque', sans-serif;
    font-size: 10px;
    color: #9CA3AF;
    text-align: center;
  }
</style>
</head>
<body>

<div class="cover">
  <div class="app-name">Magnum Opus · Research Report</div>
  <h1>$title</h1>
  <div class="meta">
    <span>Exported $dateStr</span>
    <span>$userCount questions</span>
    <span>$aiCount responses</span>
  </div>
</div>

$messagesHtml

<div class="footer">Generated by Magnum Opus Intelligence Engine · Gemini 2.5 Flash + Local RAG</div>

</body>
</html>''';
  }

  static String _escapeHtml(String text) {
    // Preserve LaTeX before escaping, then restore
    // Strategy: replace LaTeX blocks with placeholders, escape HTML, restore
    final blockLatex = <String>[];
    final inlineLatex = <String>[];

    var processed = text;

    // Extract block LaTeX $$...$$
    processed = processed.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (m) {
        blockLatex.add(m.group(0)!);
        return '%%BLOCK${blockLatex.length - 1}%%';
      },
    );

    // Extract inline LaTeX $...$
    processed = processed.replaceAllMapped(
      RegExp(r'\$(.+?)\$'),
      (m) {
        inlineLatex.add(m.group(0)!);
        return '%%INLINE${inlineLatex.length - 1}%%';
      },
    );

    // Escape HTML special chars
    processed = processed
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    // Basic Markdown → HTML
    processed = processed
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m.group(1)}</strong>')
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m.group(1)}</em>')
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => '<code>${m.group(1)}</code>')
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>');
    processed = '<p>$processed</p>';

    // Restore LaTeX (KaTeX will process it)
    for (int i = 0; i < blockLatex.length; i++) {
      processed = processed.replaceAll('%%BLOCK$i%%', blockLatex[i]);
    }
    for (int i = 0; i < inlineLatex.length; i++) {
      processed = processed.replaceAll('%%INLINE$i%%', inlineLatex[i]);
    }

    return processed;
  }

  // ─── Tiers 2 & 3: pw.Document fallback ───────────────────────────────────

  static Future<List<int>> _buildPwDocument(
    String title,
    String dateStr,
    List<ChatMessage> messages, {
    pw.Font? regular,
    pw.Font? bold,
    pw.Font? mono,
  }) async {
    final pdf = pw.Document(
      theme: regular != null
          ? pw.ThemeData.withFont(
              base: regular,
              bold: bold,
              italic: regular,
              boldItalic: bold,
            )
          : pw.ThemeData.base(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Cover
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue700, width: 2),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 16),
            margin: const pw.EdgeInsets.only(bottom: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MAGNUM OPUS · RESEARCH REPORT',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: PdfColors.blue700,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 20,
                    color: PdfColors.grey900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Exported $dateStr · ${messages.where((m) => m.isUser).length} questions · ${messages.where((m) => !m.isUser).length} responses',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          // Messages
          ...messages.map((msg) {
            final isUser = msg.isUser;
            return pw.Container(
              margin: pw.EdgeInsets.only(
                bottom: 14,
                left: isUser ? 40 : 0,
              ),
              decoration: pw.BoxDecoration(
                color: isUser ? PdfColors.blue50 : PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border(
                  left: pw.BorderSide(
                    color: isUser ? PdfColors.blue700 : PdfColors.grey400,
                    width: 3,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isUser ? 'YOU' : 'MAGNUM OPUS',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                      color: isUser ? PdfColors.blue700 : PdfColors.grey600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    msg.text,
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 11,
                      color: PdfColors.grey900,
                      lineSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Footer
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 24),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Generated by Magnum Opus Intelligence Engine · Gemini 2.5 Flash + Local RAG',
              style: pw.TextStyle(
                font: regular,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
