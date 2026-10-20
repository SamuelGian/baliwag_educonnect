import 'ocr_service.dart';

/// Outcome of running an OCR'd document through [DocumentValidationService].
class DocumentValidationResult {
  final bool valid;

  /// A heuristic 0.0–1.0 estimate, NOT a real confidence score from the OCR
  /// engine (OCR.space's API doesn't expose one — see [OcrResult]). It's a
  /// weighted blend of how much text was found, how much of it looks like
  /// real words rather than scan noise, and (when the document type is
  /// recognized) how many expected keywords showed up.
  final double confidence;

  /// Human-readable explanation shown to the admin/student — always says
  /// *why*, not just pass/fail, so a flagged document is actually
  /// actionable instead of a mystery.
  final String reason;

  const DocumentValidationResult({
    required this.valid,
    required this.confidence,
    required this.reason,
  });
}

class _DocCategory {
  final String label;
  final bool Function(String nameLower) matches;
  final List<String> keywords;

  const _DocCategory({
    required this.label,
    required this.matches,
    required this.keywords,
  });
}

final List<_DocCategory> _categories = [
  _DocCategory(
    label: 'Certificate of Indigency',
    matches: (n) => n.contains('indigen'),
    keywords: const [
      'indigent',
      'indigency',
      'certify',
      'certification',
      'barangay',
      'income',
    ],
  ),
  _DocCategory(
    label: 'Certificate of Enrollment / Registration',
    matches: (n) =>
        n.contains('enroll') ||
        n.contains('registration') ||
        RegExp(r'\bcor\b').hasMatch(n),
    keywords: const [
      'enrolled',
      'enrollment',
      'registration',
      'registrar',
      'semester',
      'school year',
      'academic year',
      'units',
    ],
  ),
  _DocCategory(
    label: 'Grade Slip / Form 137',
    matches: (n) => n.contains('grade') || n.contains('137'),
    keywords: const [
      'grade',
      'grades',
      'units',
      'subject',
      'average',
      'gwa',
      'rating',
      'semester',
    ],
  ),
  _DocCategory(
    label: 'Barangay Certificate of Residency',
    matches: (n) =>
        n.contains('residen') ||
        (n.contains('barangay') && !n.contains('indigen')),
    keywords: const [
      'barangay',
      'resident',
      'residency',
      'certify',
      'certification',
    ],
  ),
  _DocCategory(
    label: 'Certificate of Good Moral Character',
    matches: (n) => n.contains('good moral') || n.contains('moral character'),
    keywords: const ['moral', 'character', 'conduct', 'certify'],
  ),
  _DocCategory(
    label: 'Recommendation Letter',
    matches: (n) => n.contains('recommend'),
    keywords: const ['recommend', 'endorse', 'character'],
  ),
];

/// Checks whether OCR'd document text actually looks like the kind of
/// document it's supposed to be — not just "was any text extracted at
/// all?" (the old, exploitable check: a blurry or blank photo would still
/// often OCR to a handful of stray characters and sail through).
///
/// The requirement name is admin-authored free text (e.g. a scholarship's
/// requirements list), so it isn't a fixed enum — this only recognizes
/// common Philippine scholarship document types by keyword-matching the
/// requirement's name; anything unrecognized (a custom requirement, a
/// generic "Valid ID") falls back to length + word-quality checks only,
/// with no specific-content requirement.
class DocumentValidationService {
  /// Below this many characters, a document is rejected outright — this is
  /// the "blank or garbage image" floor. 20–30 chars was the requested
  /// range; 25 sits in the middle.
  static const int minChars = 25;

  /// At or above this many characters, the length factor maxes out — more
  /// text beyond this doesn't make a document more "valid".
  static const int fullConfidenceChars = 60;

  /// Confidence at or above this is treated as a pass. Chosen so that a
  /// clear, on-topic scan comfortably clears it while a noisy or
  /// off-topic one doesn't — see the worked examples in the module's test
  /// notes / PR description, not hard science.
  static const double validThreshold = 0.62;

  DocumentValidationResult validate({
    required String documentName,
    required OcrResult ocr,
  }) {
    final text = ocr.text.trim();

    if (text.length < minChars) {
      return DocumentValidationResult(
        valid: false,
        confidence: 0.0,
        reason:
            'Document appears blank or unreadable — only ${text.length} '
            'character(s) of text were detected. Try a clearer photo or scan.',
      );
    }

    final lengthScore =
        ((text.length - minChars) / (fullConfidenceChars - minChars)).clamp(
          0.0,
          1.0,
        );

    final words = ocr.words.isNotEmpty ? ocr.words : text.split(RegExp(r'\s+'));
    final meaningfulWords = words.where((w) => w.trim().isNotEmpty).toList();
    final realWordCount = meaningfulWords.where(_looksLikeRealWord).length;
    final wordQualityScore = meaningfulWords.isEmpty
        ? 0.0
        : realWordCount / meaningfulWords.length;

    final category = _categoryFor(documentName);
    final lowerText = text.toLowerCase();

    final double confidence;
    final String reason;

    if (category != null) {
      final matchedKeywords = category.keywords
          .where((k) => lowerText.contains(k))
          .toList();
      final keywordScore = (matchedKeywords.length / category.keywords.length)
          .clamp(0.0, 1.0);
      confidence =
          0.30 * lengthScore + 0.25 * wordQualityScore + 0.45 * keywordScore;

      if (matchedKeywords.isEmpty) {
        reason =
            'Extracted text doesn\'t contain any wording expected in a '
            '${category.label} (looking for words like: '
            '${category.keywords.take(4).join(', ')}). Please verify this is '
            'the correct document.';
      } else if (confidence >= validThreshold) {
        reason =
            'Content matches a ${category.label} '
            '(found: ${matchedKeywords.take(3).join(', ')}).';
      } else {
        reason =
            'Found some expected wording (${matchedKeywords.take(3).join(', ')}) '
            'but overall text quality is low (blurry scan or heavy OCR noise) — '
            'please verify manually.';
      }
    } else {
      // Unrecognized / freeform requirement (e.g. a custom admin-added
      // requirement, or a generic "Valid ID" whose content varies too much
      // to keyword-match) — judge purely on whether the OCR text looks like
      // genuine, readable content at all.
      confidence = 0.55 * lengthScore + 0.45 * wordQualityScore;
      reason = confidence >= validThreshold
          ? 'Document has readable, plausible text content.'
          : 'Text quality is low (blurry scan, noise, or a mostly-blank '
                'page) — please verify manually.';
    }

    return DocumentValidationResult(
      valid: confidence >= validThreshold,
      confidence: confidence,
      reason: reason,
    );
  }

  bool _looksLikeRealWord(String w) {
    final cleaned = w.trim();
    if (cleaned.length < 2 || cleaned.length > 25) return false;
    final letters = cleaned.runes
        .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
        .length;
    return letters / cleaned.length >= 0.6;
  }

  _DocCategory? _categoryFor(String documentName) {
    final lower = documentName.toLowerCase();
    for (final c in _categories) {
      if (c.matches(lower)) return c;
    }
    return null;
  }
}
