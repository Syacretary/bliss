import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';
import 'package:xml/xml.dart';

class ImportedKnowledge {
  const ImportedKnowledge({
    required this.fileName,
    required this.text,
    required this.size,
    required this.kind,
    required this.scannedDocument,
  });

  final String fileName;
  final String text;
  final int size;
  final ImportedFileKind kind;
  final bool scannedDocument;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum ImportedFileKind { document, image }

/// All extraction is performed on-device. Only normalized text is later sent
/// to the encrypted local Node runtime; this class never calls a network API.
class LocalKnowledgeImporter {
  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxExtractedCharacters = 180000;
  static const maxScannedPdfPages = 20;
  static const _pdfChannel = MethodChannel('bliss/local_pdf');

  static Future<PlatformFile?> choose({required bool image}) async {
    return FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: image
          ? const ['jpg', 'jpeg', 'png', 'webp']
          : const ['pdf', 'docx', 'txt', 'md'],
    );
  }

  static Future<ImportedKnowledge> extract(
    PlatformFile file, {
    required bool image,
    void Function(String status)? onStatus,
  }) async {
    final size = file.lengthSync() ?? await file.length() ?? 0;
    if (size <= 0 || size > maxFileBytes) {
      throw const FormatException('Ukuran file harus di bawah 20 MB.');
    }
    final extension = file.extension?.toLowerCase() ?? '';
    final path = file.path;
    String text;
    var scanned = false;

    if (image || {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      if (path == null)
        throw const FormatException('Lokasi file tidak tersedia.');
      onStatus?.call('Membaca teks gambar secara lokal…');
      text = await _ocrFile(path);
    } else if (extension == 'txt' || extension == 'md') {
      final bytes = await file.readAsBytes();
      text = utf8.decode(bytes, allowMalformed: true);
    } else if (extension == 'docx') {
      onStatus?.call('Mengekstrak isi dokumen secara lokal…');
      final bytes = await file.readAsBytes();
      text = await compute(_extractDocx, bytes);
    } else if (extension == 'pdf') {
      if (path == null)
        throw const FormatException('Lokasi file tidak tersedia.');
      onStatus?.call('Membaca teks PDF secara lokal…');
      text = await _pdfChannel
              .invokeMethod<String>('extractText', {'path': path}) ??
          '';
      if (_clean(text).length < 40) {
        scanned = true;
        onStatus?.call('PDF berupa scan; OCR lokal maksimal 20 halaman…');
        text = await _ocrPdf(path, onStatus: onStatus);
      }
    } else {
      throw const FormatException('Format file ini belum didukung.');
    }

    text = _clean(text);
    if (text.isEmpty) {
      throw const FormatException(
          'Teks tidak ditemukan. Pastikan gambar jelas atau PDF tidak terkunci.');
    }
    if (text.length > maxExtractedCharacters) {
      text = text.substring(0, maxExtractedCharacters);
    }
    return ImportedKnowledge(
      fileName: file.name,
      text: text,
      size: size,
      kind: image ? ImportedFileKind.image : ImportedFileKind.document,
      scannedDocument: scanned,
    );
  }

  static Future<String> _ocrFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await recognizer.processImage(InputImage.fromFilePath(path)))
          .text;
    } finally {
      await recognizer.close();
    }
  }

  static Future<String> _ocrPdf(
    String path, {
    void Function(String status)? onStatus,
  }) async {
    final document = await PdfDocument.openFile(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final results = <String>[];
    try {
      final pageCount = min(document.pagesCount, maxScannedPdfPages);
      for (var index = 1; index <= pageCount; index++) {
        onStatus?.call('OCR lokal halaman $index dari $pageCount…');
        final page = await document.getPage(index);
        try {
          final width = min(1800.0, max(900.0, page.width * 1.5));
          final height = width * page.height / page.width;
          final rendered = await page.render(
            width: width,
            height: height,
            format: PdfPageImageFormat.jpeg,
            quality: 78,
            backgroundColor: '#FFFFFF',
          );
          if (rendered != null) {
            final temporary = File(
                '${Directory.systemTemp.path}/bliss-kb-${DateTime.now().microsecondsSinceEpoch}-$index.jpg');
            try {
              await temporary.writeAsBytes(rendered.bytes, flush: false);
              results.add((await recognizer
                      .processImage(InputImage.fromFilePath(temporary.path)))
                  .text);
            } finally {
              if (await temporary.exists()) await temporary.delete();
            }
          }
        } finally {
          await page.close();
        }
      }
      return results.join('\n\n');
    } finally {
      await recognizer.close();
      await document.close();
    }
  }

  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null) throw const FormatException('Isi DOCX tidak ditemukan.');
    final document = XmlDocument.parse(utf8.decode(file.content));
    final paragraphs = document.findAllElements('w:p');
    return paragraphs
        .map((paragraph) {
          final text = paragraph
              .findAllElements('w:t')
              .map((node) => node.innerText)
              .join();
          return text.trim();
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static String _clean(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\t\u00a0 ]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final lines = normalized.split('\n');
    final output = <String>[];
    String? previous;
    for (final line in lines) {
      final value = line.trim();
      if (value.isNotEmpty && value == previous) continue;
      output.add(value);
      if (value.isNotEmpty) previous = value;
    }
    return output.join('\n').trim();
  }
}
