// The tests read as a sequence of steps on one session.
// ignore_for_file: cascade_invocations

import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_clock.dart';
import '../helpers.dart';

final scheduler = DrillScheduler(random: () => 0.5);

QueueCard q(
  DrillCard card, {
  List<String> categories = const ['cat.a'],
  int rank = 1,
  bool retired = false,
  VerbGroup? group,
}) => QueueCard(
  card: card,
  categoryIds: categories,
  level: Level.debutant,
  rank: rank,
  retired: retired,
  verbGroup: group,
);

/// A queue on a fake clock, at [noon] in Paris unless told otherwise.
class Session {
  Session(
    List<QueueCard> cards, {
    QueueSettings settings = const QueueSettings(),
    Map<StudyDay, DayCounts> counts = const {},
    Duration offset = paris,
    DateTime? now,
  }) : clock = FakeClock(now ?? noon, offset: offset),
       queue = SessionQueue(
         cards: cards,
         settings: settings,
         countsOn: (day) => counts[day] ?? const DayCounts(),
         scheduler: scheduler,
         random: () => 0,
       );

  final SessionQueue queue;
  final FakeClock clock;

  DateTime get now => clock.nowUtc();

  NextStep next() => queue.next(clock);

  ShowCard show() {
    final step = next();
    expect(step, isA<ShowCard>());
    return step as ShowCard;
  }

  /// Shows the next card and answers it with [rating].
  ShowCard answerNext([Rating rating = Rating.good]) {
    final shown = show();
    queue.record(
      scheduler.review(shown.card, rating, at: now, day: StudyDay.today(clock)),
    );
    return shown;
  }

  int dueToday() => queue.dueToday(clock);
}

/// Review cards due earlier today, all with the same memory state.
List<QueueCard> dueReviews(int count, {String prefix = 'r'}) => [
  for (var i = 0; i < count; i++)
    q(
      reviewCard(
        itemId: '$prefix$i',
        due: noon.subtract(Duration(hours: 1, minutes: i)),
      ),
    ),
];

List<QueueCard> newCards(int count, {String prefix = 'n'}) => [
  for (var i = 0; i < count; i++) q(newCard(itemId: '$prefix$i'), rank: i + 1),
];

