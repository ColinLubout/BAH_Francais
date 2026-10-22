/// Checks content against Wiktionary, as Kaikki.org's machine-readable
/// French dictionary has it (extracted by wiktextract; CC BY-SA). The data
/// is a large download kept out of the repo, in `data/kaikki/`.
///
/// The dictionary only checks: genders, plural-only nouns, auxiliaries and
/// conjugated forms. Nothing is copied from it into the content.
library;

import 'dart:convert';

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';

/// What the dictionary says about one noun entry.
class DictionaryNoun {
  const DictionaryNoun({required this.genders, required this.pluralOnly});

  /// [Gender.both] for a noun whose gender follows the person.
  final Set<Gender> genders;
  final bool pluralOnly;
}

/// One conjugation table: a verb, or its reflexive form (*se lever* is a
/// table in the entry for *lever*).
class DictionaryVerb {
  DictionaryVerb(this.infinitive);

  /// Normalised: *se lever*, *s’appeler*.
  final String infinitive;
  Auxiliary? auxiliary;
  String? participle;

  /// Every form the table gives for a tense and person, normalised. The
  /// passé composé is built from the auxiliary and the past participle.
  final Map<(Tense, Person), Set<String>> forms = {};

  bool get reflexive =>
      infinitive.startsWith('se ') || infinitive.startsWith('s’');
}

/// The parts of the dictionary the content uses.
class Dictionary {
  Dictionary._(this.nouns, this.verbs, this.partsOfSpeech);

  /// Noun entries by normalised word.
  final Map<String, List<DictionaryNoun>> nouns;

  /// Conjugation tables by normalised infinitive.
  final Map<String, List<DictionaryVerb>> verbs;

  /// The parts of speech (`noun`, `verb`, `adj`…) of each word asked for,
  /// inflected forms included: *chats* is a noun.
  final Map<String, Set<String>> partsOfSpeech;

