import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfWelderTool extends StatefulWidget {
  const PdfWelderTool({super.key});

  @override
  State<PdfWelderTool> createState() => _PdfWelderToolState();
}

class _PdfWelderToolState extends State<PdfWelderTool> {
  List<File> _selectedFiles = [];
  bool _isProcessing = false;
  String _message = '';

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.map((path) => File(path!)).toList();
        _message = 'Selected ${_selectedFiles.length} files to weld.';
      });
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) {
      setState(() => _message = 'Please select at least 2 files.');
      return;
    }
    setState(() => _isProcessing = true);

    try {
      final mergedDocument = PdfDocument();

      for (var file in _selectedFiles) {
        final bytes = await file.readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < doc.pages.count; i++) {
          final template = doc.pages[i].createTemplate();
          mergedDocument.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        doc.dispose();
      }

      final dir = await getApplicationDocumentsDirectory();
      final outPath = File(p.join(dir.path, 'Welded_Document_${DateTime.now().millisecondsSinceEpoch}.pdf'));
      await outPath.writeAsBytes(await mergedDocument.save());

      mergedDocument.dispose();

      setState(() {
        _message = 'Successfully welded and saved to ${outPath.path}!';
      });
    } catch (e) {
      setState(() {
        _message = 'Error welding PDFs: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Welder')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.merge_type, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('Select PDFs to Weld'),
              ),
              const SizedBox(height: 16),
              if (_selectedFiles.length > 1)
                _isProcessing
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _mergePdfs,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('Weld Documents', style: TextStyle(color: Colors.black)),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
