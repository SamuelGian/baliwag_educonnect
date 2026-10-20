/// Fuzzy matching between OCR'd document text and the currently signed-in
/// student's own profile name (never a hardcoded name — callers always pass
/// in `AppState.user.fullName`, so whichever account is logged in is the
/// one being checked against).
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

/// Result of checking a student's profile name against OCR'd document text.
class NameMatchResult {
  /// True only if every "core" name token (first name, last name) was found
  /// in the document text above [matchNameAgainstText]'s similarity
  /// threshold. A missing/extra middle name never blocks this on its own —
  /// see the function doc comment for why.
  final bool nameMatched;

  /// 0.0-1.0 — how closely the profile name matches what's on the document.
  /// Not the same thing as [nameMatched]: a document can score fairly high
  /// (a plausible partial match) without every core token individually
  /// clearing the pass bar, and vice versa.
  final double matchConfidence;

  /// The document's own tokens that best correspond to the profile name,
  /// re-assembled in the order they actually appear in the OCR text (not
  /// the profile's word order) — e.g. a document printed as "DELA CRUZ,
  /// JUAN" surfaces here as "DELA CRUZ JUAN", not silently reordered to
  /// match the profile. Empty if nothing in the document resembled the name
  /// at all.
  final String extractedName;

  /// The profile name this was checked against, as given by the caller.
  final String expectedName;

  const NameMatchResult({
    required this.nameMatched,
    required this.matchConfidence,
    required this.extractedName,
    required this.expectedName,
  });
}

/// Checks whether [expectedName] — always the *currently signed-in*
/// student's own `AppState.user.fullName`, never a literal/hardcoded name —
/// appears (allowing for OCR noise) inside [ocrText].
///
/// The name is split into tokens and compared to [ocrText]'s tokens by
/// fuzzy (Levenshtein) similarity, independent of word order, so it doesn't
/// matter whether a document prints "Juan Dela Cruz" or "DELA CRUZ, JUAN
/// M." — both compare token-by-token, not as a fixed sequence.
///
/// First and last name are treated as the "core" identity signal and must
/// each individually clear [tokenSimilarityThreshold]; anything in between
/// (a middle name or initial) is scored as a *bonus*, never required —
/// because it commonly appears on only one side: a profile might store
/// "Juan Carlos Dela Cruz" while the printed document only has "Juan Dela
/// Cruz" (or the reverse, a document showing a middle initial the profile
/// never recorded). Penalizing that mismatch as if it were a wrong identity
/// would produce exactly the false "needs manual review" flood this
/// function exists to avoid.
///
/// Worked examples (illustrative, not an exhaustive test suite):
/// - expectedName "Juan Dela Cruz", ocrText "...JUAN DELA CRUZ 4th Year
///   BSIT..." → both core tokens match near-exactly → nameMatched: true,
///   matchConfidence ~1.0.
/// - expectedName "Maria Santos Reyes", ocrText "...MARIA REYES
///   Barangay..." (middle name never printed) → both core tokens ("MARIA",
///   "REYES") still match → nameMatched: true, matchConfidence slightly
///   below 1.0 (middle-name bonus not earned, but not required).
/// - expectedName "Jose Dela Cruz", ocrText from a blurry scan reading
///   "JOSE DE1A CRUZ" (OCR misread "L" as "1") → similarity for "DELA" vs
///   "DE1A" is high but not exact → still clears the threshold →
///   nameMatched: true.
/// - expectedName "Ana Lim", ocrText is a Certificate of Indigency for a
///   completely different person, "PEDRO GARCIA" → neither core token finds
///   a similar match → nameMatched: false, matchConfidence low → flagged
///   for manual review rather than silently approved or auto-rejected.
NameMatchResult matchNameAgainstText(
  String expectedName,
  String ocrText, {
  double tokenSimilarityThreshold = 0.86,
  int minDocTokens = 3,
}) {
  final trimmedExpected = expectedName.trim();
  final nameTokens = _normalize(
    expectedName,
  ).split(' ').where((t) => t.length >= 2).toList();
  final docTokens = _normalize(
    ocrText,
  ).split(' ').where((t) => t.length >= 2).toList();

  if (nameTokens.isEmpty || docTokens.length < minDocTokens) {
    return NameMatchResult(
      nameMatched: false,
      matchConfidence: 0,
      extractedName: '',
      expectedName: trimmedExpected,
    );
  }

  final coreTokens = nameTokens.length == 1
      ? [nameTokens.first]
      : [nameTokens.first, nameTokens.last];
  final middleTokens = nameTokens.length > 2
      ? nameTokens.sublist(1, nameTokens.length - 1)
      : const <String>[];

  double bestSimilarityFor(String token) {
    var best = 0.0;
    for (final docToken in docTokens) {
      final s = _similarity(token, docToken);
      if (s > best) best = s;
    }
    return best;
  }

  String bestDocTokenFor(String token) {
    var best = '';
    var bestScore = 0.0;
    for (final docToken in docTokens) {
      final s = _similarity(token, docToken);
      if (s > bestScore) {
        bestScore = s;
        best = docToken;
      }
    }
    return bestScore >= tokenSimilarityThreshold ? best : '';
  }

  final coreScores = coreTokens.map(bestSimilarityFor).toList();
  final nameMatched = coreScores.every((s) => s >= tokenSimilarityThreshold);
  final coreAvg = coreScores.reduce((a, b) => a + b) / coreScores.length;

  var middleBonus = 1.0;
  if (middleTokens.isNotEmpty) {
    final found = middleTokens
        .where((t) => bestSimilarityFor(t) >= tokenSimilarityThreshold)
        .length;
    middleBonus = found / middleTokens.length;
  }

  final matchConfidence = (0.8 * coreAvg + 0.2 * middleBonus).clamp(0.0, 1.0);

  // Re-assemble the matched name in the document's own word order (see
  // NameMatchResult.extractedName doc comment) rather than echoing the
  // profile's token order back.
  final matchedDocTokens = <String>{
    for (final t in nameTokens) bestDocTokenFor(t),
  }..remove('');
  final extractedTokens = <String>[];
  for (final docToken in docTokens) {
    if (matchedDocTokens.contains(docToken) &&
        !extractedTokens.contains(docToken)) {
      extractedTokens.add(docToken);
    }
  }

  return NameMatchResult(
    nameMatched: nameMatched,
    matchConfidence: matchConfidence,
    extractedName: extractedTokens.join(' '),
    expectedName: trimmedExpected,
  );
}
