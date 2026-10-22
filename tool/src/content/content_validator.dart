/// Validates content files and turns them into the content they describe
/// (Content → Content files).
///
/// Each file is checked against its JSON Schema first. The rules beyond the
/// schema then run on everything that passed:
///
/// - every id is unique, and so is every image file name;
/// - every noun has an image or a definition;
/// - a noun or synonym is written without its article;
/// - categories a noun or verb is in exist, and are of the right kind;
/// - at most one everyday category of each kind;
/// - a noun starting with *h* states `elides`, and a verb with a form
///   starting with *h* states `h_aspire` (and no other verb does);
/// - `tenses.json` lists the tenses the content teaches;
/// - with a `grammar.json`, every sentence lists the grammar concepts it uses
///   and its level, the level of its hardest concept, no higher than the
///   content's `max_level`;
/// - every noun has a sentence, and every verb a sentence per person in each
///   tense taught; no sentence is a prompt for a tense that isn't;
/// - a sentence is written in full, with no `___`;
/// - the verbs and nouns a sentence uses exist, and their words are in it
///   exactly once, as whole words;
/// - a verb's answer and alternatives are the stored form or one of its
///   alternatives, plus *e*, *s* or *es* in a compound tense for agreement;
/// - an elided word just before a verb can be written in full in the prompt:
///   *j’, m’, t’, s’, n’, c’* always, *l’* when the sentence says `le` or
///   `la`;
/// - every image exists and follows the SVG rules; a big one is a warning.
library;

import 'dart:convert';

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/sentence_prompt.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:json_schema/json_schema.dart';

import 'content_files.dart';
import 'grammar.dart';
import 'svg_rules.dart';

/// A problem in a content file.
class ContentIssue {
  const ContentIssue(this.file, this.where, this.message);

  final String file;

  /// The item or JSON path the problem is at; empty for the whole file.
  final String where;
  final String message;

  @override
  String toString() =>
      where.isEmpty ? '$file: $message' : '$file $where: $message';
}

/// What validation found, and the content the files describe. The content
/// is only complete when there are no errors.
class ContentReport {
  const ContentReport({
    required this.content,
    required this.errors,
    required this.warnings,
  });

  final ContentSet content;
  final List<ContentIssue> errors;
  final List<ContentIssue> warnings;

  bool get isValid => errors.isEmpty;
}

ContentReport validateContent(ContentFiles files, ContentSchemas schemas) =>
    _Validation(files, schemas).run();

/// An item and where it came from.
class _Parsed<T> {
  _Parsed(this.value, this.file, this.json);

  final T value;
  final String file;
  final Map<String, Object?> json;
}

class _Validation {
  _Validation(this.files, this.schemas);

  final ContentFiles files;
  final ContentSchemas schemas;

  final errors = <ContentIssue>[];
  final warnings = <ContentIssue>[];
  final categories = <_Parsed<ContentCategory>>[];
  final nouns = <_Parsed<ContentNoun>>[];
  final verbs = <_Parsed<ContentVerb>>[];
  final sentences = <_Parsed<ContentSentence>>[];
  final images = <_Parsed<ContentImage>>[];

  /// The ids in files their schema refused. They exist but weren't read, so
  /// naming them elsewhere is not another mistake.
  final unread = <String>{};

  /// Whether a sentence file was refused: what it holds is unknown, so no
  /// noun or verb can be said to lack a sentence.
  bool sentencesUnread = false;

  /// The tenses the content teaches, from `tenses.json`.
  List<Tense> taught = Tense.values;

  /// Whether `tenses.json` is missing or was refused: which sentences a verb
  /// needs, and which it may have, is unknown.
  bool tensesUnread = false;

  /// The grammar concepts from `grammar.json` by id, and the highest level
  /// sentences may reach; null when the content has no `grammar.json`.
  Map<String, GrammarConcept>? concepts;
  CefrLevel maxLevel = CefrLevel.b2;

  /// Whether `grammar.json` was refused: sentences' tags can't be checked.
  bool grammarUnread = false;

