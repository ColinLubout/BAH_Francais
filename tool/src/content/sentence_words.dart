/// Checks the words of the content's sentences against the dictionary
/// (decision 64): a sentence's nouns and verbs are the content's own, its
/// conjugated verbs are in a tense the content teaches, and no infinitive
/// follows a conjugated verb (*je vais finir* is the futur proche).
///
/// It works from each word's parts of speech, so it can only advise: a word
/// the dictionary gives as both a noun and an adjective, say, may be either.
library;

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';

import 'dictionary.dart' show Finding;

/// Elided words, kept with their apostrophe: *l’* in *l’homme*.
const _elided = {
  'j’',
  'l’',
  'd’',
  'n’',
  's’',
  'c’',
  'm’',
  't’',
  'qu’',
  'jusqu’',
  'lorsqu’',
  'puisqu’',
  'quoiqu’',
};

/// Words that come before a noun.
const _determiners = {
  'le',
  'la',
  'l’',
  'les',
  'un',
  'une',
  'des',
  'du',
  'mon',
  'ma',
  'mes',
  'ton',
  'ta',
  'tes',
  'son',
  'sa',
  'ses',
  'notre',
  'nos',
  'votre',
  'vos',
  'leur',
  'leurs',
  'ce',
  'cet',
  'cette',
  'ces',
  'quel',
  'quelle',
  'quels',
  'quelles',
  'chaque',
  'aucun',
  'aucune',
  'plusieurs',
};

/// Words that can follow a determiner without being a noun: *un peu*.
const _notNouns = {
  'peu',
  'plus',
  'moins',
  'même',
  'mêmes',
  'autre',
  'autres',
  'tout',
  'tous',
  'toute',
  'toutes',
};

/// What can stand between a conjugated verb and an infinitive or
/// participle: *je ne le fais pas*, *a-t-il déjà fini*.
const _between = {
  'ne',
  'n’',
  'me',
  'm’',
  'te',
  't’',
  'se',
  's’',
  'le',
  'la',
  'l’',
  'les',
  'lui',
  'leur',
  'y',
  'en',
  'nous',
  'vous',
  'je',
  'tu',
  'il',
  'elle',
  'on',
  'ils',
  'elles',
  't',
  'ce',
  'pas',
  'plus',
  'jamais',
  'rien',
  'déjà',
  'toujours',
  'encore',
  'bien',
  'mal',
  'beaucoup',
  'trop',
  'peu',
  'souvent',
  'vraiment',
  'tout',
  'tous',
  'aussi',
  'très',
};

/// Words ending like an infinitive that the dictionary also gives as a verb
/// form, but aren't verbs in a sentence.
const _notVerbs = {'hier'};

const _avoir = {'ai', 'as', 'a', 'avons', 'avez', 'ont'};
const _etre = {'suis', 'es', 'est', 'sommes', 'êtes', 'sont'};

final _word = RegExp(r'[\p{L}’\-]+', unicode: true);
final _infinitive = RegExp(r'(er|ir|re|oir)$');

/// The words of [text], lowercased, with elided words split off (*l’*,
/// *qu’*). A hyphenated word is kept whole when [known] has it (*peut-être*)
/// and split otherwise (*est-ce*, *a-t-il*).
List<String> sentenceTokens(String text, bool Function(String) known) {
  final tokens = <String>[];
  for (final m in _word.allMatches(normalise(text))) {
    var w = m[0]!;
    final at = w.indexOf(apostrophe);
    if (at > 0 && at < w.length - 1) {
      final head = w.substring(0, at + 1);
      if (_elided.contains(head)) {
        tokens.add(head);
        w = w.substring(at + 1);
      }
    }
    if (!w.contains('-') || known(w)) {
      tokens.add(w);
    } else {
      tokens.addAll(w.split('-').where((p) => p.isNotEmpty));
    }
  }
  return tokens;
}

/// Every word the dictionary needs to say something about: each sentence
/// word, whole and split.
Set<String> sentenceWords(ContentSet content) => <String>{
  for (final s in content.sentences)
    for (final m in _word.allMatches(normalise(s.text))) ...[
      m[0]!,
      ...sentenceTokens(m[0]!, (_) => true),
      ...sentenceTokens(m[0]!, (_) => false),
    ],
};

/// The ways [word] is written in the plural, as far as the common rules go.
List<String> _plurals(String word) {
  if (RegExp(r'[sxz]$').hasMatch(word)) return const [];
  if (word.endsWith('eau') || word.endsWith('eu')) return ['${word}x'];
  if (word.endsWith('al')) return ['${word.substring(0, word.length - 2)}aux'];
  if (word.endsWith('ail')) {
    return ['${word}s', '${word.substring(0, word.length - 3)}aux'];
  }
  return ['${word}s'];
}

