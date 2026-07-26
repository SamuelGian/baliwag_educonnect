/// Fuzzy matching between OCR'd document text and applicant-entered data.
library;

String _normalize(String s) {
  return s
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (j) => j);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// Similarity ratio between two strings, 0.0 (nothing alike) to 1.0 (identical).
double _similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  return 1 - (_levenshtein(a, b) / maxLen);
}

/// Result of checking a name against OCR'd document text.
class NameMatchResult {
  final bool matched;
  final double score;
  const NameMatchResult({required this.matched, required this.score});
}

/// Checks whether [fullName] appears (allowing for OCR noise) inside
/// [ocrText]. Splits the name into tokens and requires most of them to be
/// found as a similar word somewhere in the document text.
NameMatchResult matchNameAgainstText(
  String fullName,
  String ocrText, {
  double tokenSimilarityThreshold = 0.75,
  double requiredTokenMatchRatio = 0.6,
}) {
  final nameTokens = _normalize(fullName)
      .split(' ')
      .where((t) => t.length >= 2)
      .toList();
  final docTokens = _normalize(ocrText).split(' ').where((t) => t.isNotEmpty).toList();

  if (nameTokens.isEmpty || docTokens.isEmpty) {
    return const NameMatchResult(matched: false, score: 0);
  }

  var hits = 0;
  for (final nameToken in nameTokens) {
    final bestForToken = docTokens
        .map((docToken) => _similarity(nameToken, docToken))
        .fold<double>(0, (best, s) => s > best ? s : best);
    if (bestForToken >= tokenSimilarityThreshold) hits++;
  }

  final ratio = hits / nameTokens.length;
  return NameMatchResult(matched: ratio >= requiredTokenMatchRatio, score: ratio);
}
