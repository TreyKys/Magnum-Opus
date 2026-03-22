import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class NonPdfParserService {
  /// Extracts plain text from a DOCX file by parsing word/document.xml
  static Future<String> extractTextFromDocx(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.name == 'word/document.xml') {
          final content = String.fromCharCodes(file.content as List<int>);
          final document = XmlDocument.parse(content);

          // <w:t> tags contain the text
          final textNodes = document.findAllElements('w:t');
          final text = textNodes.map((node) => node.innerText).join(' ');
          return text;
        }
      }
      return '';
    } catch (e) {
      return 'Error extracting DOCX: $e';
    }
  }

  /// Extracts plain text from an XLSX file by parsing sharedStrings.xml and sheet xmls
  static Future<String> extractTextFromXlsx(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<String> sharedStrings = [];
      String allText = '';

      // 1. Get Shared Strings
      for (final file in archive) {
        if (file.name == 'xl/sharedStrings.xml') {
          final content = String.fromCharCodes(file.content as List<int>);
          final document = XmlDocument.parse(content);
          final tNodes = document.findAllElements('t');
          sharedStrings = tNodes.map((node) => node.innerText).toList();
          break;
        }
      }

      // 2. Iterate through sheets (xl/worksheets/sheet1.xml, etc.)
      for (final file in archive) {
        if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          final content = String.fromCharCodes(file.content as List<int>);
          final document = XmlDocument.parse(content);

          final cNodes = document.findAllElements('c');
          for (final node in cNodes) {
            final tAttr = node.getAttribute('t'); // 's' means shared string
            final vNode = node.findElements('v').firstOrNull;

            if (vNode != null) {
              if (tAttr == 's') {
                final index = int.tryParse(vNode.innerText);
                if (index != null && index < sharedStrings.length) {
                  allText += '${sharedStrings[index]} ';
                }
              } else {
                allText += '${vNode.innerText} ';
              }
            }
          }
          allText += '\n\n'; // Separate sheets
        }
      }

      return allText.trim();
    } catch (e) {
      return 'Error extracting XLSX: $e';
    }
  }

  /// Extracts plain text from a PPTX file by parsing ppt/slides/slide*.xml
  static Future<String> extractTextFromPptx(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String allText = '';

      // PPTX stores text in slides, typically inside <a:t> tags within <p:sp> shapes.
      // Slide files are named ppt/slides/slide1.xml, ppt/slides/slide2.xml, etc.
      // We need to parse them roughly in order. Let's find all slide files first.

      final slideFiles = archive.where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml')).toList();

      // Sort them by number (slide1, slide2, slide10)
      slideFiles.sort((a, b) {
        final aNum = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      for (int i = 0; i < slideFiles.length; i++) {
        final file = slideFiles[i];
        final content = String.fromCharCodes(file.content as List<int>);
        final document = XmlDocument.parse(content);

        final textNodes = document.findAllElements('a:t');
        final slideText = textNodes.map((node) => node.innerText).join(' ');

        if (slideText.trim().isNotEmpty) {
          allText += '--- Slide ${i + 1} ---\n';
          allText += '$slideText\n\n';
        }
      }

      return allText.trim();
    } catch (e) {
      return 'Error extracting PPTX: $e';
    }
  }
}
