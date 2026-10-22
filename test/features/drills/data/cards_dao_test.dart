import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/data/content_tables.drift.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:bah_francais/features/drills/data/sessions_dao.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/content_fixture.dart';
import '../domain/helpers.dart';

final scheduler = DrillScheduler(random: () => 0.5);
final created = DateTime.utc(2026, 9);

/// The fixture's content with its cards, and a session to answer in.
Future<({AppDatabase db, CardsDao dao, int session})> setUpCards() async {
  final db = await databaseWith(fixture);
  final dao = CardsDao(db);
  await dao.createCards(
    at: created,
    nounIds: ['n.aa', 'n.bb'],
    verbIds: ['v.cc'],
  );
  final session = await SessionsDao(db)
      .start(drill: DrillType.vocabulary, at: noon);
  return (db: db, dao: dao, session: session);
}

Future<DrillCard> cardOf(CardsDao dao, DrillType drill, String itemId) async =>
    (await dao.cards(drill)).firstWhere((c) => c.itemId == itemId);

Answer answer(
  ReviewOutcome outcome,
  int session, {
  ErrorType errorType = ErrorType.none,
  String? typed = 'typed',
}) => Answer(
  outcome: outcome,
  sessionId: session,
  responseTime: const Duration(milliseconds: 2500),
  errorType: errorType,
  typed: typed,
);

