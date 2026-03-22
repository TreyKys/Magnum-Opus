import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfCompressorTool extends StatefulWidget {
  const PdfCompressorTool({super.key});

  @override
  State<PdfCompressorTool> createState() => _PdfCompressorToolState();
}

class _PdfCompressorToolState extends State<PdfCompressorTool> {
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

  Future<void> _compressPdf() async {
    if (_selectedFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Basic compression trick with Syncfusion: recreate doc without metadata
      final compressedDoc = PdfDocument();
      compressedDoc.compressionLevel = PdfCompressionLevel.best;

      for (int i = 0; i < document.pages.count; i++) {
        final template = document.pages[i].createTemplate();
        compressedDoc.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final dir = await getApplicationDocumentsDirectory();
      final outPath = File(p.join(dir.path, 'Compressed_${p.basename(_selectedFile!.path)}'));
      await outPath.writeAsBytes(await compressedDoc.save());

      compressedDoc.dispose();
      document.dispose();

      setState(() {
        _message = 'Successfully compressed to ${outPath.path}!';
      });
    } catch (e) {
      setState(() {
        _message = 'Error compressing PDF: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Compressor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.compress, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Select PDF to Compress'),
              ),
              const SizedBox(height: 16),
              if (_selectedFile != null)
                _isProcessing
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _compressPdf,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('Compress Document', style: TextStyle(color: Colors.black)),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