/// What the sentences of [content] use that breaks decision 64, given each
/// word's parts of speech in [partsOfSpeech] (`noun`, `verb`, `adj`…).
List<Finding> checkSentenceWords(
  ContentSet content,
  Map<String, Set<String>> partsOfSpeech,
) {
  // The words that are the content's own.
  final verbForms = <String>{};
  final otherTense = <String, String>{}; // word -> "être in the imparfait"
  final infinitives = <String>{};
  for (final v in content.verbs) {
    infinitives.addAll(normalise(v.infinitive).split(' '));
    for (final f in v.forms) {
      for (final form in [f.form, ...f.alternatives]) {
        for (final w in normalise(form).split(' ')) {
          if (content.tenses.contains(f.tense)) {
            verbForms.add(w);
          } else {
            otherTense.putIfAbsent(
              w,
              () => '${v.infinitive} in the ${f.tense.id}',
            );
          }
        }
      }
    }
  }
  final nouns = <String>{
    for (final n in content.nouns)
      for (final w in [n.word, ...n.synonyms.map((s) => s.word)]) ...[
        normalise(w),
        ..._plurals(normalise(w)),
      ],
    for (final s in content.sentences)
      for (final n in s.nouns) normalise(n.word),
  };
  for (final s in content.sentences) {
    for (final v in s.verbs) {
      verbForms.addAll(normalise(v.answer).split(' '));
    }
  }
  final ours = {...verbForms, ...infinitives, ...nouns};

  final findings = <Finding>[];
  for (final sentence in content.sentences) {
    final tokens = sentenceTokens(
      sentence.text,
      (w) => partsOfSpeech.containsKey(w) || ours.contains(w),
    );
    final said = <String>{};
    void note(String message) {
      if (said.add(message)) {
        findings.add(Finding(sentence.id, message, difference: false));
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final w = tokens[i];
      if (ours.contains(w) || _elided.contains(w) || w == 't') continue;
      final pos = partsOfSpeech[w];
      if (otherTense[w] case final which? when !verbForms.contains(w)) {
        if (pos == null || pos.difference({'verb'}).isEmpty) {
          note('"$w" is $which, a tense the content doesn’t teach');
          continue;
        }
      }
      if (pos == null) {
        note('"$w" isn’t in the dictionary');
      } else if (pos.difference({'noun', 'verb', 'name'}).isEmpty) {
        note('"$w" is a noun or verb the content doesn’t have');
      } else if (pos.contains('verb') &&
          !pos.contains('adj') &&
          !_notVerbs.contains(w) &&
          _infinitive.hasMatch(w)) {
        note('"$w" may be a verb the content doesn’t have');
      } else if ((pos.contains('noun') || pos.contains('adj')) &&
          !_notNouns.contains(w) &&
          i > 0 &&
          _determiners.contains(tokens[i - 1]) &&
          !_ourNounAfter(tokens, i, nouns, partsOfSpeech)) {
        note(
          '"${tokens[i - 1]} $w": "$w" may be a noun the content doesn’t '
          'have',
        );
      }
    }

    // What follows a conjugated verb.
    for (var i = 0; i < tokens.length; i++) {
      final verb = tokens[i];
      if (!verbForms.contains(verb)) continue;
      var j = i + 1;
      while (j < tokens.length && _between.contains(tokens[j])) {
        j++;
      }
      if (j >= tokens.length) continue;
      final next = tokens[j];
      final pos = partsOfSpeech[next] ?? const <String>{};
      if (infinitives.contains(next)) {
        note('"$verb … $next": an infinitive straight after a conjugated verb');
      } else if (!content.tenses.contains(Tense.passeCompose) &&
          !ours.contains(next) &&
          pos.contains('verb') &&
          !_infinitive.hasMatch(next) &&
          // Être before an adjective is the present: je suis fatigué.
          (_avoir.contains(verb) ||
              (_etre.contains(verb) && !pos.contains('adj')))) {
        note(
          '"$verb … $next" may be a compound tense, which the content '
          'doesn’t teach',
        );
      }
    }
  }
  return findings;
}

/// Whether one of [nouns] follows the determiner before [tokens]\[i], maybe
/// after an adjective: *une petite maison*, *un beau petit chat*.
bool _ourNounAfter(
  List<String> tokens,
  int i,
  Set<String> nouns,
  Map<String, Set<String>> partsOfSpeech,
) {
  bool noun(int j) => j < tokens.length && nouns.contains(tokens[j]);
  bool adjective(int j) =>
      j < tokens.length && (partsOfSpeech[tokens[j]]?.contains('adj') ?? false);
  return noun(i + 1) || (adjective(i + 1) && noun(i + 2));
}