  /// Reads the entries for [words] (normalised nouns and verb lemmas: *lever*
  /// for *se lever*), and the parts of speech of [partsOfSpeechFor], from the
  /// dictionary's JSON lines. Only lines that name one of them are decoded,
  /// so a whole dictionary reads in seconds.
  static Future<Dictionary> read(
    Stream<String> lines, {
    required Set<String> words,
    Set<String> partsOfSpeechFor = const {},
  }) async {
    final nouns = <String, List<DictionaryNoun>>{};
    final verbs = <String, List<DictionaryVerb>>{};
    final partsOfSpeech = <String, Set<String>>{};
    final wanted = {...words, ...partsOfSpeechFor};
    final named = RegExp(r'"word": ?"((?:[^"\\]|\\.)*)"');
    await for (final line in lines) {
      if (!named
          .allMatches(line)
          .any((m) => wanted.contains(normalise(_unescape(m.group(1)!))))) {
        continue;
      }
      final Object? json;
      try {
        json = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (json is! Map<String, Object?> || json['lang_code'] != 'fr') continue;
      final word = normalise(json['word']! as String);
      if (json['pos'] case final String pos
          when pos.isNotEmpty && partsOfSpeechFor.contains(word)) {
        (partsOfSpeech[word] ??= {}).add(pos);
      }
      if (!words.contains(word)) continue;
      switch (json['pos']) {
        case 'noun':
          (nouns[word] ??= []).add(_noun(json));
        case 'verb':
          for (final table in _tables(json)) {
            (verbs[table.infinitive] ??= []).add(table);
          }
      }
    }
    return Dictionary._(nouns, verbs, partsOfSpeech);
  }

  static String _unescape(String s) => jsonDecode('"$s"') as String;

  static DictionaryNoun _noun(Map<String, Object?> json) {
    final genders = <Gender>{};
    var pluralOnly = false;
    void gender(String g) {
      if (g.contains('bysense') || g.startsWith('mf')) {
        genders.add(Gender.both);
      } else if (g.startsWith('m')) {
        genders.add(Gender.masculine);
      } else if (g.startsWith('f')) {
        genders.add(Gender.feminine);
      }
      if (g.endsWith('-p')) pluralOnly = true;
    }

    for (final t in _maps(json['head_templates'])) {
      final args = (t['args'] as Map?) ?? const {};
      final g = t['name'] == 'fr-noun' ? args['1'] : args['g'];
      if (g is String) gender(g);
    }
    for (final sense in _maps(json['senses'])) {
      final tags = _strings(sense['tags']);
      if (tags.contains('plural-only')) pluralOnly = true;
      if (genders.isNotEmpty) continue;
      if (tags.contains('by-personal-gender')) {
        genders.add(Gender.both);
      } else if (tags.contains('masculine') && tags.contains('feminine')) {
        genders.add(Gender.both);
      } else if (tags.contains('masculine')) {
        genders.add(Gender.masculine);
      } else if (tags.contains('feminine')) {
        genders.add(Gender.feminine);
      }
    }
    return DictionaryNoun(genders: genders, pluralOnly: pluralOnly);
  }

  static List<DictionaryVerb> _tables(Map<String, Object?> json) {
    final tables = <DictionaryVerb>[];
    DictionaryVerb? table;
    for (final f in _maps(json['forms'])) {
      final tags = _strings(f['tags']).toSet();
      final form = f['form'] as String? ?? '';
      if (tags.contains('table-tags')) {
        table = null;
        continue;
      }
      if (tags.contains('infinitive') &&
          !tags.contains('multiword-construction')) {
        table = DictionaryVerb(normalise(form));
        tables.add(table);
        continue;
      }
      if (table == null) continue;
      if (tags.contains('infinitive') &&
          tags.contains('multiword-construction')) {
        final aux = normalise(form);
        if (aux.startsWith('avoir ')) table.auxiliary = Auxiliary.avoir;
        if (aux.startsWith('être ') || aux.startsWith('s’être ')) {
          table.auxiliary = Auxiliary.etre;
        }
        continue;
      }
      if (tags.containsAll(['participle', 'past'])) {
        if (_isSpelling(form)) table.participle ??= normalise(form);
        continue;
      }
      if (!tags.contains('indicative') ||
          tags.contains('multiword-construction')) {
        continue;
      }
      final tense = switch (tags) {
        _ when tags.containsAll(['present']) && !tags.contains('perfect') =>
          Tense.present,
        _ when tags.contains('imperfect') => Tense.imparfait,
        _ when tags.contains('future') && !tags.contains('perfect') =>
          Tense.futurSimple,
        _ => null,
      };
      final person = _person(tags);
      if (tense == null || person == null || !_isSpelling(form)) continue;
      (table.forms[(tense, person)] ??= {}).add(normalise(form));
    }
    tables.forEach(_addPasseCompose);
    return tables;
  }

  /// Whether [form] is a spelling. Some table rows hold a pronunciation
  /// (`/pɛ.ʁe/`), a dialect transcription or `-` for a missing form.
  static bool _isSpelling(String form) =>
      RegExp(r"^[a-zàâäçéèêëîïôöùûüÿœæ’' -]+$").hasMatch(form.toLowerCase()) &&
      RegExp('[a-zàâäçéèêëîïôöùûüÿœæ]').hasMatch(form.toLowerCase());

  /// The reflexive table of [plain] (*se lever* from *lever*), for a verb
  /// whose entry has none: each form after its reflexive pronoun, elided
  /// before a vowel, or before an *h* unless [hAspire].
  static DictionaryVerb reflexiveOf(
    DictionaryVerb plain, {
    required bool hAspire,
  }) {
    final elides = RegExp('^[aeiouyàâäéèêëîïôöùûüœæ]');
    final infinitive = plain.infinitive;
    final table = DictionaryVerb(
      elides.hasMatch(infinitive) || (!hAspire && infinitive.startsWith('h'))
          ? 's’$infinitive'
          : 'se $infinitive',
    )..participle = plain.participle;
    const pronouns = ['me', 'te', 'se', 'nous', 'vous', 'se'];
    // me, te and se elide; nous and vous never do.
    String withPronoun(String pronoun, String form) =>
        pronoun.length == 2 &&
            (elides.hasMatch(form) || (!hAspire && form.startsWith('h')))
        ? '${pronoun[0]}’$form'
        : '$pronoun $form';
    for (final MapEntry(key: (tense, person), value: forms)
        in plain.forms.entries) {
      if (tense.isCompound) continue;
      table.forms[(tense, person)] = {
        for (final form in forms) withPronoun(pronouns[person.index], form),
      };
    }
    _addPasseCompose(table);
    return table;
  }

  static Person? _person(Set<String> tags) {
    final plural = tags.contains('plural');
    if (!plural && !tags.contains('singular')) return null;
    if (tags.contains('first-person')) {
      return plural ? Person.firstPlural : Person.firstSingular;
    }
    if (tags.contains('second-person')) {
      return plural ? Person.secondPlural : Person.secondSingular;
    }
    if (tags.contains('third-person')) {
      return plural ? Person.thirdPlural : Person.thirdSingular;
    }
    return null;
  }

  /// The present of each auxiliary, and of *être* after a reflexive pronoun.
  static const _avoir = ['ai', 'as', 'a', 'avons', 'avez', 'ont'];
  static const _etre = ['suis', 'es', 'est', 'sommes', 'êtes', 'sont'];
  static const _reflexiveEtre = [
    'me suis',
    't’es',
    's’est',
    'nous sommes',
    'vous êtes',
    'se sont',
  ];

  static void _addPasseCompose(DictionaryVerb table) {
    final participle = table.participle;
    final aux = table.reflexive ? Auxiliary.etre : table.auxiliary;
    if (participle == null || aux == null) return;
    final present = table.reflexive
        ? _reflexiveEtre
        : aux == Auxiliary.etre
        ? _etre
        : _avoir;
    for (final (i, person) in Person.values.indexed) {
      table.forms[(Tense.passeCompose, person)] = {'${present[i]} $participle'};
    }
  }

  static List<Map<String, Object?>> _maps(Object? json) => [
    for (final item in (json as List<Object?>?) ?? const [])
      if (item is Map<String, Object?>) item,
  ];

  static List<String> _strings(Object? json) => [
    for (final item in (json as List<Object?>?) ?? const [])
      if (item is String) item,
  ];
}

/// A disagreement with the dictionary, or something it can't confirm.
class Finding {
  const Finding(this.itemId, this.message, {this.difference = true});

