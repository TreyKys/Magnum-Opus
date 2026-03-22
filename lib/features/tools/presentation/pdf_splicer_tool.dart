import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfSplicerTool extends StatefulWidget {
  const PdfSplicerTool({super.key});

  @override
  State<PdfSplicerTool> createState() => _PdfSplicerToolState();
}

class _PdfSplicerToolState extends State<PdfSplicerTool> {
  File? _selectedFile;
  bool _isProcessing = false;
  String _message = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _message = 'Selected: ${p.basename(_selectedFile!.path)}';
      });
    }
  }

  Future<void> _splitPdf() async {
    if (_selectedFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      if (document.pages.count <= 1) {
        setState(() {
          _message = 'Document only has 1 page. Cannot split.';
          _isProcessing = false;
        });
        document.dispose();
        return;
      }

      // Splitting logic: take half.
      final half = (document.pages.count / 2).ceil();
      final doc1 = PdfDocument();
      final doc2 = PdfDocument();

      for (int i = 0; i < half; i++) {
        final template = document.pages[i].createTemplate();
        doc1.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      for (int i = half; i < document.pages.count; i++) {
        final template = document.pages[i].createTemplate();
        doc2.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final dir = await getApplicationDocumentsDirectory();
      final bName = p.basenameWithoutExtension(_selectedFile!.path);

      final out1 = File(p.join(dir.path, '${bName}_part1.pdf'));
      await out1.writeAsBytes(await doc1.save());

      final out2 = File(p.join(dir.path, '${bName}_part2.pdf'));
      await out2.writeAsBytes(await doc2.save());

      doc1.dispose();
      doc2.dispose();
      document.dispose();

      setState(() {
        _message = 'Successfully split into 2 parts and saved to device!';
      });
    } catch (e) {
      setState(() {
        _message = 'Error splitting PDF: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Splicer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_split, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Select PDF'),
              ),
              const SizedBox(height: 16),
              if (_selectedFile != null)
                _isProcessing
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _splitPdf,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('Split Document', style: TextStyle(color: Colors.black)),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
