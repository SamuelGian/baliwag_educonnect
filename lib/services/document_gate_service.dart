import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class DocumentGateException implements Exception {
  final String message;
  DocumentGateException(this.message);
  @override
  String toString() => message;
}

/// Verdict from [DocumentGateService.check]. [detectedContent] is always
/// populated on a successful call (even when [accepted] is true) so a
/// rejection message can say exactly what Gemini actually saw instead of a
/// generic "wrong document" — e.g. "a photo of a rabbit" rather than just
/// "mismatch".
class DocumentGateResult {
  final bool accepted;
  final String detectedContent;
  final String reason;

  const DocumentGateResult({
    required this.accepted,
    required this.detectedContent,
    required this.reason,
  });
}

/// Immediate, pick-time gate that looks at an uploaded file with Gemini
/// Vision and asks a narrow question: does this plausibly serve as the
/// specific document type a scholarship requirement asks for, or is it
/// something else entirely (a random photo, a different document, a blank
/// page)? This runs *before* a file is ever accepted into an application
/// draft — it is deliberately not a replacement for the OCR.space +
/// [DocumentValidationService] pipeline that still runs after submission
/// (that one checks the applicant's own name against the text; this one
/// only checks "is this even the right kind of document").
class DocumentGateService {
  static const _model = 'gemini-3.8-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<DocumentGateResult> check({
    required Uint8List bytes,
    required String fileName,
    required String expectedDocumentName,
  }) async {
    if (geminiApiKey.isEmpty || geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw DocumentGateException(
        'No Gemini API key configured. Get a free key at '
        'aistudio.google.com/apikey and paste it into lib/config/secrets.dart.',
      );
    }

    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };

    final prompt =
        'You are a document gatekeeper for a Philippine scholarship '
        'application portal. The applicant is uploading a file for the '
        'requirement: "$expectedDocumentName".\n\n'
        'Look at the attached file and decide whether it plausibly serves as '
        'that requirement — e.g. an official certificate, ID, enrollment '
        'form, grade slip, or other document/photo-of-a-document that could '
        'reasonably be submitted for "$expectedDocumentName". It does not '
        'need to be perfectly legible or fully confirm the content (that is '
        "checked separately) — only reject it if it is clearly NOT a "
        'document/ID/certificate at all, or is obviously an unrelated '
        'subject (an animal, a random object, a selfie, a meme, scenery, a '
        'blank page, etc).\n\n'
        'Respond ONLY with compact JSON in this exact shape, no other text:\n'
        '{"accepted": true or false, "detectedContent": "a short, concrete '
        'description of what the image/file actually shows", "reason": "one '
        'short sentence explaining the decision"}';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Encode(bytes)},
            },
          ],
        },
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_endpoint?key=$geminiApiKey'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw DocumentGateException('Could not reach Gemini: $e');
    }

    if (response.statusCode != 200) {
      throw DocumentGateException(
        'Gemini returned ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw DocumentGateException('Gemini returned an unreadable response.');
    }

    final candidates = decoded['candidates'] as List<dynamic>?;
    final content = candidates != null && candidates.isNotEmpty
        ? (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?
        : null;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts
        ?.map((p) => (p as Map<String, dynamic>)['text']?.toString() ?? '')
        .join();

    if (text == null || text.trim().isEmpty) {
      throw DocumentGateException('Gemini returned an empty verdict.');
    }

    final Map<String, dynamic> verdict;
    try {
      verdict = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw DocumentGateException('Gemini returned a non-JSON verdict.');
    }

    return DocumentGateResult(
      accepted: verdict['accepted'] as bool? ?? true,
      detectedContent:
          verdict['detectedContent'] as String? ?? '(not described)',
      reason: verdict['reason'] as String? ?? '',
    );
  }
}
