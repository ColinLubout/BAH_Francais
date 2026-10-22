/// A Conjugation prompt from a sentence written in full.
library;

/// The blank a prompt shows where the verb goes.
const blank = '___';

/// The elided words that can stand just before a verb, and their full form.
/// A prompt writes them in full, since what the user types decides whether
/// they elide (*J’habite* → *Je ___*). *l’* can be *le* or *la*, so a
/// sentence says which.
const Map<String, String> fullForms = {
  'j': 'je',
  'm': 'me',
  't': 'te',
  's': 'se',
  'n': 'ne',
  'c': 'ce',
};

final _letter = RegExp(r'\p{L}', unicode: true);
final _elided = RegExp(r"(?:^|[^\p{L}])(\p{L}+)[’']$", unicode: true);

/// Where [words] stands in [text] as whole words, ignoring case, if it does
/// exactly once.
({int start, int end})? findOnce(String text, String words) {
  if (words.isEmpty) return null;
  final lowerText = text.toLowerCase();
  final lowerWords = words.toLowerCase();
  ({int start, int end})? found;
  for (
    var start = lowerText.indexOf(lowerWords);
    start >= 0;
    start = lowerText.indexOf(lowerWords, start + 1)
  ) {
    final end = start + words.length;
    final before = start == 0 ? '' : text[start - 1];
    final after = end == text.length ? '' : text[end];
    if (_letter.hasMatch(before) || _letter.hasMatch(after)) continue;
    if (found != null) return null;
    found = (start: start, end: end);
  }
  return found;
}

/// The elided word that ends just before [start] in [text], without its
/// apostrophe (`J` in *J’habite*), or null.
String? elidedBefore(String text, int start) =>
    _elided.firstMatch(text.substring(0, start))?.group(1);

/// [text] with [answer] blanked out and an elided word just before it
/// written in full, as the Conjugation drill shows it: *J’habite à
/// Marseille.* → *Je ___ à Marseille.* [before] is *le* or *la* for an
/// elided *l’*.
///
/// Null if [answer] isn't in [text] exactly once, or if the word before it
/// can't be written in full: an *l’* without [before], another elided word,
/// or [before] given with no *l’*.
String? conjugationPrompt(String text, String answer, {String? before}) {
  final at = findOnce(text, answer);
  if (at == null) return null;
  var head = text.substring(0, at.start);
  final elided = elidedBefore(text, at.start);
  if (elided == null) {
    if (before != null) return null;
  } else {
    final lower = elided.toLowerCase();
    final full = lower == 'l'
        ? (before == 'le' || before == 'la' ? before : null)
        : (before == null ? fullForms[lower] : null);
    if (full == null) return null;
    final capital = elided[0] != elided[0].toLowerCase();
    final written = capital ? full[0].toUpperCase() + full.substring(1) : full;
    head = '${head.substring(0, head.length - elided.length - 1)}$written ';
  }
  return '$head$blank${text.substring(at.end)}';
}
