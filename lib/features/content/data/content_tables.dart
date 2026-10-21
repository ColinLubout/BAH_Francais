/// The content tables (Content → Content model), shared by the app's database
/// and content packs.
library;

import 'package:bah_francais/core/database/converters.dart';
import 'package:bah_francais/features/content/data/content_tables.drift.dart';
import 'package:drift/drift.dart';

/// The content tables, as both the app's database and a content pack have
/// them, so the same code can read and write either.
abstract interface class ContentTables {
  $CategoriesTable get categories;
  $NounsTable get nouns;
  $NounCategoriesTable get nounCategories;
  $VerbsTable get verbs;
  $VerbCategoriesTable get verbCategories;
  $VerbFormsTable get verbForms;
  $SentencesTable get sentences;
  $SentenceVerbsTable get sentenceVerbs;
  $SentenceNounsTable get sentenceNouns;
  $ImagesTable get images;
  $ContentMetaTable get contentMeta;
}

/// The columns every content table has.
mixin ContentColumns on Table {
  /// Official (from a content pack) or Perso (the user's own).
  TextColumn get source =>
      text().map(sourceConverter).withDefault(const Constant('official'))();

  /// Removed by a content update: hidden and never scheduled, but kept so
  /// review logs stay valid.
  BoolColumn get retired => boolean().withDefault(const Constant(false))();
}

@DataClassName('CategoryRow')
class Categories extends Table with ContentColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text().map(categoryKindConverter)();

  /// Where the category is listed.
  IntColumn get sortOrder => integer()();

  /// The universally useful words, whose new cards come first.
  BoolColumn get everyday => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NounRow')
class Nouns extends Table with ContentColumns {
  TextColumn get id => text()();
  TextColumn get word => text()();
  TextColumn get gender => text().map(genderConverter)();

  /// Takes *l’*.
  BoolColumn get elides => boolean().withDefault(const Constant(false))();
  BoolColumn get pluralOnly => boolean().withDefault(const Constant(false))();
  TextColumn get definition => text().nullable()();
  TextColumn get gloss => text().nullable()();
  TextColumn get synonyms =>
      text().map(synonymListConverter).withDefault(const Constant('[]'))();
  TextColumn get endingHint => text().nullable()();

  /// Official nouns only.
  TextColumn get level => text().map(levelConverter).nullable()();
  IntColumn get rank => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NounCategoryRow')
class NounCategories extends Table with ContentColumns {
  TextColumn get nounId =>
      text().references(Nouns, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id)();

  @override
  Set<Column<Object>> get primaryKey => {nounId, categoryId};
}

@DataClassName('VerbRow')
class Verbs extends Table with ContentColumns {
  TextColumn get id => text()();
  TextColumn get infinitive => text()();
  TextColumn get verbGroup => text().named('group').map(verbGroupConverter)();
  TextColumn get auxiliary => text().map(auxiliaryConverter)();
  BoolColumn get pronominal => boolean().withDefault(const Constant(false))();

  /// Forms starting with *h* don't elide what comes before them.
  BoolColumn get hAspire => boolean().withDefault(const Constant(false))();
  TextColumn get level => text().map(levelConverter)();
  IntColumn get rank => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('VerbCategoryRow')
class VerbCategories extends Table with ContentColumns {
  TextColumn get verbId =>
      text().references(Verbs, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id)();

  @override
  Set<Column<Object>> get primaryKey => {verbId, categoryId};
}

@DataClassName('VerbFormRow')
class VerbForms extends Table with ContentColumns {
  TextColumn get verbId =>
      text().references(Verbs, #id, onDelete: KeyAction.cascade)();
  TextColumn get tense => text().map(tenseConverter)();
  TextColumn get person => text().map(personConverter)();

  /// Compound tenses store the masculine singular participle (*suis allé*).
  TextColumn get form => text()();
  TextColumn get alternatives =>
      text().map(stringListConverter).withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {verbId, tense, person};
}

/// A sentence written in full. Its links say which verbs it is a
/// Conjugation prompt for and which nouns it is an example of.
@DataClassName('SentenceRow')
class Sentences extends Table with ContentColumns {
  TextColumn get id => text()();

  /// The sentence, with no blank. A column called `text` breaks Drift's
  /// generated schema test helpers.
  TextColumn get sentenceText => text()();

  /// The credit of a sentence from Tatoeba: its number there and its author.
  IntColumn get tatoebaId => integer().nullable()();
  TextColumn get tatoebaAuthor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A verb a sentence uses, in one tense and person.
@DataClassName('SentenceVerbRow')
class SentenceVerbs extends Table with ContentColumns {
  TextColumn get sentenceId =>
      text().references(Sentences, #id, onDelete: KeyAction.cascade)();
  TextColumn get verbId =>
      text().references(Verbs, #id, onDelete: KeyAction.cascade)();
  TextColumn get tense => text().map(tenseConverter)();
  TextColumn get person => text().map(personConverter)();

  /// The words the drill blanks out, with any agreement (*sommes allés*).
  TextColumn get answer => text()();
  TextColumn get alternatives =>
      text().map(stringListConverter).withDefault(const Constant('[]'))();

  /// *le* or *la*, when the word before the answer is an elided *l’*.
  TextColumn get before => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sentenceId, verbId, tense, person};
}

/// A noun a sentence is an example of.
@DataClassName('SentenceNounRow')
class SentenceNouns extends Table with ContentColumns {
  TextColumn get sentenceId =>
      text().references(Sentences, #id, onDelete: KeyAction.cascade)();
  TextColumn get nounId =>
      text().references(Nouns, #id, onDelete: KeyAction.cascade)();

  /// The words the noun takes in the sentence (*haricots*), shown in bold.
  TextColumn get word => text()();

  @override
  Set<Column<Object>> get primaryKey => {sentenceId, nounId};
}

/// A noun's images (Spaced Repetition → Data model). Not a content table:
/// official images are those of official nouns.
@DataClassName('ImageRow')
class Images extends Table {
  TextColumn get id => text()();
  TextColumn get itemId =>
      text().references(Nouns, #id, onDelete: KeyAction.cascade)();
  TextColumn get format => text().map(imageFormatConverter)();

  /// The markup of an SVG; null for a PNG or JPEG.
  TextColumn get svg => text().nullable()();

  /// The encoded bytes of a PNG or JPEG; null for an SVG.
  BlobColumn get bytes => blob().nullable()();

  /// The credit: who made the image, listed on À propos / Crédits.
  TextColumn get source => text().nullable()();
  IntColumn get createdAt => integer().map(utcConverter)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((svg IS NULL) <> (bytes IS NULL))',
    "CHECK ((format = 'svg') = (svg IS NOT NULL))",
  ];
}

/// What the installed content says about itself: `content_version`,
/// `released_at` and `schema_version`.
@DataClassName('ContentMetaRow')
class ContentMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