  ContentReport run() {
    _readTenses();
    _readGrammar();
    if (files.verbCategories case final file?) _readVerbCategories(file);
    files.nouns.forEach(_readNounFile);
    files.verbs.forEach(_readVerb);
    files.sentences.forEach(_readSentenceFile);
    _readImages();

    _checkIds();
    _checkCategories();
    _checkNouns();
    _checkVerbs();
    _checkSentences();

    return ContentReport(
      content: ContentSet(
        tenses: taught,
        categories: [for (final c in categories) c.value],
        nouns: [for (final n in nouns) n.value],
        verbs: [for (final v in verbs) v.value],
        sentences: [for (final s in sentences) s.value],
        images: [for (final i in images) i.value],
      ),
      errors: errors,
      warnings: warnings,
    );
  }

  void _error(String file, String where, String message) =>
      errors.add(ContentIssue(file, where, message));

  /// [file] decoded, if it is JSON that its schema accepts. If the schema
  /// refuses it, the ids [idsIn] finds in it go to [unread].
  Map<String, Object?>? _decode(
    SourceFile file,
    JsonSchema schema, {
    Iterable<String> Function(Object? json)? idsIn,
  }) {
    final Object? json;
    try {
      json = jsonDecode(file.text);
    } on FormatException catch (e) {
      _error(file.path, '', 'is not valid JSON: ${e.message}');
      return null;
    }
    final result = schema.validate(json);
    if (result.isValid) return json! as Map<String, Object?>;

    final reported = <String>{};
    for (final e in result.errors) {
      final (:path, :message) = _schemaIssue(e.instancePath, e.message);
      if (reported.add('$path $message')) _error(file.path, path, message);
    }
    if (idsIn != null) unread.addAll(idsIn(json));
    return null;
  }

  /// A schema error made readable: without the dump of the object it is
  /// about, and once per field.
  static ({String path, String message}) _schemaIssue(
    String path,
    String message,
  ) {
    var clean = message.replaceFirst(RegExp(r' from \{.*$', dotAll: true), '');
    var where = path;
    // A missing field is reported both on its object and on itself.
    final missing = RegExp(r'^required prop missing: (\S+)$').firstMatch(clean);
    if (missing != null && where.endsWith('/${missing.group(1)}')) {
      where = where.substring(0, where.length - missing.group(1)!.length - 1);
    }
    if (clean.contains('oneOf')) {
      clean = 'is none of the forms the format allows (see content/schema)';
    }
    return (path: where, message: clean);
  }

  /// The `id` of each object in the list at [key] of [json], however
  /// malformed the rest is.
  static List<String> _idsInList(Object? json, String key) => [
    if (json is Map<String, Object?>)
      if (json[key] case final List<Object?> list)
        for (final item in list)
          if (item case {'id': final String id}) id,
  ];

  void _readTenses() {
    final file = files.tenses;
    if (file == null) {
      _error(
        'tenses.json',
        '',
        'is missing: list the tenses the content teaches, as '
            '{"tenses": ["present"]}',
      );
      tensesUnread = true;
      return;
    }
    final json = _decode(file, schemas.tenses);
    if (json == null) {
      tensesUnread = true;
      return;
    }
    final ids = _strings(json['tenses']).toSet();
    taught = [
      for (final t in Tense.values)
        if (ids.contains(t.id)) t,
    ];
  }

  void _readGrammar() {
    final file = files.grammar;
    if (file == null) return;
    final json = _decode(file, schemas.grammar);
    if (json == null) {
      grammarUnread = true;
      return;
    }
    maxLevel = CefrLevel.of(json['max_level']! as String)!;
    final byId = <String, GrammarConcept>{};
    for (final c in conceptsFromJson(json)) {
      if (byId.containsKey(c.id)) {
        _error(file.path, c.id, 'concept id ${c.id} is already used');
      }
      byId[c.id] = c;
    }
    concepts = byId;
  }

