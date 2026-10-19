import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/data/content_tables.drift.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/data/drill_tables.drift.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// An answer as the review log records it.
@immutable
class Answer {
  const Answer({
    required this.outcome,
    required this.sessionId,
    required this.responseTime,
    required this.errorType,
    this.typed,
  });

  final ReviewOutcome outcome;
  final int sessionId;

  /// From the prompt appearing to the answer being submitted.
  final Duration responseTime;
  final ErrorType errorType;

  /// What the user typed, or the gender they chose; null for *Je ne sais
  /// pas*.
  final String? typed;

  /// Counted as correct in the session: anything but Again.
  bool get correct => outcome.rating != Rating.again;
}

/// The cards, and the answers that move them on.
class CardsDao {
  CardsDao(this._db);

  final AppDatabase _db;

  /// Creates New cards dated [at]: Genre and Vocabulaire cards for each of
  /// [nounIds], and one Conjugaison card per tense for each of [verbIds].
  Future<void> createCards({
    required DateTime at,
    Iterable<String> nounIds = const [],
    Iterable<String> verbIds = const [],
  }) => _db.batch(
    (batch) => batch.insertAll(_db.cards, [
      for (final id in nounIds)
        for (final drill in [DrillType.gender, DrillType.vocabulary])
          CardsCompanion.insert(itemId: id, drillType: drill, createdAt: at),
      for (final id in verbIds)
        for (final tense in Tense.values)
          CardsCompanion.insert(
            itemId: id,
            drillType: DrillType.conjugation,
            tense: Value(tense),
            createdAt: at,
          ),
    ]),
  );

  Future<DrillCard?> card(int id) async {
    final row = await (_db.select(
      _db.cards,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _card(row);
  }

  /// Every card of [drill], in the order they were created.
  Future<List<DrillCard>> cards(DrillType drill) => _ofDrill(drill).get();

  Stream<List<DrillCard>> watchCards(DrillType drill) =>
      _ofDrill(drill).watch();

  /// Every card of [drill], with what the queue needs to know about its
  /// item: categories, level, rank, Perso, retired and verb group.
  Future<List<QueueCard>> queueCards(DrillType drill) async {
    final cards = await this.cards(drill);
    if (drill == DrillType.conjugation) {
      final verbs = {
        for (final v in await _db.select(_db.verbs).get()) v.id: v,
      };
      final links = await _links<VerbCategoryRow>(
        _db.select(_db.verbCategories)..where((l) => l.retired.not()),
        (l) => (l.verbId, l.categoryId),
      );
      return [
        for (final card in cards)
          if (verbs[card.itemId] case final verb?)
            QueueCard(
              card: card,
              categoryIds: links[verb.id] ?? const [],
              level: verb.level,
              rank: verb.rank,
              isPerso: verb.source == ContentSource.perso,
              retired: verb.retired,
              verbGroup: verb.verbGroup,
            ),
      ];
    }
    final nouns = {for (final n in await _db.select(_db.nouns).get()) n.id: n};
    final links = await _links<NounCategoryRow>(
      _db.select(_db.nounCategories)..where((l) => l.retired.not()),
      (l) => (l.nounId, l.categoryId),
    );
    return [
      for (final card in cards)
        if (nouns[card.itemId] case final noun?)
          QueueCard(
            card: card,
            categoryIds: links[noun.id] ?? const [],
            level: noun.level,
            rank: noun.rank,
            isPerso: noun.source == ContentSource.perso,
            retired: noun.retired,
          ),
    ];
  }

  /// Saves an answer: the card's new state, its review-log row and the
  /// session's counts, in one transaction, so a force-close never keeps one
  /// without the others. Returns the review-log row's id.
  Future<int> recordAnswer(Answer answer) => _db.transaction(() async {
    await _saveCard(answer.outcome.after);
    final logId = await _db.into(_db.reviewLogs).insert(_log(answer));
    await _count(
      answer.sessionId,
      at: answer.outcome.reviewedAt,
      answered: 1,
      correct: answer.correct ? 1 : 0,
    );
    return logId;
  });

  /// Replaces the answer saved as [logId], as the override buttons do: the
  /// card takes [answer]'s state, and the row and session counts change to
  /// match. No row is added.
  Future<void> replaceAnswer(int logId, Answer answer) =>
      _db.transaction(() async {
        final old = await (_db.select(
          _db.reviewLogs,
        )..where((l) => l.id.equals(logId))).getSingle();
        await _saveCard(answer.outcome.after);
        await (_db.update(
          _db.reviewLogs,
        )..where((l) => l.id.equals(logId))).write(_log(answer));
        final wasCorrect = old.rating != Rating.again;
        await _count(
          old.sessionId,
          at: answer.outcome.reviewedAt,
          answered: 0,
          correct: (answer.correct ? 1 : 0) - (wasCorrect ? 1 : 0),
        );
      });

  /// Marks the cards known at [at], or brings them back into practice when
  /// [at] is null. No rating and no review-log row: it isn't an answer.
  Future<void> setKnownAt(Iterable<int> cardIds, DateTime? at) =>
      (_db.update(_db.cards)..where((c) => c.id.isIn(cardIds))).write(
        CardsCompanion(knownAt: Value(at)),
      );

  /// What [day]'s answers in [drill] have used of the daily limits, counted
  /// from the review log by the study day each answer stored.
  Future<DayCounts> dayCounts(DrillType drill, StudyDay day) async {
    final logs = _db.reviewLogs;
    final count = logs.id.count();
    final rows =
        await (_db.selectOnly(logs)
              ..join([
                innerJoin(
                  _db.cards,
                  _db.cards.id.equalsExp(logs.cardId),
                  useColumns: false,
                ),
              ])
              ..addColumns([logs.stateBefore, count])
              ..where(
                _db.cards.drillType.equalsValue(drill) &
                    logs.studyDay.equals(day.key),
              )
              ..groupBy([logs.stateBefore]))
            .get();
    var newCards = 0;
    var reviews = 0;
    for (final row in rows) {
      final state = row.readWithConverter(logs.stateBefore);
      final n = row.read(count) ?? 0;
      if (state == CardState.newCard) newCards += n;
      if (state == CardState.review) reviews += n;
    }
    return DayCounts(newCards: newCards, reviews: reviews);
  }

  Selectable<DrillCard> _ofDrill(DrillType drill) =>
      (_db.select(_db.cards)
            ..where((c) => c.drillType.equalsValue(drill))
            ..orderBy([(c) => OrderingTerm(expression: c.id)]))
          .map(_card);

  Future<void> _saveCard(DrillCard card) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(card.id))).write(
        CardsCompanion(
          state: Value(card.state),
          step: Value(card.step),
          stability: Value(card.stability),
          difficulty: Value(card.difficulty),
          due: Value(card.due),
          lastReview: Value(card.lastReview),
          reps: Value(card.reps),
          lapses: Value(card.lapses),
          againCount: Value(card.againCount),
          isLeech: Value(card.isLeech),
        ),
      );

