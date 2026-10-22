/// Grammar concepts and their CEFR levels (decision 65), and the detection
/// that tags a sentence with the concepts it uses.
///
/// The detection works from the content's own verbs and nouns and from the
/// grammar words (articles, pronouns, negations…), so it needs no
/// dictionary. Sentences only use the content's nouns and verbs (decision
/// 64), which keeps it reliable; what it gets wrong is corrected by hand in
/// the content files, and `tool/grammar_tag.dart` never overwrites tags.
library;

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';

/// The levels of the Common European Framework, in the order courses teach
/// them.
enum CefrLevel {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2');

  CefrLevel(this.id);

  final String id;

  static CefrLevel? of(String id) {
    for (final level in values) {
      if (level.id == id) return level;
    }
    return null;
  }
}

/// A grammar concept and the level courses usually teach it at.
class GrammarConcept {
  const GrammarConcept({
    required this.id,
    required this.level,
    required this.name,
    this.example,
    this.note,
  });

  final String id;
  final CefrLevel level;

  /// The concept as French courses name it: *La négation ne… pas*.
  final String name;
  final String? example;
  final String? note;
}

/// The concepts in `grammar.json`, as its schema allows them, by id.
List<GrammarConcept> conceptsFromJson(Map<String, Object?> json) => [
  for (final c in (json['concepts']! as List).cast<Map<String, Object?>>())
    GrammarConcept(
      id: c['id']! as String,
      level: CefrLevel.of(c['level']! as String)!,
      name: c['name']! as String,
      example: c['example'] as String?,
      note: c['note'] as String?,
    ),
];

/// [sentence] (a sentence's JSON) with [detected] as its grammar tags and
/// their level, unless it has tags already: those are kept as they are,
/// since they may have been corrected by hand. Keys keep the order content
/// files use, the tags in [concepts]' order.
Map<String, Object?> withGrammar(
  Map<String, Object?> sentence,
  Set<String> detected,
  List<GrammarConcept> concepts,
) {
  if (sentence['grammar'] != null) return sentence;
  final byId = {for (final c in concepts) c.id: c};
  final tags = [
    for (final c in concepts)
      if (detected.contains(c.id)) c.id,
  ];
  const first = ['id', 'text', 'credit'];
  return {
    for (final key in first)
      if (sentence.containsKey(key)) key: sentence[key],
    'level': levelOf(tags, byId).id,
    'grammar': tags,
    for (final MapEntry(:key, :value) in sentence.entries)
      if (!first.contains(key) && key != 'level') key: value,
  };
}

/// A sentence's level: that of the hardest concept in [conceptIds], or A1.
CefrLevel levelOf(
  Iterable<String> conceptIds,
  Map<String, GrammarConcept> concepts,
) {
  var level = CefrLevel.a1;
  for (final id in conceptIds) {
    final concept = concepts[id];
    if (concept != null && concept.level.index > level.index) {
      level = concept.level;
    }
  }
  return level;
}

/// What the detection needs to know about the content: its verbs' forms
/// and its nouns.
class GrammarContext {
  GrammarContext(ContentSet content) {
    for (final verb in content.verbs) {
      infinitives.add(normalise(verb.infinitive).split(' ').last);
      for (final f in verb.forms) {
        for (final form in [f.form, ...f.alternatives]) {
          final words = normalise(form).split(' ');
          if (words.length == 1) {
            (singleForms[words.single] ??= {}).add(f.tense);
            if (f.tense == Tense.present) {
              presentForms.add(words.single);
              if (verb.id == 'v.aller') allerPresent.add(words.single);
              if (const {
                Person.secondSingular,
                Person.firstPlural,
                Person.secondPlural,
              }.contains(f.person)) {
                imperativeForms.add(words.single);
              }
            }
          } else {
            compoundForms.add(words);
            auxiliaries.add(words.first);
            participles.add(words.last);
          }
          if (verb.id == 'v.dire') dire.add(words.last);
        }
      }
    }
    for (final noun in content.nouns) {
      for (final w in [noun.word, ...noun.synonyms.map((s) => s.word)]) {
        final word = normalise(w);
        nouns.add(word);
        if (!RegExp(r'[sxz]$').hasMatch(word)) {
          nouns
            ..add('${word}s')
            ..add('${word}x');
        }
        if (word.endsWith('ail')) {
          nouns.add('${word.substring(0, word.length - 3)}aux');
        }
      }
    }
  }