  /// A sentence's grammar tags name concepts that exist, and its level is
  /// that of the hardest, within the content's `max_level`.
  void _checkGrammar(_Parsed<ContentSentence> parsed) {
    void error(String message) => _error(parsed.file, parsed.value.id, message);
    final tags = _strings(parsed.json['grammar']);
    final level = parsed.json['level'] as String?;
    final byId = concepts;
    if (byId == null) {
      if (!grammarUnread && (tags.isNotEmpty || level != null)) {
        error('has grammar tags, but there is no grammar.json to define them');
      }
      return;
    }
    if (tags.isEmpty || level == null) {
      error(
        'needs its grammar concepts and level: run '
        'dart run tool/grammar_tag.dart',
      );
      return;
    }
    final unknown = [
      for (final t in tags)
        if (!byId.containsKey(t)) t,
    ];
    if (unknown.isNotEmpty) {
      error('no grammar concept ${unknown.join(', ')} in grammar.json');
      return;
    }
    final hardest = levelOf(tags, byId);
    if (level != hardest.id) {
      error(
        'is level $level, but its hardest concept is ${hardest.id} '
        '(${[for (final t in tags)
          if (byId[t]!.level == hardest) t].join(', ')})',
      );
    }
    if (hardest.index > maxLevel.index) {
      error(
        'is ${hardest.id}, above the content’s ${maxLevel.id} (grammar.json '
        'max_level)',
      );
    }
  }

  void _readVerbCategories(SourceFile file) {
    final json = _decode(
      file,
      schemas.verbCategories,
      idsIn: (json) => _idsInList(json, 'categories'),
    );
    if (json == null) return;
    for (final c in _listOfMaps(json['categories'])) {
      categories.add(_Parsed(_category(c), file.path, c));
    }
  }

  void _readNounFile(SourceFile file) {
    final json = _decode(
      file,
      schemas.nounCategory,
      idsIn: (json) => [
        if (json case {'category': {'id': final String id}}) id,
        ..._idsInList(json, 'nouns'),
      ],
    );
    if (json == null) return;
    final category = _map(json['category']);
    categories.add(_Parsed(_category(category), file.path, category));
    final categoryId = category['id']! as String;
    for (final n in _listOfMaps(json['nouns'])) {
      nouns.add(_Parsed(_noun(n, categoryId), file.path, n));
    }
  }

  void _readVerb(SourceFile file) {
    final json = _decode(
      file,
      schemas.verb,
      idsIn: (json) => [if (json case {'id': final String id}) id],
    );
    if (json == null) return;
    verbs.add(_Parsed(_verb(json), file.path, json));
  }

  void _readSentenceFile(SourceFile file) {
    final json = _decode(file, schemas.sentences);
    if (json == null) {
      sentencesUnread = true;
      return;
    }
    for (final s in _listOfMaps(json['sentences'])) {
      sentences.add(_Parsed(_sentence(s), file.path, s));
    }
  }

  void _readImages() {
    for (final noun in nouns) {
      final id = noun.value.id;
      for (final entry in _imageEntries(noun.json)) {
        final path = 'images/${id.substring(2)}/${entry.file}';
        final bytes = files.images[path];
        if (bytes == null) {
          _error(noun.file, id, 'image $path not found');
          continue;
        }
        final String svg;
        try {
          svg = utf8.decode(bytes);
        } on FormatException {
          _error(path, '', 'is not UTF-8 text');
          continue;
        }
        for (final problem in svgProblems(svg)) {
          _error(path, '', problem);
        }
        if (bytes.length > svgSizeTarget) {
          warnings.add(
            ContentIssue(
              path,
              '',
              '${(bytes.length / 1024).toStringAsFixed(1)} KB, over the '
                  '${svgSizeTarget ~/ 1024} KB target',
            ),
          );
        }
        images.add(
          _Parsed(
            ContentImage(
              id: ContentImage.idFor(entry.file),
              itemId: id,
              format: ImageFormat.svg,
              svg: svg,
              credit: entry.source,
            ),
            noun.file,
            const {},
          ),
        );
      }
    }
  }

  void _checkIds() {
    final seen = <String, String>{};
    void check(String id, String file, String what) {
      final first = seen[id];
      if (first == null) {
        seen[id] = file;
      } else {
        _error(file, id, '$what id $id is already used in $first');
      }
    }

    for (final c in categories) {
      check(c.value.id, c.file, 'category');
    }
    for (final n in nouns) {
      check(n.value.id, n.file, 'noun');
    }
    for (final v in verbs) {
      check(v.value.id, v.file, 'verb');
    }
    for (final s in sentences) {
      check(s.value.id, s.file, 'sentence');
    }
    for (final i in images) {
      check(i.value.id, i.file, 'image');
    }
  }

  void _checkCategories() {
    final kinds = {for (final c in categories) c.value.id: c.value.kind};

    for (final kind in CategoryKind.values) {
      final everyday = [
        for (final c in categories)
          if (c.value.kind == kind && c.value.everyday) c,
      ];
      for (final c in everyday.skip(1)) {
        _error(
          c.file,
          c.value.id,
          'only one ${kind.id} category can be everyday; '
          '${everyday.first.value.id} already is',
        );
      }
    }

    for (final n in nouns) {
      final own = n.value.categoryIds.first;
      for (final id in n.value.categoryIds.skip(1)) {
        if (id == own) {
          _error(n.file, n.value.id, 'also_in repeats its own category $id');
        } else if (kinds[id] != CategoryKind.noun && !unread.contains(id)) {
          _error(n.file, n.value.id, 'also_in: no noun category $id');
        }
      }
    }
    for (final v in verbs) {
      for (final id in v.value.categoryIds) {
        if (kinds[id] != CategoryKind.verb && !unread.contains(id)) {
          _error(v.file, v.value.id, 'no verb category $id');
        }
      }
    }
  }

  void _checkNouns() {
    final inSentences = {
      for (final s in sentences)
        for (final n in s.value.nouns) n.nounId,
    };
    for (final n in nouns) {
      final noun = n.value;
      if (noun.definition == null && _imageEntries(n.json).isEmpty) {
        _error(n.file, noun.id, 'has neither an image nor a definition');
      }
      if (!sentencesUnread && !inSentences.contains(noun.id)) {
        _error(n.file, noun.id, 'no sentence uses it as an example');
      }
      for (final word in [noun.word, ...noun.synonyms.map((s) => s.word)]) {
        if (splitArticle(normalise(word)).article != null) {
          _error(
            n.file,
            noun.id,
            '"$word" starts with an article: write the noun alone, since '
            'its article comes from its gender',
          );
        }
      }
      if (_startsWithH(noun.word) && !n.json.containsKey('elides')) {
        _error(
          n.file,
          noun.id,
          'starts with h: state "elides" (true for l’, false for le/la)',
        );
      }
    }
  }

  void _checkVerbs() {
    final inSentences = {
      for (final s in sentences)
        for (final v in s.value.verbs) (v.verbId, v.tense, v.person),
    };
    for (final v in verbs) {
      final verb = v.value;
      final startsWithH = verb.forms.any(
        (f) => [f.form, ...f.alternatives].any(_startsWithH),
      );
      final states = v.json.containsKey('h_aspire');
      if (startsWithH && !states) {
        _error(
          v.file,
          verb.id,
          'has forms starting with h: state "h_aspire" '
          '(false if je becomes j’, true if not)',
        );
      } else if (states && !startsWithH) {
        _error(
          v.file,
          verb.id,
          'h_aspire only applies when a form starts with h',
        );
      }

      if (sentencesUnread || tensesUnread) continue;
      for (final tense in taught) {
        for (final person in Person.values) {
          if (!inSentences.contains((verb.id, tense, person))) {
            _error(v.file, verb.id, 'no sentence for ${tense.id} ${person.id}');
          }
        }
      }
    }
  }

  void _checkSentences() {
    final verbsById = {for (final v in verbs) v.value.id: v.value};
    final nounIds = {for (final n in nouns) n.value.id};

    for (final parsed in sentences) {
      final s = parsed.value;
      void error(String message) => _error(parsed.file, s.id, message);
      _checkGrammar(parsed);

      if (s.text.contains('_')) {
        error(
          'is written in full, with no ___: the drill blanks the verb '
          'itself',
        );
      }

      final linkedVerbs = <(String, Tense, Person)>{};
      for (final link in s.verbs) {
        final key = (link.verbId, link.tense, link.person);
        if (!linkedVerbs.add(key)) {
          error('uses ${link.verbId} ${link.tense.id} ${link.person.id} twice');
        }
        if (!tensesUnread && !taught.contains(link.tense)) {
          error(
            'is a prompt for ${link.verbId} ${link.tense.id} '
            '${link.person.id}, but tenses.json doesn’t teach the '
            '${link.tense.id}',
          );
        }
        final verb = verbsById[link.verbId];
        if (verb == null) {
          if (!unread.contains(link.verbId)) error('no verb ${link.verbId}');
        } else {
          _checkAnswers(error, verb, link);
        }
        _checkPlace(error, s.text, link);
      }

      final linkedNouns = <String>{};
      for (final link in s.nouns) {
        if (!linkedNouns.add(link.nounId)) error('uses ${link.nounId} twice');
        if (!nounIds.contains(link.nounId) && !unread.contains(link.nounId)) {
          error('no noun ${link.nounId}');
        }
        if (findOnce(s.text, link.word) == null) {
          error(
            '"${link.word}" (${link.nounId}) is not in the text exactly '
            'once, as whole words',
          );
        }
      }
    }
  }

  /// A verb's answer and alternatives are its stored form, with agreement.
  void _checkAnswers(
    void Function(String) error,
    ContentVerb verb,
    SentenceVerb link,
  ) {
    final form = verb.form(link.tense, link.person)!;
    final accepted = {
      for (final base in [form.form, ...form.alternatives].map(normalise)) ...[
        base,
        if (link.tense.isCompound) ...['${base}e', '${base}s', '${base}es'],
      ],
    };
    for (final answer in [link.answer, ...link.alternatives]) {
      if (!accepted.contains(normalise(answer))) {
        final alternatives = form.alternatives.isEmpty
            ? ''
            : ' or ${form.alternatives.map((a) => '"$a"').join(', ')}';
        error(
          '"$answer" is not the ${verb.id} ${link.tense.id} '
          '${link.person.id} form, "${form.form}"$alternatives'
          '${link.tense.isCompound ? ', allowing for agreement' : ''}',
        );
      }
    }
  }

  /// A verb's answer is in the text once, and the prompt can write the word
  /// before it in full.
  void _checkPlace(
    void Function(String) error,
    String text,
    SentenceVerb link,
  ) {
    final at = findOnce(text, link.answer);
    if (at == null) {
      error(
        'the answer "${link.answer}" (${link.verbId}) is not in the text '
        'exactly once, as whole words',
      );
      return;
    }
    final elided = elidedBefore(text, at.start)?.toLowerCase();
    if (elided == 'l') {
      if (link.before == null) {
        error(
          '"${link.answer}" follows l’: say whether it is le or la, with '
          '"before"',
        );
      }
    } else if (link.before != null) {
      error('"before" only applies when the answer follows l’');
    } else if (elided != null && !fullForms.containsKey(elided)) {
      error(
        '"${link.answer}" follows $elided’, which the prompt can’t write '
        'in full: reword the sentence',
      );
    }
  }

  static bool _startsWithH(String word) => word.toLowerCase().startsWith('h');

  static List<({String file, String? source})> _imageEntries(
    Map<String, Object?> noun,
  ) => [
    for (final entry in _list(noun['images']))
      switch (entry) {
        final String file => (file: file, source: null),
        final Map<String, Object?> json => (
          file: json['file']! as String,
          source: json['source'] as String?,
        ),
        _ => throw StateError('the schema allows only these'),
      },
  ];

  static ContentCategory _category(Map<String, Object?> json) =>
      ContentCategory(
        id: json['id']! as String,
        name: json['name']! as String,
        kind: _byId(CategoryKind.values, json['kind'], (k) => k.id),
        sortOrder: json['sort_order']! as int,
        everyday: json['everyday'] as bool? ?? false,
      );

  static ContentNoun _noun(Map<String, Object?> json, String categoryId) =>
      ContentNoun(
        id: json['id']! as String,
        word: json['word']! as String,
        gender: _byId(Gender.values, json['gender'], (g) => g.id),
        elides: json['elides'] as bool? ?? false,
        pluralOnly: json['plural_only'] as bool? ?? false,
        level: _byId(Level.values, json['level'], (l) => l.id),
        rank: json['rank'] as int?,
        definition: json['definition'] as String?,
        gloss: json['gloss'] as String?,
        endingHint: json['ending_hint'] as String?,
        synonyms: [
          for (final s in _list(json['synonyms']))
            switch (s) {
              final String word => Synonym(word),
              final Map<String, Object?> json => Synonym(
                json['word']! as String,
                gender: json['gender'] == null
                    ? null
                    : _byId(Gender.values, json['gender'], (g) => g.id),
                elides: json['elides'] as bool?,
              ),
              _ => throw StateError('the schema allows only these'),
            },
        ],
        categoryIds: [categoryId, ..._strings(json['also_in'])],
        imageIds: [
          for (final entry in _imageEntries(json))
            ContentImage.idFor(entry.file),
        ],
      );

  static ContentVerb _verb(Map<String, Object?> json) {
    final forms = _map(json['forms']);
    return ContentVerb(
      id: json['id']! as String,
      infinitive: json['infinitive']! as String,
      group: _byId(VerbGroup.values, json['group'], (g) => g.id),
      auxiliary: _byId(Auxiliary.values, json['auxiliary'], (a) => a.id),
      pronominal: json['pronominal'] as bool? ?? false,
      hAspire: json['h_aspire'] as bool? ?? false,
      level: _byId(Level.values, json['level'], (l) => l.id),
      rank: json['rank'] as int?,
      categoryIds: _strings(json['categories']),
      forms: [
        for (final tense in Tense.values)
          for (final person in Person.values)
            ContentVerbForm(
              tense: tense,
              person: person,
              form: _map(forms[tense.id])[person.id]! as String,
              alternatives: _strings(
                _map(_map(forms[tense.id])['alt'])[person.id],
              ),
            ),
      ],
    );
  }

  static ContentSentence _sentence(Map<String, Object?> json) =>
      ContentSentence(
        id: json['id']! as String,
        text: json['text']! as String,
        verbs: [
          for (final v in _listOfMaps(json['verbs']))
            SentenceVerb(
              verbId: v['verb']! as String,
              tense: _byId(Tense.values, v['tense'], (t) => t.id),
              person: _byId(Person.values, v['person'], (p) => p.id),
              answer: v['answer']! as String,
              alternatives: _strings(v['alternatives']),
              before: v['before'] as String?,
            ),
        ],
        nouns: [
          for (final n in _listOfMaps(json['nouns']))
            SentenceNoun(
              nounId: n['noun']! as String,
              word: n['word']! as String,
            ),
        ],
        credit: switch (json['credit']) {
          {'tatoeba': final int id, 'author': final String author} =>
            SentenceCredit(tatoebaId: id, author: author),
          _ => null,
        },
      );

  static T _byId<T extends Enum>(
    List<T> values,
    Object? id,
    String Function(T) idOf,
  ) => byId(values, id! as String, idOf)!;

  static Map<String, Object?> _map(Object? json) =>
      json as Map<String, Object?>? ?? const {};

  static List<Map<String, Object?>> _listOfMaps(Object? json) =>
      (json as List<Object?>? ?? const []).cast();

  static List<Object?> _list(Object? json) =>
      json as List<Object?>? ?? const [];

  static List<String> _strings(Object? json) => _list(json).cast();
}
