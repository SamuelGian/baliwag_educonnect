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

/// Result of a successful OCR call. [words] comes from OCR.space's word
/// overlay data (bounding boxes) — it does NOT include a confidence score;
/// OCR.space's REST API has no per-word or per-character confidence field
/// at all, unlike engines such as Google Cloud Vision or Tesseract's hOCR
/// output. [words] is exposed anyway because it's still useful on its own:
/// [DocumentValidationService] uses it to estimate text quality (what
/// fraction of "words" look like real words vs. OCR noise), which is a
/// legitimate signal even without true confidence numbers.
class OcrResult {
  final String text;
  final List<String> words;

  const OcrResult({required this.text, required this.words});
}

/// Thin client for the OCR.space free-tier REST API.
/// https://ocr.space/ocrapi
class OcrService {
  static const _endpoint = 'https://api.ocr.space/parse/image';

  /// Runs OCR on [bytes] and returns both the recognized text and its
  /// per-word breakdown. Throws [OcrException] if the key is missing, the
  /// request fails, or the API reports a parse error.
  Future<OcrResult> extractText({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (ocrSpaceApiKey.isEmpty ||
        ocrSpaceApiKey == 'YOUR_OCR_SPACE_API_KEY_HERE') {
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
      ..fields['detectOrientation'] = 'true'
      ..fields['isOverlayRequired'] = 'true'
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

    final http.Response response;
    try {
      // The connection succeeding (above) doesn't guarantee the body ever
      // finishes arriving — without its own timeout, a stalled response
      // stream leaves this hanging indefinitely, stuck on "Verifying with
      // OCR…" forever with no error surfaced anywhere.
      response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw OcrException('OCR service took too long to respond: $e');
    }
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
      return const OcrResult(text: '', words: []);
    }

    final text = results
        .map((r) => (r as Map<String, dynamic>)['ParsedText']?.toString() ?? '')
        .join('\n');

    final words = <String>[];
    for (final r in results) {
      final overlay =
          (r as Map<String, dynamic>)['TextOverlay'] as Map<String, dynamic>?;
      final lines = overlay?['Lines'] as List<dynamic>?;
      if (lines == null) continue;
      for (final line in lines) {
        final lineWords =
            (line as Map<String, dynamic>)['Words'] as List<dynamic>?;
        if (lineWords == null) continue;
        for (final w in lineWords) {
          final wordText = (w as Map<String, dynamic>)['WordText']?.toString();
          if (wordText != null && wordText.isNotEmpty) words.add(wordText);
        }
      }
    }

    return OcrResult(text: text, words: words);
  }
}
