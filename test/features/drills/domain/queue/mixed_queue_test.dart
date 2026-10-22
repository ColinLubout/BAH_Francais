// The mixed session's order (decision 80), over each drill's own queue.

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

QueueCard q(DrillCard card) => QueueCard(
  card: card,
  categoryIds: const ['cat.a'],
  level: Level.debutant,
  rank: 1,
);

SessionQueue queueOf(
  List<DrillCard> cards, {
  QueueSettings settings = const QueueSettings(),
  DayCounts counts = const DayCounts(),
}) => SessionQueue(
  cards: [for (final c in cards) q(c)],
  settings: settings,
  countsOn: (_) => counts,
  scheduler: scheduler,
  random: () => 0,
);

/// A mixed queue over the three drills, at noon in Paris.
(MixedQueue, FakeClock) mixed({
  SessionQueue? gender,
  SessionQueue? vocabulary,
  SessionQueue? conjugation,
}) => (
  MixedQueue({
    DrillType.gender: gender ?? queueOf(const []),
    DrillType.vocabulary: vocabulary ?? queueOf(const []),
    DrillType.conjugation: conjugation ?? queueOf(const []),
  }),
  FakeClock(noon, offset: paris),
);

DrillCard due(String itemId, DrillType drill, {double stability = 10}) =>
    reviewCard(due: noon, itemId: itemId, drill: drill, stability: stability);

ShowCard show(NextStep step) => step as ShowCard;