void main() {
  test('Genre and Vocabulaire cards for each noun, a Conjugaison card '
      'per tense for each verb, all new', () async {
    final (:dao, db: _, session: _) = await setUpCards();

    for (final drill in [DrillType.gender, DrillType.vocabulary]) {
      expect((await dao.cards(drill)).map((c) => c.itemId), ['n.aa', 'n.bb']);
    }
    final conjugation = await dao.cards(DrillType.conjugation);
    expect(conjugation.map((c) => c.tense), Tense.values);
    for (final card in [...conjugation, ...await dao.cards(DrillType.gender)]) {
      expect(card.state, CardState.newCard);
      expect(card.createdAt, created);
      expect(card.reps, 0);
      expect(card.knownAt, isNull);
    }
  });

  test('a verb has Conjugaison cards only in the tenses taught', () async {
    final db = await databaseWith(fixture);
    final dao = CardsDao(db);
    await dao.createCards(
      at: created,
      verbIds: ['v.cc'],
      tenses: [Tense.present, Tense.futurSimple],
    );
    expect((await dao.cards(DrillType.conjugation)).map((c) => c.tense), [
      Tense.present,
      Tense.futurSimple,
    ]);
  });

  test('an item has one card per drill, and a verb one per tense', () async {
    final (:dao, db: _, session: _) = await setUpCards();
    expect(
      dao.createCards(at: created, nounIds: ['n.aa']),
      throwsA(isA<Exception>()),
    );
    expect(
      dao.createCards(at: created, verbIds: ['v.cc']),
      throwsA(isA<Exception>()),
    );
  });

  test('an answer saves the card, its review-log row and the session '
      'counts together', () async {
    final (:db, :dao, :session) = await setUpCards();
    final card = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final outcome = scheduler.review(card, Rating.good, at: noon, day: today);

    final logId = await dao.recordAnswer(answer(outcome, session, typed: 'aa'));

    expect(await dao.card(card.id), outcome.after);
    final log = await (db.select(
      db.reviewLogs,
    )..where((l) => l.id.equals(logId))).getSingle();
    expect(log.cardId, card.id);
    expect(log.sessionId, session);
    expect(log.timestamp, noon);
    expect(log.studyDay, today.key);
    expect(log.rating, Rating.good);
    expect(log.stateBefore, CardState.newCard);
    expect(log.elapsedDays, isNull);
    expect(log.scheduledDays, outcome.scheduledDays);
    expect(log.responseTimeMs, 2500);
    expect(log.typedAnswer, 'aa');
    expect(log.errorType, ErrorType.none);

    final row = (await SessionsDao(db).session(session))!;
    expect((row.answered, row.correct, row.incorrect), (1, 1, 0));
    expect(row.endTime, noon);
  });

  test(
    'Again counts as incorrect; the session ends at its last answer',
    () async {
      final (:db, :dao, :session) = await setUpCards();
      final first = await cardOf(dao, DrillType.vocabulary, 'n.aa');
      final second = await cardOf(dao, DrillType.vocabulary, 'n.bb');
      final later = noon.add(const Duration(minutes: 3));

      await dao.recordAnswer(
        answer(
          scheduler.review(second, Rating.again, at: later, day: today),
          session,
          errorType: ErrorType.wrong,
        ),
      );
      await dao.recordAnswer(
        answer(
          scheduler.review(first, Rating.hard, at: noon, day: today),
          session,
        ),
      );

      final row = (await SessionsDao(db).session(session))!;
      expect((row.answered, row.correct, row.incorrect), (2, 1, 1));
      expect(row.endTime, later);
    },
  );

  test('a failed save keeps nothing', () async {
    final (:db, :dao, session: _) = await setUpCards();
    final card = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final outcome = scheduler.review(card, Rating.good, at: noon, day: today);

    // No such session: the review-log row can't be written.
    await expectLater(
      dao.recordAnswer(answer(outcome, 999)),
      throwsA(isA<Exception>()),
    );
    expect(await dao.card(card.id), card);
    expect(await db.select(db.reviewLogs).get(), isEmpty);
  });

  test('an override replaces the saved answer and its counts', () async {
    final (:db, :dao, :session) = await setUpCards();
    final card = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final wrong = scheduler.review(card, Rating.again, at: noon, day: today);
    final logId = await dao.recordAnswer(
      answer(wrong, session, errorType: ErrorType.wrong, typed: 'ax'),
    );

    // Faute de frappe.
    final typo = scheduler.regrade(wrong, Rating.hard);
    await dao.replaceAnswer(
      logId,
      answer(typo, session, errorType: ErrorType.typoOverride, typed: 'ax'),
    );

    expect(await dao.card(card.id), typo.after);
    final log = (await db.select(db.reviewLogs).get()).single;
    expect(log.id, logId);
    expect(log.rating, Rating.hard);
    expect(log.errorType, ErrorType.typoOverride);
    expect(log.stateBefore, CardState.newCard);
    final row = (await SessionsDao(db).session(session))!;
    expect((row.answered, row.correct, row.incorrect), (1, 1, 0));
  });

  test(
    'marking known writes no review-log row; bringing back undoes it',
    () async {
      final (:db, :dao, session: _) = await setUpCards();
      final gender = await cardOf(dao, DrillType.gender, 'n.aa');
      final vocabulary = await cardOf(dao, DrillType.vocabulary, 'n.aa');

      await dao.setKnownAt([gender.id, vocabulary.id], noon);
      expect((await dao.card(gender.id))!.knownAt, noon);
      expect((await dao.card(vocabulary.id))!.isKnown, isTrue);
      expect(await db.select(db.reviewLogs).get(), isEmpty);

      await dao.setKnownAt([gender.id], null);
      expect((await dao.card(gender.id))!.isKnown, isFalse);
      expect((await dao.card(vocabulary.id))!.isKnown, isTrue);
    },
  );

  test('the day’s counts come from the review log, by drill and study '
      'day', () async {
    final (:dao, db: _, :session) = await setUpCards();
    final aa = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final bb = await cardOf(dao, DrillType.vocabulary, 'n.bb');
    final gender = await cardOf(dao, DrillType.gender, 'n.aa');
    final tomorrow = StudyDay.fromKey(20260925);

    // A new card, a review and a learning step today; a new Genre card;
    // and a review tomorrow.
    final first = scheduler.review(aa, Rating.again, at: noon, day: today);
    await dao.recordAnswer(answer(first, session));
    await dao.recordAnswer(
      answer(
        scheduler.review(first.after, Rating.good, at: noon, day: today),
        session,
      ),
    );
    final inReview = reviewCard(id: bb.id, itemId: 'n.bb', due: noon);
    await dao.recordAnswer(
      answer(
        scheduler.review(inReview, Rating.good, at: noon, day: today),
        session,
      ),
    );
    await dao.recordAnswer(
      answer(
        scheduler.review(gender, Rating.good, at: noon, day: today),
        session,
      ),
    );
    await dao.recordAnswer(
      answer(
        scheduler.review(inReview, Rating.good, at: noon, day: tomorrow),
        session,
      ),
    );

    final counts = await dao.dayCounts(DrillType.vocabulary, today);
    expect((counts.newCards, counts.reviews), (1, 1));
    final genderCounts = await dao.dayCounts(DrillType.gender, today);
    expect((genderCounts.newCards, genderCounts.reviews), (1, 0));
    final next = await dao.dayCounts(DrillType.vocabulary, tomorrow);
    expect((next.newCards, next.reviews), (0, 1));
  });

  test('queue cards carry what the queue needs about their items', () async {
    final (:db, :dao, session: _) = await setUpCards();
    await db
        .into(db.nouns)
        .insert(
          NounsCompanion.insert(
            id: 'p.mine',
            word: 'mine',
            gender: Gender.masculine,
            source: const Value(ContentSource.perso),
          ),
        );
    await dao.createCards(at: noon, nounIds: ['p.mine']);
    await (db.update(db.nouns)..where((n) => n.id.equals('n.bb'))).write(
      const NounsCompanion(retired: Value(true)),
    );
    await (db.update(db.nounCategories)..where(
          (l) => l.nounId.equals('n.aa') & l.categoryId.equals('cat.topic'),
        ))
        .write(const NounCategoriesCompanion(retired: Value(true)));

    final nouns = {
      for (final q in await dao.queueCards(DrillType.vocabulary))
        q.card.itemId: q,
    };
    expect(nouns.keys, ['n.aa', 'n.bb', 'p.mine']);
    expect(nouns['n.aa']!.categoryIds, ['cat.everyday']);
    expect(nouns['n.aa']!.level, Level.debutant);
    expect(nouns['n.aa']!.rank, 1);
    expect(nouns['n.aa']!.isPerso, isFalse);
    expect(nouns['n.bb']!.retired, isTrue);
    expect(nouns['n.bb']!.rank, isNull);
    expect(nouns['p.mine']!.isPerso, isTrue);
    expect(nouns['p.mine']!.level, isNull);

    final verbs = await dao.queueCards(DrillType.conjugation);
    expect(verbs, hasLength(Tense.values.length));
    expect(verbs.first.categoryIds, ['cat.verbs']);
    expect(verbs.first.verbGroup, VerbGroup.irr);
    expect(verbs.first.level, Level.intermediaire);
    expect(verbs.first.rank, 7);
  });

  test('deleting a word’s cards deletes their review log too', () async {
    final (:db, :dao, :session) = await setUpCards();
    final kept = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final deleted = await cardOf(dao, DrillType.vocabulary, 'n.bb');
    for (final card in [kept, deleted]) {
      await dao.recordAnswer(
        answer(
          scheduler.review(card, Rating.good, at: noon, day: today),
          session,
        ),
      );
    }

    await (db.delete(db.cards)..where((c) => c.itemId.equals('n.bb'))).go();
    await (db.delete(db.nouns)..where((n) => n.id.equals('n.bb'))).go();

    expect(await dao.card(deleted.id), isNull);
    expect((await db.select(db.reviewLogs).get()).single.cardId, kept.id);
    expect(
      (await dao.queueCards(DrillType.vocabulary)).map((q) => q.card.itemId),
      ['n.aa'],
    );
  });

  test('cards stream as answers change them', () async {
    final (:dao, db: _, :session) = await setUpCards();
    final stream = dao.watchCards(DrillType.gender);
    final card = (await stream.first).first;
    expect(card.state, CardState.newCard);

    await dao.recordAnswer(
      answer(
        scheduler.review(card, Rating.good, at: noon, day: today),
        session,
      ),
    );
    expect((await stream.first).first.state, CardState.learning);
  });

  test('times read back exactly, in UTC', () async {
    final (:dao, db: _, :session) = await setUpCards();
    final card = await cardOf(dao, DrillType.vocabulary, 'n.aa');
    final at = DateTime.utc(2026, 9, 24, 10, 0, 0, 123, 456);
    await dao.recordAnswer(
      answer(scheduler.review(card, Rating.good, at: at, day: today), session),
    );
    final read = (await dao.card(card.id))!;
    expect(read.lastReview, at);
    expect(read.lastReview!.isUtc, isTrue);
  });
}
