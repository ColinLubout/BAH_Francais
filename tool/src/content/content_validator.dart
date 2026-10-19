/// Validates content files and turns them into the content they describe
/// (Content → Content files).
///
/// Each file is checked against its JSON Schema first. The rules beyond the
/// schema then run on everything that passed:
///
/// - every id is unique, and so is every image file name;
/// - every noun has an image or a definition;
/// - categories a noun or verb is in exist, and are of the right kind;
/// - at most one everyday category of each kind;
/// - a noun starting with *h* states `elides`, and a verb with a form
///   starting with *h* states `h_aspire` (and no other verb does);
/// - every verb has at least one sentence per tense and person;
/// - every sentence has `___` exactly once, with the word before it written
///   in full;
/// - a sentence's answer and alternatives are the stored form or one of its
///   alternatives, plus *e*, *s* or *es* in a compound tense for agreement;
/// - every image exists and follows the SVG rules; a big one is a warning.
library;

import 'dart:convert';

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:json_schema/json_schema.dart';

import 'content_files.dart';
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
  final images = <_Parsed<ContentImage>>[];

  /// The categories of files their schema refused. They exist but weren't
  /// read, so naming them elsewhere is not another mistake.
  final unread = <String>{};

  ContentReport run() {
    if (files.verbCategories case final file?) _readVerbCategories(file);
    files.nouns.forEach(_readNounFile);
    files.verbs.forEach(_readVerb);
    _readImages();

    _checkIds();
    _checkCategories();
    _checkNouns();
    _checkVerbs();

    return ContentReport(
      content: ContentSet(
        categories: [for (final c in categories) c.value],
        nouns: [for (final n in nouns) n.value],
        verbs: [for (final v in verbs) v.value],
        images: [for (final i in images) i.value],
      ),
      errors: errors,
      warnings: warnings,
    );
  }

  void _error(String file, String where, String message) =>
      errors.add(ContentIssue(file, where, message));

  /// [file] decoded, if it is JSON that its schema accepts. If the schema
  /// refuses it, the ids [categoriesIn] finds in it go to [unread].
  Map<String, Object?>? _decode(
    SourceFile file,
    JsonSchema schema, {
    Iterable<String> Function(Object? json)? categoriesIn,
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
    if (categoriesIn != null) unread.addAll(categoriesIn(json));
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

  void _readVerbCategories(SourceFile file) {
    final json = _decode(
      file,
      schemas.verbCategories,
      categoriesIn: (json) => [
        if (json case {'categories': final List<Object?> list})
          for (final c in list)
            if (c case {'id': final String id}) id,
      ],
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
      categoriesIn: (json) => [
        if (json case {'category': {'id': final String id}}) id,
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
    final json = _decode(file, schemas.verb);
    if (json == null) return;
    verbs.add(_Parsed(_verb(json), file.path, json));
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
      for (final s in v.value.sentences) {
        check(s.id, v.file, 'sentence');
      }
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
    for (final n in nouns) {
      final noun = n.value;
      if (noun.definition == null && _imageEntries(n.json).isEmpty) {
        _error(n.file, noun.id, 'has neither an image nor a definition');
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

      for (final tense in Tense.values) {
        for (final person in Person.values) {
          if (!verb.sentences.any(
            (s) => s.tense == tense && s.person == person,
          )) {
            _error(v.file, verb.id, 'no sentence for ${tense.id} ${person.id}');
          }
        }
      }

      for (final s in verb.sentences) {
        _checkSentence(v.file, verb, s);
      }
    }
  }

  void _checkSentence(String file, ContentVerb verb, ContentSentence s) {
    final blanks = RegExp('_+').allMatches(s.text).toList();
    if (blanks.isEmpty) {
      _error(file, s.id, 'has no ___');
    } else if (blanks.length > 1) {
      _error(file, s.id, 'has ___ more than once');
    } else if (blanks.single.group(0) != '___') {
      _error(file, s.id, 'its blank must be three underscores, ___');
    }
    if (RegExp(r"[’']\s*_").hasMatch(s.text)) {
      _error(
        file,
        s.id,
        'the word before ___ is elided: write it in full (Je ___, not '
        'J’___), since the app elides it as the user types',
      );
    }

    final form = verb.form(s.tense, s.person)!;
    final accepted = {
      for (final base in [form.form, ...form.alternatives].map(normalise)) ...[
        base,
        if (s.tense.isCompound) ...['${base}e', '${base}s', '${base}es'],
      ],
    };
    for (final answer in [s.answer, ...s.alternatives]) {
      if (!accepted.contains(normalise(answer))) {
        final alternatives = form.alternatives.isEmpty
            ? ''
            : ' or ${form.alternatives.map((a) => '"$a"').join(', ')}';
        _error(
          file,
          s.id,
          '"$answer" is not the ${s.tense.id} ${s.person.id} form, '
          '"${form.form}"$alternatives'
          '${s.tense.isCompound ? ', allowing for agreement' : ''}',
        );
      }
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
        examples: _strings(json['examples']),
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
      sentences: [
        for (final s in _listOfMaps(json['sentences']))
          ContentSentence(
            id: s['id']! as String,
            tense: _byId(Tense.values, s['tense'], (t) => t.id),
            person: _byId(Person.values, s['person'], (p) => p.id),
            text: s['text']! as String,
            answer: s['answer']! as String,
            alternatives: _strings(s['alternatives']),
          ),
      ],
    );
  }

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
