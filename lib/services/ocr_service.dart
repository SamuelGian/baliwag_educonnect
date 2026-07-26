import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => message;
}

/// Thin client for the OCR.space free-tier REST API.
/// https://ocr.space/ocrapi
class OcrService {
  static const _endpoint = 'https://api.ocr.space/parse/image';

  /// Extracts and returns all recognized text from an uploaded document.
  /// Throws [OcrException] if the key is missing, the request fails, or
  /// the API reports a parse error.
  Future<String> extractText({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (ocrSpaceApiKey.isEmpty || ocrSpaceApiKey == 'YOUR_OCR_SPACE_API_KEY_HERE') {
      throw OcrException(
        'No OCR API key configured. Get a free key at ocr.space/ocrapi and '
        'paste it into lib/config/secrets.dart.',
      );
    }

    final ext = fileName.split('.').last.toLowerCase();
    final fileType = switch (ext) {
      'pdf' => 'PDF',
      'jpg' || 'jpeg' => 'JPG',
      'png' => 'PNG',
      _ => 'JPG',
    };

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..fields['apikey'] = ocrSpaceApiKey
      ..fields['language'] = 'eng'
      ..fields['OCREngine'] = '2'
      ..fields['scale'] = 'true'
      ..fields['isOverlayRequired'] = 'false'
      ..fields['filetype'] = fileType
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw OcrException('Could not reach OCR service: $e');
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw OcrException('OCR service returned ${response.statusCode}.');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw OcrException('OCR service returned an unreadable response.');
    }

    if (body['IsErroredOnProcessing'] == true) {
      final err = body['ErrorMessage'];
      final msg = err is List ? err.join(', ') : err.toString();
      throw OcrException(msg.isEmpty ? 'OCR processing failed.' : msg);
    }

    final results = body['ParsedResults'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return '';
    }
    return results
        .map((r) => (r as Map<String, dynamic>)['ParsedText']?.toString() ?? '')
        .join('\n');
  }
}