void main() {
  test('a learning step in one drill comes before a review in another', () {
    final (queue, clock) = mixed(
      gender: queueOf([due('n.a', DrillType.gender)]),
      vocabulary: queueOf([
        learningCard(
          due: noon.subtract(const Duration(minutes: 1)),
          itemId: 'n.b',
        ),
      ]),
    );
    final step = show(queue.next(clock));
    expect(step.card.drill, DrillType.vocabulary);
    expect(step.source, CardSource.learningStep);
  });

  test('equally urgent cards: the drills take turns', () {
    final (queue, clock) = mixed(
      gender: queueOf([
        due('n.a', DrillType.gender),
        due('n.b', DrillType.gender),
      ]),
      vocabulary: queueOf([
        due('n.c', DrillType.vocabulary),
        due('n.d', DrillType.vocabulary),
      ]),
    );
    final drills = [for (var i = 0; i < 4; i++) show(queue.next(clock))];
    expect(
      [for (final s in drills) s.card.drill],
      [
        DrillType.gender,
        DrillType.vocabulary,
        DrillType.gender,
        DrillType.vocabulary,
      ],
    );
  });

  test('a new card on its turn ranks with due reviews', () {
    final (queue, clock) = mixed(
      gender: queueOf([due('n.a', DrillType.gender)]),
      vocabulary: queueOf([newCard(itemId: 'n.b')]),
    );
    expect(show(queue.next(clock)).card.drill, DrillType.gender);
    final second = show(queue.next(clock));
    expect(second.card.drill, DrillType.vocabulary);
    expect(second.source, CardSource.newCard);
  });

  test('a card for the word just shown waits a turn', () {
    final (queue, clock) = mixed(
      gender: queueOf([due('n.x', DrillType.gender)]),
      vocabulary: queueOf([due('n.x', DrillType.vocabulary)]),
      conjugation: queueOf([due('v.aller', DrillType.conjugation)]),
    );
    expect(show(queue.next(clock)).card.itemId, 'n.x');
    // Vocabulaire's turn, but its card is the same word: Conjugaison first.
    expect(show(queue.next(clock)).card.drill, DrillType.conjugation);
    final third = show(queue.next(clock));
    expect(third.card.drill, DrillType.vocabulary);
    expect(third.card.itemId, 'n.x');
  });

  test('unless nothing else is left', () {
    final (queue, clock) = mixed(
      gender: queueOf([due('n.x', DrillType.gender)]),
      vocabulary: queueOf([due('n.x', DrillType.vocabulary)]),
    );
    expect(show(queue.next(clock)).card.drill, DrillType.gender);
    expect(show(queue.next(clock)).card.drill, DrillType.vocabulary);
  });

  test('each drill keeps its own limits', () {
    final (queue, clock) = mixed(
      gender: queueOf(
        [newCard(itemId: 'n.a', drill: DrillType.gender)],
        settings: const QueueSettings(newPerDay: 1),
        counts: const DayCounts(newCards: 1),
      ),
      vocabulary: queueOf([newCard(itemId: 'n.b')]),
    );
    final step = show(queue.next(clock));
    expect(step.card.drill, DrillType.vocabulary);
  });

  test('answers count against their own drill', () {
    final genderNew = newCard(itemId: 'n.a', drill: DrillType.gender);
    final (queue, clock) = mixed(
      gender: queueOf([
        genderNew,
        newCard(itemId: 'n.c', drill: DrillType.gender),
      ], settings: const QueueSettings(newPerDay: 1)),
      vocabulary: queueOf([newCard(itemId: 'n.b')]),
    );
    final first = show(queue.next(clock));
    expect(first.card.drill, DrillType.gender);
    queue.record(
      scheduler.review(first.card, Rating.good, at: noon, day: today),
    );
    // Gender's one new card for the day is used: Vocabulaire's comes.
    final second = show(queue.next(clock));
    expect(second.card.drill, DrillType.vocabulary);

    // Marked known there, it leaves the session; Gender's learning card,
    // before its step, is all that is left.
    queue.update(second.card.withKnownAt(noon));
    final third = show(queue.next(clock));
    expect(third.card.drill, DrillType.gender);
    expect(third.source, CardSource.freePractice);

    final regraded = scheduler.regrade(
      scheduler.review(third.card, Rating.again, at: noon, day: today),
      Rating.hard,
    );
    queue.recordRegrade(regraded);
    expect(show(queue.next(clock)).card.id, third.card.id);
  });

  test('a drill at its daily goal drops out; when all have, the goal', () {
    final atGoal = queueOf(
      [due('n.a', DrillType.gender)],
      settings: const QueueSettings(maxReviewsPerDay: 10),
      counts: const DayCounts(reviews: 10),
    );
    final (withOther, clock) = mixed(
      gender: atGoal,
      vocabulary: queueOf([due('n.b', DrillType.vocabulary)]),
    );
    expect(show(withOther.next(clock)).card.drill, DrillType.vocabulary);

    final (alone, _) = mixed(gender: atGoal);
    expect(alone.next(clock), isA<DailyGoalReached>());
    final (empty, _) = mixed();
    expect(empty.next(clock), isA<NoCardsAvailable>());
  });

  test('Tout est à jour once, when the session first moves into practice', () {
    final later = noon.add(const Duration(days: 3));
    final (queue, clock) = mixed(
      gender: queueOf([
        reviewCard(due: later, itemId: 'n.a', drill: DrillType.gender),
      ]),
      vocabulary: queueOf([reviewCard(due: later, itemId: 'n.b')]),
    );
    final first = show(queue.next(clock));
    expect(first.source, CardSource.freePractice);
    expect(first.startsFreePractice, isTrue);
    expect(show(queue.next(clock)).startsFreePractice, isFalse);
  });

  test('peeking shows nothing; a single drill still flags practice once', () {
    final later = noon.add(const Duration(days: 3));
    final single = queueOf([
      reviewCard(due: later, itemId: 'n.a'),
      reviewCard(due: later, itemId: 'n.b'),
    ]);
    final clock = FakeClock(noon, offset: paris);
    expect(show(single.peek(clock)).startsFreePractice, isTrue);
    expect(show(single.peek(clock)).startsFreePractice, isTrue);
    final first = show(single.next(clock));
    expect(first.startsFreePractice, isTrue);
    final second = show(single.next(clock));
    expect(second.startsFreePractice, isFalse);
    expect(second.card.id, isNot(first.card.id));
  });
}