  ReviewLogsCompanion _log(Answer answer) {
    final outcome = answer.outcome;
    return ReviewLogsCompanion.insert(
      cardId: outcome.after.id,
      sessionId: answer.sessionId,
      timestamp: outcome.reviewedAt,
      studyDay: outcome.studyDay.key,
      rating: outcome.rating,
      stateBefore: outcome.stateBefore,
      elapsedDays: Value(outcome.elapsedDays),
      scheduledDays: outcome.scheduledDays,
      responseTimeMs: answer.responseTime.inMilliseconds,
      typedAnswer: Value(answer.typed),
      errorType: answer.errorType,
    );
  }

  /// Adds to the session's counts, and moves its end to [at] if later.
  Future<void> _count(
    int sessionId, {
    required DateTime at,
    required int answered,
    required int correct,
  }) => _db.customUpdate(
    'UPDATE sessions SET answered = answered + ?1, correct = correct + ?2, '
    'incorrect = incorrect + ?3, end_time = MAX(end_time, ?4) WHERE id = ?5',
    variables: [
      Variable.withInt(answered),
      Variable.withInt(correct),
      Variable.withInt(answered - correct),
      Variable.withInt(at.toUtc().microsecondsSinceEpoch),
      Variable.withInt(sessionId),
    ],
    updates: {_db.sessions},
  );

  Future<Map<String, List<String>>> _links<R>(
    Selectable<R> query,
    (String, String) Function(R) pair,
  ) async {
    final links = <String, List<String>>{};
    for (final row in await query.get()) {
      final (item, category) = pair(row);
      (links[item] ??= []).add(category);
    }
    return links;
  }

  static DrillCard _card(CardRow row) => DrillCard(
    id: row.id,
    itemId: row.itemId,
    drill: row.drillType,
    tense: row.tense,
    createdAt: row.createdAt,
    state: row.state,
    step: row.step,
    stability: row.stability,
    difficulty: row.difficulty,
    due: row.due,
    lastReview: row.lastReview,
    reps: row.reps,
    lapses: row.lapses,
    againCount: row.againCount,
    isLeech: row.isLeech,
    knownAt: row.knownAt,
  );
}
