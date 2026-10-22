import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/sentence_prompt.dart';
import 'package:meta/meta.dart';

/// What a Conjugaison card needs from its verb, in its tense.
@immutable
class ConjugationItem {
  const ConjugationItem({
    required this.verbId,
    required this.infinitive,
    required this.tense,
    this.hAspire = false,
    this.sentences = const [],
  });

  final String verbId;
  final String infinitive;
  final Tense tense;

  /// A form starts with an *h* that doesn't elide (*je hais*).
  final bool hAspire;

  /// The sentences that are prompts for the verb in [tense], every person.
  final List<ConjugationSentence> sentences;
}

/// A sentence that is a Conjugaison prompt, for one person.
@immutable
class ConjugationSentence {
  const ConjugationSentence({
    required this.id,
    required this.text,
    required this.person,
    required this.answer,
    this.alternatives = const [],
    this.before,
  });

  final String id;

  /// Written in full, in plain French.
  final String text;
  final Person person;

  /// The words that fill the blank, as [text] has them (*sommes allés*).
  final String answer;

  /// Other forms accepted (*paie* / *paye*).
  final List<String> alternatives;

  /// *le* or *la*, when an *l’* comes just before [answer].
  final String? before;

  /// The words around the blank: [text] with [answer] blanked out, and an
  /// elided word just before it written in full (*J’habite à Marseille.* →
  /// *Je* and *à Marseille.*). Null if it can't be blanked, which the
  /// content validator never lets through.
  (String, String)? get aroundBlank {
    final prompt = conjugationPrompt(text, answer, before: before);
    if (prompt == null) return null;
    final at = prompt.indexOf(blank);
    return (prompt.substring(0, at), prompt.substring(at + blank.length));
  }
}

final _vowel = RegExp('^[aeiouyàâäéèêëîïôöùûüœæ]');
final _lastWord = RegExp(r'(\p{L}+) $', unicode: true);

/// The words written in full before a blank, adjusted to what the user is
/// typing (decision 43): if [typed] starts with a vowel or a silent *h*, the
/// word just before the blank elides — *je* → *j’*, *me* → *m’*, *te* →
/// *t’*, *se* → *s’*, *ne* → *n’*, *le* / *la* → *l’*, *ce* → *c’*.
/// [hAspire]: the verb's *h* doesn't elide (*je hais*).
String elideBefore(String before, String typed, {required bool hAspire}) {
  final start = typed.trimLeft().toLowerCase();
  final elides = _vowel.hasMatch(start) || (start.startsWith('h') && !hAspire);
  if (!elides) return before;
  final match = _lastWord.firstMatch(before);
  if (match == null) return before;
  final word = match.group(1)!;
  if (!_elidable.contains(word.toLowerCase())) return before;
  return '${before.substring(0, match.start)}${word[0]}’';
}

const _elidable = {'je', 'me', 'te', 'se', 'ne', 'le', 'la', 'ce'};