  /// One-word forms of the content's verbs, and the tenses they belong to.
  final Map<String, Set<Tense>> singleForms = {};
  final Set<String> presentForms = {};
  final Set<String> imperativeForms = {};
  final Set<String> allerPresent = {};
  final Set<String> dire = {};

  /// Compound forms, word by word: [ai, fini].
  final List<List<String>> compoundForms = [];
  final Set<String> auxiliaries = {};
  final Set<String> participles = {};
  final Set<String> infinitives = {};
  final Set<String> nouns = {};

  /// Whether [word] is a conjugated form of one of the content's verbs, or
  /// an auxiliary.
  bool isConjugated(String word) =>
      singleForms.containsKey(word) || auxiliaries.contains(word);

  /// Whether [word] is an infinitive: the content's, or one that looks like
  /// it (*voir*), for a verb the content may not have yet.
  bool isInfinitive(String word) =>
      infinitives.contains(word) ||
      (RegExp(r'(er|ir|re|oir)$').hasMatch(word) &&
          !_notInfinitives.contains(word) &&
          !nouns.contains(word));
}

const _notInfinitives = {
  'hier',
  'cher',
  'fier',
  'premier',
  'dernier',
  'entier',
  'soir',
  'noir',
  'pire',
  'autre',
  'entre',
  'contre',
  'notre',
  'votre',
  'encore',
  'heure',
  'quatre',
  'leur',
  'mer',
  'hiver',
};

/// A word of a sentence: lowercased, an elided word split off with its
/// apostrophe (*l’*), and whether a hyphen joins it to the word before
/// (*-tu* in *as-tu*).
typedef Token = ({String word, bool hyphen});

/// Hyphenated words that are one word, not a verb and a pronoun.
const _whole = {
  'peut-être',
  'là-bas',
  'là-haut',
  'c’est-à-dire',
  'au-dessus',
  'au-dessous',
  'rendez-vous',
  'grand-chose',
  'après-midi',
  'week-end',
  'celui-ci',
  'celle-ci',
  'ceux-ci',
  'celles-ci',
  'celui-là',
  'celle-là',
  'ceux-là',
  'celles-là',
  'vis-à-vis',
  'quelques-uns',
  'quelques-unes',
};

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

/// The words of [text].
List<Token> grammarTokens(String text) {
  final tokens = <Token>[];
  for (final m in RegExp(
    r'[\p{L}’\-]+',
    unicode: true,
  ).allMatches(normalise(text))) {
    var w = m[0]!;
    final at = w.indexOf(apostrophe);
    if (at > 0 &&
        at < w.length - 1 &&
        _elided.contains(w.substring(0, at + 1))) {
      tokens.add((word: w.substring(0, at + 1), hyphen: false));
      w = w.substring(at + 1);
    }
    if (_whole.contains(w) || !w.contains('-')) {
      tokens.add((word: w, hyphen: false));
      continue;
    }
    final parts = w.split('-');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      tokens.add((word: parts[i], hyphen: i > 0));
    }
  }
  return tokens;
}

const _subjects = {
  'je',
  'j’',
  'tu',
  'il',
  'elle',
  'on',
  'nous',
  'vous',
  'ils',
  'elles',
};
const _cluster = {
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
};
const _otherNegations = {
  'jamais',
  'rien',
  'plus',
  'personne',
  'aucun',
  'aucune',
  'nulle',
  'guère',
  'point',
  'ni',
  'nullement',
};
const _questionWords = {
  'où',
  'quand',
  'comment',
  'pourquoi',
  'combien',
  'quel',
  'quelle',
  'quels',
  'quelles',
  'quoi',
};
const _numbers = {
  'deux',
  'trois',
  'quatre',
  'cinq',
  'six',
  'sept',
  'huit',
  'neuf',
  'dix',
  'onze',
  'douze',
  'treize',
  'quatorze',
  'quinze',
  'seize',
  'vingt',
  'trente',
  'quarante',
  'cinquante',
  'soixante',
  'cent',
  'cents',
  'mille',
};
const _possessives = {
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
};
const _possessivePronouns = {
  'mien',
  'mienne',
  'miens',
  'miennes',
  'tien',
  'tienne',
  'tiens',
  'tiennes',
  'sien',
  'sienne',
  'siens',
  'siennes',
  'nôtre',
  'nôtres',
  'vôtre',
  'vôtres',
};
const _articles = {'le', 'la', 'l’', 'les', 'un', 'une', 'des'};
const _prepositions = {
  'à',
  'avec',
  'pour',
  'chez',
  'sans',
  'de',
  'd’',
  'sur',
  'sous',
  'devant',
  'derrière',
  'contre',
  'vers',
  'entre',
  'par',
};
const _placePrepositions = {
  'à',
  'au',
  'aux',
  'chez',
  'dans',
  'sur',
  'sous',
  'devant',
  'derrière',
};
const _stressed = {'moi', 'toi', 'eux', 'soi'};
const _thirdStressed = {'lui', 'elle', 'elles', 'nous', 'vous'};
const _relativesComposed = {
  'lequel',
  'laquelle',
  'lesquels',
  'lesquelles',
  'auquel',
  'auxquels',
  'auxquelles',
  'duquel',
  'desquels',
  'desquelles',
};
const _gerondifNot = {
  'avant',
  'maintenant',
  'pendant',
  'cependant',
  'tant',
  'durant',
  'enfant',
  'enfants',
};

