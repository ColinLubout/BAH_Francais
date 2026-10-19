/// The tables of the user's practice (Spaced Repetition → Data model), and
/// the category weights. Content updates never touch them.
library;

import 'package:bah_francais/core/database/converters.dart';
import 'package:drift/drift.dart';

/// One item in one drill, with its FSRS state.
@DataClassName('CardRow')
@TableIndex.sql(
  // One card per noun and drill, or per verb and tense. A plain unique index
  // would let a null tense repeat.
  'CREATE UNIQUE INDEX cards_item ON cards '
  "(item_id, drill_type, IFNULL(tense, ''))",
)
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// A noun for Genre and Vocabulaire, a verb for Conjugaison. No foreign
  /// key, since it can be either.
  TextColumn get itemId => text()();
  TextColumn get drillType => text().map(drillConverter)();

  /// Conjugation cards only.
  TextColumn get tense => text().map(tenseConverter).nullable()();
  TextColumn get state =>
      text().map(cardStateConverter).withDefault(const Constant('new'))();

  /// The learning or relearning step.
  IntColumn get step => integer().nullable()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  IntColumn get due => integer().map(utcConverter).nullable()();
  IntColumn get lastReview => integer().map(utcConverter).nullable()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  /// Every Again that stands, in any state: eight make a leech.
  IntColumn get againCount => integer().withDefault(const Constant(0))();
  BoolColumn get isLeech => boolean().withDefault(const Constant(false))();

  /// Set when the user marks the card known: it is then never scheduled.
  IntColumn get knownAt => integer().map(utcConverter).nullable()();
  IntColumn get createdAt => integer().map(utcConverter)();
}

/// One row per answer. Deleting a word deletes its cards, and their rows
/// with them.
@DataClassName('ReviewLogRow')
@TableIndex(name: 'review_logs_card', columns: {#cardId})
@TableIndex(name: 'review_logs_day', columns: {#studyDay})
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get timestamp => integer().map(utcConverter)();

  /// The study day the answer counts towards, `yyyymmdd`.
  IntColumn get studyDay => integer()();
  IntColumn get rating => integer().map(ratingConverter)();
  TextColumn get stateBefore => text().map(cardStateConverter)();

  /// Null for a card's first review.
  IntColumn get elapsedDays => integer().nullable()();

  /// The interval this review set; 0 for a learning or relearning step.
  IntColumn get scheduledDays => integer()();
  IntColumn get responseTimeMs => integer()();

  /// What the user typed, or the gender they chose; null for *Je ne sais
  /// pas*.
  TextColumn get typedAnswer => text().nullable()();
  TextColumn get errorType => text().map(errorTypeConverter)();
}

/// A run of answers, from the first to the last.
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The drill, or `mixed` for a mixed session (null in Dart).
  TextColumn get drillType => text().map(sessionDrillConverter)();
  IntColumn get startTime => integer().map(utcConverter)();

  /// The time of the last answer so far, so a session cut short by a
  /// force-close still has an end.
  IntColumn get endTime => integer().map(utcConverter)();
  IntColumn get answered => integer().withDefault(const Constant(0))();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get incorrect => integer().withDefault(const Constant(0))();
}

/// A category's weight in one drill. No row is Normal.
@DataClassName('CategoryWeightRow')
class CategoryWeights extends Table {
  TextColumn get drillType => text().map(drillConverter)();
  TextColumn get categoryId => text()();
  TextColumn get weight => text().map(weightConverter)();

  @override
  Set<Column<Object>> get primaryKey => {drillType, categoryId};
}