  final String itemId;
  final String message;

  /// False for a note: something to look at, not a disagreement.
  final bool difference;

  @override
  String toString() => '$itemId: $message';
}

/// The verb lemma a dictionary entry is under: *lever* for *se lever*.
String verbLemma(String infinitive) {
  final normalised = normalise(infinitive);
  if (normalised.startsWith('se ')) return normalised.substring(3);
  if (normalised.startsWith('s’')) return normalised.substring(2);
  return normalised;
}

/// Every word [content] needs from the dictionary, normalised.
Set<String> wordsToLook(ContentSet content) => {
  for (final n in content.nouns) ...[
    normalise(n.word),
    for (final s in n.synonyms) normalise(s.word),
  ],
  for (final v in content.verbs) verbLemma(v.infinitive),
};

/// Compares [content] with [dictionary].
List<Finding> compare(ContentSet content, Dictionary dictionary) => [
  for (final noun in content.nouns) ..._compareNoun(noun, dictionary),
  for (final verb in content.verbs) ..._compareVerb(verb, dictionary),
];

const Map<Gender, String> _genderName = {
  Gender.masculine: 'masculine',
  Gender.feminine: 'feminine',
  Gender.both: 'both genders',
};

String _genderNames(Iterable<Gender> genders) =>
    genders.map((g) => _genderName[g]).join(' or ');

String _quoted(Iterable<String> words, String separator) =>
    words.map((w) => '"$w"').join(separator);

Iterable<Finding> _compareNoun(ContentNoun noun, Dictionary d) sync* {
  final words = [
    (word: noun.word, gender: noun.gender, what: '"${noun.word}"'),
    for (final s in noun.synonyms)
      (
        word: s.word,
        gender: s.gender ?? noun.gender,
        what: 'synonym "${s.word}"',
      ),
  ];
  for (final w in words) {
    final entries = d.nouns[normalise(w.word)] ?? const [];
    if (entries.isEmpty) {
      yield Finding(
        noun.id,
        '${w.what} is not in the dictionary',
        difference: false,
      );
      continue;
    }
    final genders = {for (final e in entries) ...e.genders};
    if (genders.isEmpty) {
      yield Finding(
        noun.id,
        'the dictionary gives no gender for ${w.what}',
        difference: false,
      );
    } else if (!genders.contains(w.gender)) {
      yield Finding(
        noun.id,
        '${w.what} is ${_genderName[w.gender]} here; the dictionary has '
        '${_genderNames(genders)}',
      );
    } else if (genders.length > 1) {
      yield Finding(
        noun.id,
        'the dictionary also has ${w.what} as '
        '${_genderNames(genders.where((g) => g != w.gender))} '
        '(another meaning?)',
        difference: false,
      );
    }
    if (w.word == noun.word) {
      final pluralOnly = entries.any((e) => e.pluralOnly);
      if (noun.pluralOnly && !pluralOnly) {
        yield Finding(
          noun.id,
          '${w.what} is plural only here, not in the dictionary',
        );
      } else if (!noun.pluralOnly && entries.every((e) => e.pluralOnly)) {
        yield Finding(noun.id, '${w.what} is plural only in the dictionary');
      }
    }
  }
}

Iterable<Finding> _compareVerb(ContentVerb verb, Dictionary d) sync* {
  var tables = d.verbs[normalise(verb.infinitive)] ?? const [];
  final lemma = verbLemma(verb.infinitive);
  if (tables.isEmpty && lemma != normalise(verb.infinitive)) {
    // Wiktionary gives few reflexive tables: build one from the verb.
    tables = [
      for (final plain in d.verbs[lemma] ?? const <DictionaryVerb>[])
        Dictionary.reflexiveOf(plain, hAspire: verb.hAspire),
    ];
    if (tables.isNotEmpty) {
      yield Finding(
        verb.id,
        'its reflexive forms are built from "$lemma", which has no '
        'reflexive table',
        difference: false,
      );
    }
  }
  if (tables.isEmpty) {
    yield Finding(
      verb.id,
      '"${verb.infinitive}" is not in the dictionary',
      difference: false,
    );
    return;
  }
  // An infinitive can have several entries (two meanings, two
  // etymologies): compare with the one that agrees most.
  int agreement(DictionaryVerb t) => verb.forms
      .where(
        (f) =>
            t.forms[(f.tense, f.person)]?.contains(normalise(f.form)) ?? false,
      )
      .length;
  final table = tables.reduce((a, b) => agreement(b) > agreement(a) ? b : a);

  final aux = table.reflexive ? Auxiliary.etre : table.auxiliary;
  if (aux != null && aux != verb.auxiliary) {
    yield Finding(
      verb.id,
      'its auxiliary is ${verb.auxiliary.id} here; '
      'the dictionary has ${aux.id}',
    );
  }
  for (final f in verb.forms) {
    final theirs = table.forms[(f.tense, f.person)];
    final where = '${f.tense.id} ${f.person.id}';
    if (theirs == null || theirs.isEmpty) {
      yield Finding(
        verb.id,
        '$where: the dictionary has no form',
        difference: false,
      );
      continue;
    }
    final ours = [f.form, ...f.alternatives];
    for (final form in ours) {
      if (!theirs.contains(normalise(form))) {
        yield Finding(
          verb.id,
          '$where: "$form" here; the dictionary has '
          '${_quoted(theirs, ' or ')}',
        );
      }
    }
    final extra = theirs.difference({for (final o in ours) normalise(o)});
    if (extra.isNotEmpty && ours.every((o) => theirs.contains(normalise(o)))) {
      yield Finding(
        verb.id,
        '$where: the dictionary also has ${_quoted(extra, ', ')}',
        difference: false,
      );
    }
  }
}