/// The concepts [sentence] uses, by id.
Set<String> detectGrammar(ContentSentence sentence, GrammarContext context) {
  final found = <String>{};
  final tokens = grammarTokens(sentence.text);
  final words = [for (final t in tokens) t.word];
  final text = normalise(sentence.text);
  final question = text.trimRight().endsWith('?');
  String at(int i) => i >= 0 && i < words.length ? words[i] : '';

  // Tenses: the sentence's own links, and the content's forms in the text.
  for (final link in sentence.verbs) {
    found.add(_tenseConcept[link.tense]!);
  }
  for (final form in context.compoundForms) {
    for (var i = 0; i + form.length <= words.length; i++) {
      if (words[i] == form.first &&
          RegExp('^${RegExp.escape(form.last)}(e|s|es)?\$')
              .hasMatch(at(i + form.length - 1))) {
        found.add('passe-compose');
      }
    }
  }
  for (var i = 0; i < words.length; i++) {
    final tenses = context.singleForms[words[i]];
    if (tenses == null || tenses.contains(Tense.present)) continue;
    for (final tense in tenses) {
      found.add(_tenseConcept[tense]!);
    }
  }

  // Verbs and the pronouns before them.
  var ilYA = false;
  for (var v = 0; v < tokens.length; v++) {
    if (tokens[v].hyphen || !context.isConjugated(words[v])) continue;
    var j = v - 1;
    final cluster = <String>[];
    while (j >= 0 && _cluster.contains(words[j]) && !tokens[j + 1].hyphen) {
      cluster.insert(0, words[j]);
      j--;
    }
    var subject = j >= 0 ? words[j] : '';
    if (!_subjects.contains(subject) &&
        cluster.isNotEmpty &&
        (cluster.first == 'nous' || cluster.first == 'vous')) {
      subject = cluster.removeAt(0);
    }
    // Inverted: as-tu, a-t-il.
    if (at(v + 1) == 't' && tokens.length > v + 2 && tokens[v + 2].hyphen) {
      subject = at(v + 2);
    } else if (v + 1 < tokens.length &&
        tokens[v + 1].hyphen &&
        _subjects.contains(at(v + 1))) {
      subject = at(v + 1);
    }

    final pronouns = [
      for (final p in cluster)
        if (p != 'ne' && p != 'n’') p,
    ];
    // Il y a: y is part of the phrase, not a pronoun.
    const avoir3s = {'a', 'avait', 'aura', 'ait', 'aurait'};
    if (subject == 'il' &&
        pronouns.contains('y') &&
        avoir3s.contains(words[v])) {
      found.add('il-y-a');
      ilYA = true;
      pronouns.remove('y');
    }
    for (final p in pronouns) {
      switch (p) {
        case 'y':
          found.add('pronoun-y');
        case 'en':
          found.add('pronoun-en');
        case 'le' || 'la' || 'l’' || 'les':
          found.add('pronoun-direct-object');
        case 'lui' || 'leur':
          found.add('pronoun-indirect-object');
        case 'se' || 's’':
          found.add('pronominal-verbs');
        default:
          found.add(
            _reflexive(p, subject)
                ? 'pronominal-verbs'
                : 'pronoun-object-me-te',
          );
      }
    }
    if (pronouns.length >= 2) found.add('pronouns-double');

    // Pronouns after an imperative: dis-moi, faites-le.
    if (v == 0 && context.imperativeForms.contains(words[v])) {
      final inverted =
          v + 1 < tokens.length &&
          tokens[v + 1].hyphen &&
          (_subjects.contains(at(v + 1)) || at(v + 1) == 't');
      if (!inverted && !(question && at(v + 1) == 'nous')) {
        found.add('imperative');
        for (var k = v + 1; k < tokens.length && tokens[k].hyphen; k++) {
          switch (words[k]) {
            case 'le' || 'la' || 'les':
              found.add('pronoun-direct-object');
            case 'lui' || 'leur':
              found.add('pronoun-indirect-object');
            case 'moi' || 'toi' || 'nous' || 'vous':
              found.add('pronoun-object-me-te');
            case 'y':
              found.add('pronoun-y');
            case 'en':
              found.add('pronoun-en');
          }
        }
      }
    }

    // Aller + infinitive, after any pronouns and negation.
    if (context.allerPresent.contains(words[v])) {
      var k = v + 1;
      while (k < tokens.length &&
          (_cluster.contains(words[k]) ||
              const {'pas', 'bien', 'peut-être', 'aussi'}.contains(words[k]) ||
              tokens[k].hyphen)) {
        k++;
      }
      if (k < tokens.length && context.isInfinitive(words[k])) {
        found.add('futur-proche');
      }
    }
  }
  if (!ilYA &&
      RegExp(
        r'(?<!\p{L})il (n’)?y (en )?a(?!\p{L})',
        unicode: true,
      ).hasMatch(text)) {
    found.add('il-y-a');
  }
  if (RegExp(r'(?<!\p{L})y a-t-il(?!\p{L})', unicode: true).hasMatch(text)) {
    found.add('il-y-a');
  }

  // Inversion: as-tu; with -t- (a-t-elle); after a noun subject (ta femme
  // a-t-elle, ces chiens sont-ils); in the negative (ne dis-tu pas).
  void inverted(int verb) {
    // Outside a question, an inversion reports speech: « C’est beau »,
    // dit-il.
    if (!question) {
      found.add('reported-speech');
      return;
    }
    found.add('question-inversion');
    var j = verb - 1;
    while (j >= 0 && _cluster.contains(words[j])) {
      j--;
    }
    if (words.sublist(j + 1, verb).any((w) => w == 'ne' || w == 'n’')) {
      found.add('inversion-negative');
    }
    // A noun before the verb is its subject, unless it belongs to the
    // question: quel jour sommes-nous, combien de chats as-tu.
    if (j >= 0 &&
        context.nouns.contains(words[j]) &&
        !_questionWords.contains(at(j - 1)) &&
        !(at(j - 1) == 'de' && at(j - 2) == 'combien')) {
      found.add('inversion-complex');
    }
  }

  for (var i = 1; i < tokens.length; i++) {
    if (!tokens[i].hyphen) continue;
    if (words[i] == 't' && i + 1 < tokens.length && tokens[i + 1].hyphen) {
      found.add('inversion-t');
      inverted(i - 1);
    } else if (_subjects.contains(words[i]) &&
        words[i - 1] != 't' &&
        context.isConjugated(words[i - 1]) &&
        (question || !context.imperativeForms.contains(words[i - 1]))) {
      inverted(i - 1);
    }
  }

  // Negation.
  final negated = words.contains('ne') || words.contains('n’');
  var restriction = false;
  if (negated) {
    final other = words.any(_otherNegations.contains);
    if (other) found.add('negation-other');
    if (words.contains('pas')) found.add('negation-ne-pas');
    if (!other && !words.contains('pas')) {
      final ne = words.indexWhere((w) => w == 'ne' || w == 'n’');
      if (words.skip(ne).any((w) => w == 'que' || w == 'qu’')) {
        found.add('restriction-ne-que');
        restriction = true;
      }
    }
  }

  // Questions.
  var questionKind = false;
  if (text.contains('est-ce qu')) {
    found.add('question-est-ce-que');
    questionKind = true;
  }
  if (text.startsWith('qu’est-ce') || text.contains(' qu’est-ce')) {
    found.add('question-words');
  }
  if (question) {
    final first = at(0);
    final startsWithWord =
        _questionWords.contains(first) ||
        first == 'qui' ||
        first == 'que' ||
        first == 'qu’' ||
        (_prepositions.contains(first) &&
            (_questionWords.contains(at(1)) || at(1) == 'qui'));
    if (startsWithWord || words.any(_questionWords.contains)) {
      found.add('question-words');
      questionKind = true;
    }
    if (found.contains('question-inversion')) questionKind = true;
    if (!questionKind) found.add('question-intonation');
  }

  // Clauses.
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final prev = at(i - 1);
    final startOfQuestion = question && i == 0;
    switch (w) {
      case 'que' || 'qu’':
        if (startOfQuestion) break;
        // est-ce que, qu’est-ce que
        if (prev == 'ce' && at(i - 2) == 'est') break;
        if (at(i + 1) == 'est' && at(i + 2) == 'ce') break;
        if (restriction) break;
        if (prev == 'ce') {
          found.add('ce-que-ce-qui');
        } else if (words
                .sublist((i - 4).clamp(0, i), i)
                .any(const {'plus', 'moins', 'aussi', 'autant'}.contains) &&
            !negated) {
          found.add('comparative');
        } else if (context.dire.contains(prev)) {
          found
            ..add('reported-speech')
            ..add('clause-que');
        } else if (context.nouns.contains(prev)) {
          found.add('relative-qui-que');
        } else if (_cEstMiseEnRelief(words, i)) {
          found.add('mise-en-relief');
        } else {
          found.add('clause-que');
        }
      case 'qui':
        if (startOfQuestion) break;
        if (prev == 'ce') {
          found.add('ce-que-ce-qui');
        } else if (_cEstMiseEnRelief(words, i)) {
          found.add('mise-en-relief');
        } else {
          found.add('relative-qui-que');
        }
      case 'où':
        if (startOfQuestion || (question && _prepositions.contains(prev))) {
          break;
        }
        if (i > 0) found.add('relative-ou');
      case 'dont':
        found.add('relative-dont');
      case 'quand' || 'lorsque' || 'lorsqu’' || 'puisque' || 'puisqu’':
        if (!startOfQuestion) found.add('clause-time-cause');
      case 'parce' || 'pendant' || 'depuis' || 'dès':
        if (at(i + 1) == 'que' || at(i + 1) == 'qu’') {
          found.add('clause-time-cause');
        }
      case 'comme':
        if (_subjects.contains(at(i + 1)) || at(i + 1) == 'c’') {
          found.add('clause-time-cause');
        }
      case 'si':
        if (_subjects.contains(at(i + 1))) found.add('clause-si');
      case 's’':
        if (at(i + 1) == 'il' || at(i + 1) == 'ils') found.add('clause-si');
      case _ when _relativesComposed.contains(w):
        if (!startOfQuestion) found.add('relatives-composes');
    }
  }

  // Comparisons.
  for (var i = 0; i + 1 < words.length; i++) {
    if (const {'le', 'la', 'les'}.contains(words[i]) &&
        (words[i + 1] == 'plus' || words[i + 1] == 'moins')) {
      found.add('superlative');
    }
  }

  // Determiners, numbers, the time, places.
  final objectPronoun = found.contains('pronoun-direct-object');
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final next = at(i + 1);
    // A pronoun stands before a verb, an article before a noun.
    final beforeVerb = context.isConjugated(next) || context.isInfinitive(next);
    if (_articles.contains(w) &&
        !beforeVerb &&
        !(objectPronoun && _cluster.contains(next)) &&
        !_possessivePronouns.contains(next) &&
        !(i > 0 && tokens[i].hyphen)) {
      found.add('articles');
    }
    if (const {'le', 'la', 'les'}.contains(w) &&
        (_possessivePronouns.contains(next) ||
            ((next == 'leur' || next == 'leurs') &&
                !context.isConjugated(at(i + 2)) &&
                !context.isInfinitive(at(i + 2))))) {
      found.add('possessive-pronouns');
    }
    if (w == 'au' || w == 'aux') found.add('contractions');
    if (w == 'du' || (w == 'de' && (next == 'la' || next == 'l’'))) {
      final previous = at(i - 1);
      found.add(context.isConjugated(previous) ? 'partitive' : 'contractions');
    }
    if (_possessives.contains(w) && !beforeVerb) found.add('possessives');
    if ((w == 'leur' || w == 'leurs') &&
        !beforeVerb &&
        !const {'le', 'la', 'les'}.contains(at(i - 1))) {
      found.add('possessives');
    }
    if ((w == 'cet' || w == 'cette' || w == 'ces') ||
        (w == 'ce' &&
            !beforeVerb &&
            !const {
              'qui',
              'que',
              'qu’',
              'ne',
              'n’',
              'sont',
              'sera',
              'seront',
            }.contains(next) &&
            // est-ce, sont-ce
            !tokens[i].hyphen)) {
      found.add('demonstratives');
    }
    if (const {'celui', 'celle', 'ceux', 'celles'}.contains(w) ||
        w.startsWith('celui-') ||
        w.startsWith('celle-') ||
        w.startsWith('ceux-') ||
        w.startsWith('celles-')) {
      found.add('demonstrative-pronouns');
    }
    if (_numbers.contains(w)) found.add('numbers');
    if ((w == 'heure' || w == 'heures') &&
        (_numbers.contains(at(i - 1)) ||
            const {'une', 'quelle', 'cette'}.contains(at(i - 1)))) {
      found.add('telling-time');
    }
    if (w == 'midi' || w == 'minuit') found.add('telling-time');
    if (w == 'c’' && context.isConjugated(next)) found.add('c-est');
    if (w == 'ce' &&
        (next == 'sont' ||
            next == 'seront' ||
            next == 'sera' ||
            next == 'n’' ||
            next == 'ne')) {
      found.add('c-est');
    }
    if (_placePrepositions.contains(w) && i + 1 < words.length) {
      final after =
          _articles.contains(next) ||
              _possessives.contains(next) ||
              const {'ce', 'cet', 'cette', 'ces'}.contains(next)
          ? at(i + 2)
          : next;
      final notPlace =
          after == 'heure' ||
          after == 'heures' ||
          _numbers.contains(after) ||
          _stressed.contains(after) ||
          _thirdStressed.contains(after) ||
          context.isInfinitive(after) ||
          const {'quelle', 'quel', 'midi', 'minuit'}.contains(after);
      if (w == 'chez' || !notPlace) found.add('prepositions-place');
    }
    if (_stressed.contains(w) && !(i > 0 && tokens[i].hyphen)) {
      found.add('stressed-pronouns');
    }
    if (_thirdStressed.contains(w) &&
        !(i > 0 && tokens[i].hyphen) &&
        (_prepositions.contains(at(i - 1)) ||
            at(i - 1) == 'que' && found.contains('comparative') ||
            (i == 0 && (next == 'et' || next == '')))) {
      found.add('stressed-pronouns');
    }
    if (w == 'en' &&
        RegExp(r'ant$').hasMatch(next) &&
        !_gerondifNot.contains(next) &&
        !context.nouns.contains(next)) {
      found.add('gerondif');
    }
  }
  if (RegExp(r'(?<!\p{L})en train d', unicode: true).hasMatch(text)) {
    found.add('present-progressive');
  }
  final recent = RegExp(
    r'(?<!\p{L})(viens|vient|venons|venez|viennent|venais|venait|venions|veniez|venaient) (de |d’)(\p{L}+)',
    unicode: true,
  ).firstMatch(text);
  if (recent != null && context.isInfinitive(recent[3]!)) {
    found.add('passe-recent');
  }
  return found;
}

const Map<Tense, String> _tenseConcept = {
  Tense.present: 'present',
  Tense.passeCompose: 'passe-compose',
  Tense.imparfait: 'imparfait',
  Tense.futurSimple: 'futur-simple',
};

/// Whether [pronoun] refers back to [subject]: *je me*, *nous nous*.
bool _reflexive(String pronoun, String subject) => switch (pronoun) {
  'me' || 'm’' => subject == 'je' || subject == 'j’',
  'te' || 't’' => subject == 'tu',
  'nous' => subject == 'nous',
  'vous' => subject == 'vous',
  _ => false,
};

/// Whether the qui or que at [i] closes a *c’est… qui/que*: *c’est lui qui*.
bool _cEstMiseEnRelief(List<String> words, int i) {
  for (var k = i - 1; k >= 0 && k >= i - 4; k--) {
    if (words[k] == 'c’' && k + 1 < words.length && words[k + 1] == 'est') {
      return true;
    }
  }
  return false;
}
