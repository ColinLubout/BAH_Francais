import 'package:bah_francais/features/drills/domain/grading/grade.dart';

/// The apostrophe answers are compared with. ’ and ' count as the same.
const apostrophe = '’';

/// Prepares an answer for comparison: trims it, ignores case, treats ’ and '
/// as the same, collapses runs of spaces, and ignores a space typed after an
/// apostrophe (*j’ aime* is *j’aime*).
String normalise(String answer) => answer
    .trim()
    .toLowerCase()
    .replaceAll("'", apostrophe)
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('$apostrophe ', apostrophe);

/// Accented letters and what they are without the accent. œ and æ fold to
/// two letters, so *oe* typed for *œ* is an accent slip, not a wrong answer.
const _folds = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ñ': 'n',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'œ': 'oe',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ý': 'y',
};

/// [text] (already normalised) with its accents removed.
String foldAccents(String text) =>
    text.split('').map((char) => _folds[char] ?? char).join();

/// Where [expected] and [typed] differ, as ranges of [expected], when they
/// differ only by accents: `foldAccents(expected) == foldAccents(typed)`.
/// Both are normalised and the same length apart from œ/æ written as two
/// letters.
List<Span> accentSpans(String expected, String typed) {
  final spans = <Span>[];
  var i = 0;
  var j = 0;
  while (i < expected.length && j < typed.length) {
    final e = expected[i];
    final t = typed[j];
    final foldedE = foldAccents(e);
    final foldedT = foldAccents(t);
    if (e == t) {
      i++;
      j++;
    } else if (foldedE == foldedT) {
      spans.add(Span(i, i + 1));
      i++;
      j++;
    } else if (foldedE.length == 2 &&
        j + 2 <= typed.length &&
        foldAccents(typed.substring(j, j + 2)) == foldedE) {
      // oe typed for œ.
      spans.add(Span(i, i + 1));
      i++;
      j += 2;
    } else if (foldedT.length == 2 &&
        i + 2 <= expected.length &&
        foldAccents(expected.substring(i, i + 2)) == foldedT) {
      // œ typed for oe.
      spans.add(Span(i, i + 2));
      i += 2;
      j++;
    } else {
      // Not an accent-only difference: mark the rest.
      spans.add(Span(i, expected.length));
      return spans;
    }
  }
  return spans;
}
