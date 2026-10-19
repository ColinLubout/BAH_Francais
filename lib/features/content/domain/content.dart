import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:meta/meta.dart';

/// The version of the content tables a content pack is built for. A pack
/// built for a newer version needs a newer app.
const contentSchemaVersion = 1;

/// The official content: what the content files describe, and what a
/// content pack and the app's database hold.
@immutable
class ContentSet {
  const ContentSet({
    this.categories = const [],
    this.nouns = const [],
    this.verbs = const [],
    this.images = const [],
  });

  final List<ContentCategory> categories;
  final List<ContentNoun> nouns;
  final List<ContentVerb> verbs;
  final List<ContentImage> images;

  /// Everything as plain values, each list in a fixed order, so two sets can
  /// be compared whatever order they were read in.
  Map<String, Object?> toJson() => {
    'categories': _sortedById(categories, (c) => c.id, (c) => c.toJson()),
    'nouns': _sortedById(nouns, (n) => n.id, (n) => n.toJson()),
    'verbs': _sortedById(verbs, (v) => v.id, (v) => v.toJson()),
    'images': _sortedById(images, (i) => i.id, (i) => i.toJson()),
  };
}

/// What a content pack says about itself.
@immutable
class ContentInfo {
  const ContentInfo({
    required this.version,
    required this.releasedAt,
    this.schemaVersion = contentSchemaVersion,
  });

  /// Goes up by 1 with each published pack; 0 for a development build.
  final int version;

  /// The release date, `yyyy-mm-dd`.
  final String releasedAt;

  final int schemaVersion;
}

@immutable
class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.sortOrder,
    this.everyday = false,
  });

  final String id;
  final String name;
  final CategoryKind kind;

  /// Where the category is listed.
  final int sortOrder;

  /// The universally useful words, whose new cards come before the topics'.
  final bool everyday;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.id,
    'sort_order': sortOrder,
    'everyday': everyday,
  };
}

@immutable
class ContentNoun {
  const ContentNoun({
    required this.id,
    required this.word,
    required this.gender,
    required this.level,
    required this.categoryIds,
    required this.examples,
    this.elides = false,
    this.pluralOnly = false,
    this.rank,
    this.definition,
    this.gloss,
    this.endingHint,
    this.synonyms = const [],
    this.imageIds = const [],
  });

  final String id;
  final String word;
  final Gender gender;

  /// Takes *l’*.
  final bool elides;
  final bool pluralOnly;
  final Level level;

  /// Frequency rank, 1 the most common.
  final int? rank;
  final String? definition;
  final String? gloss;

  /// An ending rule shown as *Astuce* (*-tion → féminin*).
  final String? endingHint;
  final List<Synonym> synonyms;
  final List<String> categoryIds;

  /// Example sentences, in order.
  final List<String> examples;

  /// Its images' ids, in order.
  final List<String> imageIds;

  /// The id of example [index] (from 0): `n.fourchette.ex01`.
  static String exampleId(String nounId, int index) =>
      '$nounId.ex${(index + 1).toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'word': word,
    'gender': gender.id,
    'elides': elides,
    'plural_only': pluralOnly,
    'level': level.id,
    'rank': rank,
    'definition': definition,
    'gloss': gloss,
    'ending_hint': endingHint,
    'synonyms': [for (final s in synonyms) synonymToJson(s)],
    'categories': [...categoryIds]..sort(),
    'examples': examples,
    'images': imageIds,
  };
}

/// [synonym] as stored: only what differs from its noun.
Map<String, Object?> synonymToJson(Synonym synonym) => {
  'word': synonym.word,
  if (synonym.gender != null) 'gender': synonym.gender!.id,
  if (synonym.elides != null) 'elides': synonym.elides,
};

@immutable
class ContentVerb {
  const ContentVerb({
    required this.id,
    required this.infinitive,
    required this.group,
    required this.auxiliary,
    required this.level,
    required this.categoryIds,
    required this.forms,
    required this.sentences,
    this.pronominal = false,
    this.hAspire = false,
    this.rank,
  });

  final String id;
  final String infinitive;
  final VerbGroup group;
  final Auxiliary auxiliary;
  final bool pronominal;

  /// Forms starting with *h* don't elide what comes before them: *je hais*,
  /// not *j’hais*.
  final bool hAspire;
  final Level level;
  final int? rank;
  final List<String> categoryIds;
  final List<ContentVerbForm> forms;
  final List<ContentSentence> sentences;

  /// The form for [tense] and [person], or null.
  ContentVerbForm? form(Tense tense, Person person) {
    for (final form in forms) {
      if (form.tense == tense && form.person == person) return form;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'infinitive': infinitive,
    'group': group.id,
    'auxiliary': auxiliary.id,
    'pronominal': pronominal,
    'h_aspire': hAspire,
    'level': level.id,
    'rank': rank,
    'categories': [...categoryIds]..sort(),
    'forms': [
      for (final tense in Tense.values)
        for (final person in Person.values)
          if (form(tense, person) case final f?) f.toJson(),
    ],
    'sentences': _sortedById(sentences, (s) => s.id, (s) => s.toJson()),
  };
}

/// A verb's form for one tense and person. Compound tenses store the
/// masculine singular participle (*suis allé*).
@immutable
class ContentVerbForm {
  const ContentVerbForm({
    required this.tense,
    required this.person,
    required this.form,
    this.alternatives = const [],
  });

  final Tense tense;
  final Person person;
  final String form;

  /// Other accepted forms (*paye* beside *paie*).
  final List<String> alternatives;

  Map<String, Object?> toJson() => {
    'tense': tense.id,
    'person': person.id,
    'form': form,
    'alternatives': alternatives,
  };
}

/// A Conjugation prompt: [text] has `___` where the verb goes.
@immutable
class ContentSentence {
  const ContentSentence({
    required this.id,
    required this.tense,
    required this.person,
    required this.text,
    required this.answer,
    this.alternatives = const [],
  });

  final String id;
  final Tense tense;
  final Person person;
  final String text;

  /// What fills the blank, with any agreement (*sommes allés*).
  final String answer;
  final List<String> alternatives;

  Map<String, Object?> toJson() => {
    'id': id,
    'tense': tense.id,
    'person': person.id,
    'text': text,
    'answer': answer,
    'alternatives': alternatives,
  };
}

/// An image of a noun: SVG markup, or the encoded bytes of a PNG or JPEG.
@immutable
class ContentImage {
  const ContentImage({
    required this.id,
    required this.itemId,
    required this.format,
    this.svg,
    this.bytes,
    this.credit,
  }) : assert(
         (format == ImageFormat.svg) == (svg != null) &&
             (svg == null) != (bytes == null),
         'An SVG has markup and no bytes; a PNG or JPEG has bytes',
       );

  final String id;
  final String itemId;
  final ImageFormat format;
  final String? svg;
  final List<int>? bytes;

  /// Who made it, listed on À propos / Crédits.
  final String? credit;

  /// The id of an official image stored as [fileName]: `i.fourchette-1`.
  static String idFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return 'i.${dot < 0 ? fileName : fileName.substring(0, dot)}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'item_id': itemId,
    'format': format.id,
    'svg': svg,
    'bytes': bytes,
    'credit': credit,
  };
}

List<Map<String, Object?>> _sortedById<T>(
  List<T> items,
  String Function(T) id,
  Map<String, Object?> Function(T) toJson,
) => [
  for (final item in [...items]..sort((a, b) => id(a).compareTo(id(b))))
    toJson(item),
];