void main() {
  group('order', () {
    test('learning steps first, then due reviews, then new cards', () {
      final learning = q(
        learningCard(itemId: 'learning', due: noon.subtract(minutes(1))),
      );
      final review = q(reviewCard(itemId: 'review', due: noon));
      final fresh = q(newCard(itemId: 'new'));
      final s = Session([fresh, review, learning]);

      final first = s.answerNext();
      expect(first.card.itemId, 'learning');
      expect(first.source, CardSource.learningStep);
      final second = s.answerNext();
      expect(second.card.itemId, 'review');
      expect(second.source, CardSource.dueReview);
      final third = s.show();
      expect(third.card.itemId, 'new');
      expect(third.source, CardSource.newCard);
    });

    test('learning steps come in the order they fall due', () {
      final later = q(learningCard(itemId: 'later', due: noon));
      final earlier = q(
        learningCard(itemId: 'earlier', due: noon.subtract(minutes(5))),
      );
      expect(Session([later, earlier]).show().card.itemId, 'earlier');
    });

    test('a learning step not yet due waits', () {
      final waiting = q(
        learningCard(itemId: 'waiting', due: noon.add(minutes(1))),
      );
      final review = q(reviewCard(itemId: 'review', due: noon));
      expect(Session([waiting, review]).show().card.itemId, 'review');
    });

    test('due reviews come lowest retrievability first', () {
      // Same stability; the one reviewed longest ago is closest to forgetting.
      final recent = q(
        reviewCard(
          itemId: 'recent',
          due: noon,
          stability: 5,
          lastReview: noon.subtract(const Duration(days: 5)),
        ),
      );
      final old = q(
        reviewCard(
          itemId: 'old',
          due: noon,
          stability: 5,
          lastReview: noon.subtract(const Duration(days: 20)),
        ),
      );
      final s = Session([recent, old]);
      expect(s.answerNext().card.itemId, 'old');
      expect(s.answerNext().card.itemId, 'recent');
    });

    test('a review is due all day, until the next 04:00', () {
      // Due at 23:00 tonight Paris time, or at 03:59 tomorrow.
      final tonight = q(
        reviewCard(itemId: 'tonight', due: DateTime.utc(2026, 9, 24, 21)),
      );
      final beforeFour = q(
        reviewCard(
          itemId: 'before four',
          due: DateTime.utc(2026, 9, 25, 1, 59),
        ),
      );
      final afterFour = q(
        reviewCard(itemId: 'after four', due: DateTime.utc(2026, 9, 25, 2)),
      );
      final s = Session([tonight, beforeFour, afterFour]);
      final shown = {s.answerNext().card.itemId, s.answerNext().card.itemId};
      expect(shown, {'tonight', 'before four'});
      // Only the card due after 04:00 is left: it comes as free practice.
      expect(s.show().source, CardSource.freePractice);
      expect(s.dueToday(), 0);
    });
  });

  group('new cards', () {
    test('one new card after every four reviews', () {
      final s = Session([...dueReviews(8), ...newCards(3)]);
      final sources = [for (var i = 0; i < 11; i++) s.answerNext().source];
      const r = CardSource.dueReview;
      const n = CardSource.newCard;
      // New cards' learning steps come back later; within these answers the
      // pattern is four reviews, then a new card.
      expect(sources.take(10), [r, r, r, r, n, r, r, r, r, n]);
    });

    test('back to back when no reviews are due', () {
      final s = Session(newCards(3));
      for (var i = 0; i < 3; i++) {
        expect(s.answerNext().source, CardSource.newCard);
      }
    });

    test('stop at the daily limit, counting earlier sessions today', () {
      final s = Session(
        newCards(5),
        settings: const QueueSettings(newPerDay: 3),
        counts: {today: const DayCounts(newCards: 1)},
      );
      expect(s.answerNext().source, CardSource.newCard);
      expect(s.answerNext().source, CardSource.newCard);
      // Limit reached: the new cards' learning steps aren't due yet, so free
      // practice shows them early.
      final after = s.show();
      expect(after.source, CardSource.freePractice);
      expect(after.card.state, isNot(CardState.newCard));
    });

    test('none at a limit of 0', () {
      final s = Session(
        newCards(2),
        settings: const QueueSettings(newPerDay: 0),
      );
      expect(s.next(), isA<NoCardsAvailable>());
    });

    test('a new limit applies from the next card', () {
      final s = Session(
        newCards(5),
        settings: const QueueSettings(newPerDay: 1),
      );
      expect(s.answerNext().source, CardSource.newCard);
      expect(s.show().source, isNot(CardSource.newCard));
      s.queue.settings = const QueueSettings(newPerDay: 2);
      expect(s.show().source, CardSource.newCard);
    });

    test('the limit resets at 04:00', () {
      final s = Session(
        newCards(3),
        settings: const QueueSettings(newPerDay: 1),
        now: DateTime.utc(2026, 9, 25, 1, 50), // 03:50 in Paris
      );
      // Easy, so it graduates and no learning step is left pending.
      expect(s.answerNext(Rating.easy).source, CardSource.newCard);
      expect(s.show().source, isNot(CardSource.newCard));
      s.clock.setNow(DateTime.utc(2026, 9, 25, 2)); // 04:00: a new study day
      expect(s.show().source, CardSource.newCard);
    });

    test('asking twice without answering gives the same new card', () {
      final queue = SessionQueue(
        cards: newCards(5),
        settings: const QueueSettings(),
        countsOn: (_) => const DayCounts(),
        scheduler: scheduler,
        random: () => 0.99,
      );
      final first = queue.next(FakeClock(noon, offset: paris)) as ShowCard;
      final again = queue.next(FakeClock(noon, offset: paris)) as ShowCard;
      expect(again.card.id, first.card.id);
    });

    test('marking a new card known costs no new-card slot', () {
      final cards = newCards(2);
      final s = Session(cards, settings: const QueueSettings(newPerDay: 1));
      final shown = s.show();
      s.queue.update(shown.card.withKnownAt(noon));
      final next = s.show();
      expect(next.source, CardSource.newCard);
      expect(next.card.id, isNot(shown.card.id));
    });
  });

  group('free practice', () {
    test('when nothing is due and the new-card limit is reached', () {
      final notDue = q(
        reviewCard(itemId: 'later', due: noon.add(const Duration(days: 3))),
      );
      final s = Session([notDue]);
      final shown = s.show();
      expect(shown.source, CardSource.freePractice);
      expect(shown.startsFreePractice, isTrue);
    });

    test('Tout est à jour is flagged only once', () {
      final s = Session([
        q(reviewCard(itemId: 'a', due: noon.add(const Duration(days: 3)))),
        q(reviewCard(itemId: 'b', due: noon.add(const Duration(days: 4)))),
      ]);
      expect(s.answerNext().startsFreePractice, isTrue);
      expect(s.answerNext().startsFreePractice, isFalse);
    });

    test('closest to forgetting first', () {
      final safe = q(
        reviewCard(
          itemId: 'safe',
          due: noon.add(const Duration(days: 20)),
          stability: 30,
          lastReview: noon.subtract(const Duration(days: 2)),
        ),
      );
      final shaky = q(
        reviewCard(
          itemId: 'shaky',
          due: noon.add(const Duration(days: 1)),
          stability: 3,
          lastReview: noon.subtract(const Duration(days: 2)),
        ),
      );
      expect(Session([safe, shaky]).show().card.itemId, 'shaky');
    });

    test('learning cards waiting for their step come first, soonest first', () {
      final review = q(
        reviewCard(itemId: 'review', due: noon.add(const Duration(days: 2))),
      );
      final soon = q(learningCard(itemId: 'soon', due: noon.add(minutes(2))));
      final later = q(learningCard(itemId: 'later', due: noon.add(minutes(8))));
      final shown = Session([review, later, soon]).show();
      expect(shown.card.itemId, 'soon');
      expect(shown.source, CardSource.freePractice);
    });

    test('the same card is not shown twice in a row if another exists', () {
      final s = Session([
        q(learningCard(itemId: 'a', due: noon.add(minutes(1)))),
        q(learningCard(itemId: 'b', due: noon.add(minutes(5)))),
      ]);
      final first = s.answerNext(Rating.again);
      final second = s.show();
      expect(second.card.itemId, isNot(first.card.itemId));
    });

    test('one card alone can come straight back', () {
      final s = Session([
        q(learningCard(itemId: 'only', due: noon.add(minutes(1)))),
      ]);
      s.answerNext(Rating.again);
      expect(s.show().card.itemId, 'only');
    });

    test('early reviews go through FSRS and count as reviews', () {
      final card = reviewCard(
        itemId: 'early',
        due: noon.add(const Duration(days: 5)),
      );
      final s = Session([q(card)]);
      s.answerNext();
      // Reviewed today, so due further out than before.
      final after = s.show().card;
      expect(after.reps, card.reps + 1);
      expect(after.due!.isAfter(card.due!), isTrue);
    });
  });

  group('the daily review limit', () {
    const limit = QueueSettings(maxReviewsPerDay: 10);

    test('stops due reviews once reached, counting earlier sessions', () {
      final s = Session(
        dueReviews(5),
        settings: limit,
        counts: {today: const DayCounts(reviews: 8)},
      );
      expect(s.answerNext().source, CardSource.dueReview);
      expect(s.answerNext().source, CardSource.dueReview);
      expect(s.next(), isA<DailyGoalReached>());
    });

    test('learning steps and new cards carry on', () {
      final learning = q(learningCard(itemId: 'learning', due: noon));
      final s = Session(
        [...dueReviews(3), learning, ...newCards(1)],
        settings: limit,
        counts: {today: const DayCounts(reviews: 10)},
      );
      final first = s.answerNext();
      expect(first.card.itemId, 'learning');
      final second = s.answerNext();
      expect(second.source, CardSource.newCard);
    });

    test('learning cards are shown early, then the goal is reached', () {
      final s = Session(
        [
          ...dueReviews(2),
          q(learningCard(itemId: 'waiting', due: noon.add(minutes(5)))),
        ],
        settings: limit,
        counts: {today: const DayCounts(reviews: 10)},
      );
      final early = s.answerNext(Rating.easy); // graduates
      expect(early.card.itemId, 'waiting');
      expect(early.source, CardSource.earlyLearningStep);
      expect(s.next(), isA<DailyGoalReached>());
    });

    test('no free practice once reached', () {
      final notDue = q(
        reviewCard(itemId: 'later', due: noon.add(const Duration(days: 3))),
      );
      final s = Session(
        [notDue],
        settings: limit,
        counts: {today: const DayCounts(reviews: 10)},
      );
      expect(s.next(), isA<DailyGoalReached>());
    });

    test('only answers to review cards count towards it', () {
      final s = Session(
        [
          ...newCards(2),
          q(learningCard(itemId: 'learning', due: noon)),
          ...dueReviews(1),
        ],
        settings: limit,
        counts: {today: const DayCounts(reviews: 9)},
      );
      // The learning step and new cards don't use up the last review.
      s.answerNext(); // learning step
      final review = s.answerNext();
      expect(review.source, CardSource.dueReview);
    });

    test('unlimited by default', () {
      final s = Session(
        dueReviews(3),
        counts: {today: const DayCounts(reviews: 5000)},
      );
      expect(s.show().source, CardSource.dueReview);
    });

    test('the due count shows at most what the limit leaves', () {
      final s = Session(
        dueReviews(6),
        settings: limit,
        counts: {today: const DayCounts(reviews: 7)},
      );
      expect(s.dueToday(), 3);
    });
  });

  group('exclusions', () {
    test('known cards are never shown', () {
      final known = q(reviewCard(itemId: 'known', due: noon, knownAt: noon));
      final knownNew = q(newCard(itemId: 'known new').withKnownAt(noon));
      final s = Session([known, knownNew]);
      expect(s.next(), isA<NoCardsAvailable>());
      expect(s.dueToday(), 0);
    });

    test('retired items are never shown', () {
      final s = Session([
        q(reviewCard(itemId: 'gone', due: noon), retired: true),
        q(newCard(itemId: 'gone new'), retired: true),
      ]);
      expect(s.next(), isA<NoCardsAvailable>());
    });

    test('Jamais pauses a category’s cards, reviews included', () {
      final s = Session(
        [
          q(
            reviewCard(itemId: 'paused', due: noon),
            categories: ['cat.a'],
          ),
          q(newCard(itemId: 'paused new'), categories: ['cat.a']),
        ],
        settings: const QueueSettings(
          categoryWeights: {'cat.a': CategoryWeight.jamais},
        ),
      );
      expect(s.next(), isA<NoCardsAvailable>());
      expect(s.dueToday(), 0);
    });

    test('a noun is paused only when all its categories are Jamais', () {
      final card = q(
        reviewCard(itemId: 'shared', due: noon),
        categories: ['cat.a', 'cat.b'],
      );
      final oneOff = Session(
        [card],
        settings: const QueueSettings(
          categoryWeights: {'cat.a': CategoryWeight.jamais},
        ),
      );
      expect(oneOff.show().card.itemId, 'shared');
      final allOff = Session(
        [card],
        settings: const QueueSettings(
          categoryWeights: {
            'cat.a': CategoryWeight.jamais,
            'cat.b': CategoryWeight.jamais,
          },
        ),
      );
      expect(allOff.next(), isA<NoCardsAvailable>());
    });

    test('back from Jamais, overdue cards are simply due', () {
      final overdue = q(
        reviewCard(
          itemId: 'overdue',
          due: noon.subtract(const Duration(days: 30)),
        ),
      );
      final s = Session(
        [overdue],
        settings: const QueueSettings(
          categoryWeights: {'cat.a': CategoryWeight.jamais},
        ),
      );
      expect(s.next(), isA<NoCardsAvailable>());
      s.queue.settings = const QueueSettings();
      expect(s.show().source, CardSource.dueReview);
    });

    test('a paused tense or verb group pauses its conjugation cards', () {
      DrillCard conj(String item, Tense tense) => reviewCard(
        itemId: item,
        due: noon,
        drill: DrillType.conjugation,
        tense: tense,
      );
      final cards = [
        q(conj('v.aller', Tense.imparfait), group: VerbGroup.irr),
        q(conj('v.parler', Tense.present), group: VerbGroup.er),
      ];
      final noImparfait = Session(
        cards,
        settings: const QueueSettings(
          enabledTenses: {Tense.present, Tense.passeCompose, Tense.futurSimple},
        ),
      );
      expect(noImparfait.answerNext().card.itemId, 'v.parler');
      expect(noImparfait.show().source, CardSource.freePractice);

      final noEr = Session(
        cards,
        settings: const QueueSettings(
          enabledGroups: {VerbGroup.ir, VerbGroup.re, VerbGroup.irr},
        ),
      );
      expect(noEr.answerNext().card.itemId, 'v.aller');
    });

    test('nothing to show at all', () {
      expect(Session(const []).next(), isA<NoCardsAvailable>());
      expect(Session(const []).queue.drill, isNull);
    });
  });

  group('clock and time zone', () {
    test('a time-zone change mid-session uses the new local day', () {
      // 05:00 on the 25th in Paris; the limit of 1 is used on the 25th.
      final s = Session(
        newCards(3),
        settings: const QueueSettings(newPerDay: 1),
        now: DateTime.utc(2026, 9, 25, 3),
        counts: {const StudyDay(2026, 9, 24): const DayCounts(newCards: 1)},
      );
      // Easy, so it graduates and no learning step is left pending.
      expect(s.answerNext(Rating.easy).source, CardSource.newCard);
      expect(s.show().source, isNot(CardSource.newCard));

      // The phone moves to New York: 23:00 on the 24th, whose limit was
      // already used there. The 25th's answers stay on the 25th.
      s.clock.offset = const Duration(hours: -4);
      expect(s.show().source, isNot(CardSource.newCard));

      // At 04:00 in New York the 25th starts, with the 25th's count as it was.
      s.clock.setNow(DateTime.utc(2026, 9, 25, 8));
      expect(s.show().source, isNot(CardSource.newCard));
      // And the 26th brings a fresh allowance.
      s.clock.setNow(DateTime.utc(2026, 9, 26, 8));
      expect(s.show().source, CardSource.newCard);
    });

    test('a daylight-saving change moves the day boundary with local time', () {
      // Paris leaves summer time overnight on 24–25 October 2026. A card
      // due at 02:30 UTC on the 25th is due 03:30 local winter time: still
      // part of the 24th's study day.
      final card = q(
        reviewCard(itemId: 'late', due: DateTime.utc(2026, 10, 25, 2, 30)),
      );
      final s = Session(
        [card],
        now: DateTime.utc(2026, 10, 24, 20),
        offset: const Duration(hours: 1), // after the change
      );
      expect(s.dueToday(), 1);
      expect(s.show().source, CardSource.dueReview);
    });

    test('the clock going backwards keeps working', () {
      final s = Session([...dueReviews(2), ...newCards(1)]);
      s.answerNext();
      s.clock.setNow(noon.subtract(const Duration(hours: 3)));
      final shown = s.answerNext();
      expect(shown, isA<ShowCard>());
      // Answers still save, and the next card still comes.
      expect(s.next(), isA<ShowCard>());
    });

    test('answers count towards the study day they were given on', () {
      final s = Session(
        newCards(3),
        settings: const QueueSettings(newPerDay: 1),
      );
      final shown = s.show();
      // Answered on yesterday's study day (the clock went back over 04:00).
      final yesterday = StudyDay.of(
        noon.subtract(const Duration(hours: 9)),
        paris,
      );
      s.queue.record(
        scheduler.review(shown.card, Rating.good, at: noon, day: yesterday),
      );
      // Today's allowance is untouched.
      expect(s.show().source, CardSource.newCard);
    });
  });

  group('overrides and updates', () {
    test('a regrade changes the card but not the counts', () {
      final s = Session(
        newCards(3),
        settings: const QueueSettings(newPerDay: 1),
      );
      final shown = s.show();
      final outcome = scheduler.review(
        shown.card,
        Rating.good,
        at: noon,
        day: today,
      );
      s.queue.record(outcome);
      final easy = scheduler.regrade(outcome, Rating.easy);
      s.queue.recordRegrade(easy);
      // Still one new card used; the card is now in review, not due today.
      final next = s.show();
      expect(next.source, CardSource.freePractice);
      expect(next.card.state, CardState.review);
    });

    test('updating a card the queue does not have is ignored', () {
      final s = Session(newCards(1));
      s.queue.update(newCard(itemId: 'stranger'));
      expect(s.show().card.itemId, 'n0');
    });

    test('knows its drill', () {
      expect(Session(newCards(1)).queue.drill, DrillType.vocabulary);
    });
  });

  group('the due count for Accueil', () {
    test('counts learning steps and reviews due today, not new cards', () {
      final s = Session([
        ...dueReviews(2),
        q(learningCard(itemId: 'step', due: noon.add(minutes(10)))),
        q(
          reviewCard(
            itemId: 'tomorrow',
            due: noon.add(const Duration(days: 1)),
          ),
        ),
        ...newCards(4),
      ]);
      expect(s.dueToday(), 3);
    });
  });
}

Duration minutes(int n) => Duration(minutes: n);
