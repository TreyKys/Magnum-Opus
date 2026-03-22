import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:magnum_opus/features/vault/services/non_pdf_parser_service.dart';

class TextRipperTool extends StatefulWidget {
  const TextRipperTool({super.key});

  @override
  State<TextRipperTool> createState() => _TextRipperToolState();
}

class _TextRipperToolState extends State<TextRipperTool> {
  File? _selectedFile;
  bool _isProcessing = false;
  String _message = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'xlsx', 'pptx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _message = 'Selected: ${p.basename(_selectedFile!.path)}';
      });
    }
  }

  Future<void> _ripText() async {
    if (_selectedFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final ext = _selectedFile!.path.split('.').last.toLowerCase();
      String extractedText = '';

      if (ext == 'pdf') {
        final bytes = await _selectedFile!.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        extractedText = extractor.extractText();
        document.dispose();
      } else if (ext == 'docx') {
        extractedText = await NonPdfParserService.extractTextFromDocx(_selectedFile!.path);
      } else if (ext == 'xlsx') {
        extractedText = await NonPdfParserService.extractTextFromXlsx(_selectedFile!.path);
      } else if (ext == 'pptx') {
        extractedText = await NonPdfParserService.extractTextFromPptx(_selectedFile!.path);
      }

      if (extractedText.isEmpty) {
         setState(() => _message = 'No text could be extracted.');
         return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final outPath = File(p.join(dir.path, 'RippedText_${p.basenameWithoutExtension(_selectedFile!.path)}.txt'));
      await outPath.writeAsString(extractedText);

      setState(() {
        _message = 'Successfully ripped text and saved to ${outPath.path}!';
      });
    } catch (e) {
      setState(() {
        _message = 'Error ripping text: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Ripper')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.text_snippet_outlined, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Select Document (PDF/DOCX/XLSX/PPTX)'),
              ),
              const SizedBox(height: 16),
              if (_selectedFile != null)
                _isProcessing
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _ripText,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('Rip Text to .txt', style: TextStyle(color: Colors.black)),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
