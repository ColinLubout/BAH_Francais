// The nouns here are the spec's examples (fourchette, école) with their real
// gender and elision; the sentences are made-up tokens around them.

import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_clock.dart';
import '../helpers.dart';

const fourchette = VocabularyItem(
  nounId: 'n.fourchette',
  answer: VocabularyAnswer(word: 'fourchette', gender: Gender.feminine),
  definition: 'def fourchette',
  examples: [ExampleSentence('zz fourchette zz', highlight: Span(3, 13))],
);
const ecole = VocabularyItem(
  nounId: 'n.ecole',
  answer: VocabularyAnswer(
    word: 'école',
    gender: Gender.feminine,
    elides: true,
  ),
  imageIds: ['i.ecole-1', 'i.ecole-2'],
);

/// A store in memory that records what the session saves.
class FakeStore implements DrillStore {
  FakeStore({
    required this.cards,
    this.items = const {},
    this.setup = const DrillQueueSetup(),
    this.counts = const DayCounts(),
  });

  final List<DrillCard> cards;
  final Map<String, VocabularyItem> items;
  final DrillQueueSetup setup;
  final DayCounts counts;

  final sessionsStarted = <DateTime>[];
  final answers = <Answer>[];
  final replaced = <(int, Answer)>[];
  final knownCalls = <(List<int>, DateTime?)>[];

  @override
  Future<List<QueueCard>> queueCards(DrillType drill) async => [
    for (final c in cards)
      if (c.drill == drill) QueueCard(card: c),
  ];

  @override
  Future<DrillQueueSetup> queueSetup(DrillType drill) async => setup;

  @override
  Future<DayCounts> dayCounts(DrillType drill, StudyDay day) async => counts;

  @override
  Future<int> startSession({
    required DrillType? drill,
    required DateTime at,
  }) async {
    sessionsStarted.add(at);
    return 7;
  }

  @override
  Future<int> recordAnswer(Answer answer) async {
    answers.add(answer);
    return 100 + answers.length;
  }

  @override
  Future<void> replaceAnswer(int logId, Answer answer) async =>
      replaced.add((logId, answer));

  @override
  Future<List<DrillCard>> cardsOfItem(String itemId) async => [
    for (final c in cards)
      if (c.itemId == itemId) c,
  ];

  @override
  Future<void> setKnownAt(Iterable<int> cardIds, DateTime? at) async =>
      knownCalls.add((cardIds.toList(), at));

  @override
  Future<VocabularyItem> vocabularyItem(String nounId) async => items[nounId]!;
}

/// A session over [store], at noon in Paris.
Future<(DrillSession, FakeClock)> open(
  FakeStore store, {
  double random = 0,
  bool articleMandatory = false,
}) async {
  final clock = FakeClock(noon, offset: paris);
  final session = await DrillSession.open(
    drill: DrillType.vocabulary,
    store: store,
    clock: clock,
    scheduler: DrillScheduler(random: () => 0.5),
    random: () => random,
    articleMandatory: articleMandatory,
  );
  return (session, clock);
}

FakeStore oneNoun({VocabularyItem item = fourchette}) => FakeStore(
  cards: [newCard(itemId: item.nounId, id: 1)],
  items: {item.nounId: item},
);

void main() {
  test('only the Vocabulaire drill exists so far', () {
    expect(
      DrillSession.open(
        drill: DrillType.gender,
        store: oneNoun(),
        clock: FakeClock(noon),
        scheduler: DrillScheduler(),
        random: () => 0,
      ),
      throwsUnsupportedError,
    );
  });

  group('the cards', () {
    test('a noun with no image is asked by its definition', () async {
      final (session, _) = await open(oneNoun());
      final view = await session.next();
      expect(view, isA<CardQuestion>());
      final card = (view as CardQuestion).card;
      expect(card.prompt, const DefinitionPrompt('def fourchette'));
      expect(card.card.id, 1);
      expect(card.typings, contains('fourchette'));
      expect(view.startsFreePractice, isFalse);
    });

    test('a noun with images is asked by one, chosen at random', () async {
      final (first, _) = await open(oneNoun(item: ecole));
      expect(
        ((await first.next()) as CardQuestion).card.prompt,
        const ImagePrompt('i.ecole-1'),
      );
      final (last, _) = await open(oneNoun(item: ecole), random: 0.99);
      expect(
        ((await last.next()) as CardQuestion).card.prompt,
        const ImagePrompt('i.ecole-2'),
      );
    });

    test('with Article obligatoire, the answer needs one', () async {
      final (session, _) = await open(oneNoun(), articleMandatory: true);
      final card = ((await session.next()) as CardQuestion).card;
      expect(card.typings, isNot(contains('fourchette')));
      final view = await session.submit('fourchette') as CardFeedback;
      expect(view.grade.rating, Rating.hard);
      expect(view.grade.errorType, ErrorType.article);
    });

    test('no card at all', () async {
      final (session, _) = await open(FakeStore(cards: const []));
      expect(await session.next(), isA<NoCards>());
      expect(session.view, isA<NoCards>());
    });

    test('the review limit reached, nothing else left: the goal', () async {
      final store = FakeStore(
        cards: [reviewCard(due: noon, itemId: 'n.fourchette', id: 1)],
        items: const {'n.fourchette': fourchette},
        setup: const DrillQueueSetup(
          settings: QueueSettings(maxReviewsPerDay: 10),
        ),
        counts: const DayCounts(reviews: 10),
      );
      final (session, _) = await open(store);
      expect(await session.next(), isA<GoalReached>());
    });

    test('nothing due and no new card: free practice, flagged once', () async {
      final store = FakeStore(
        cards: [
          reviewCard(
            due: noon.add(const Duration(days: 3)),
            itemId: 'n.fourchette',
            id: 1,
          ),
        ],
        items: const {'n.fourchette': fourchette},
      );
      final (session, _) = await open(store);
      final view = await session.next() as CardQuestion;
      expect(view.startsFreePractice, isTrue);
    });
  });

  group('answering', () {
    test('an exact answer is Correct, and saved at once', () async {
      final store = oneNoun();
      final (session, clock) = await open(store);
      await session.next();
      clock.advance(const Duration(seconds: 4));
      final view = await session.submit('fourchette') as CardFeedback;

      expect(view.grade.rating, Rating.good);
      expect(view.example, fourchette.examples.single);
      expect(view.offersTooEasy, isTrue);
      expect(view.offersTypo, isFalse);

      // The session row is written with the first answer, dated its start.
      expect(store.sessionsStarted, [noon]);
      final answer = store.answers.single;
      expect(answer.sessionId, 7);
      expect(answer.typed, 'fourchette');
      expect(answer.responseTime, const Duration(seconds: 4));
      expect(answer.errorType, ErrorType.none);
      expect(answer.outcome.rating, Rating.good);
      expect(answer.outcome.reviewedAt, clock.nowUtc());
      expect(answer.outcome.studyDay, today);
    });

    test('a letter that went red or orange caps it at Hard', () async {
      final (session, _) = await open(oneNoun());
      await session.next();
      final view = await session.submit('fourchette', capsGrade: true);
      expect((view as CardFeedback).grade.rating, Rating.hard);
    });

    test('a wrong answer is Again, and offers Faute de frappe', () async {
      final (session, _) = await open(oneNoun());
      await session.next();
      final view = await session.submit('zz') as CardFeedback;
      expect(view.grade.rating, Rating.again);
      expect(view.offersTypo, isTrue);
      expect(view.offersTooEasy, isFalse);
    });

    test('Je ne sais pas is Again, shows the answer, offers nothing', () async {
      final store = oneNoun();
      final (session, _) = await open(store);
      await session.next();
      final view = await session.giveUp() as CardFeedback;
      expect(view.grade.rating, Rating.again);
      expect(view.grade.errorType, ErrorType.gaveUp);
      expect(view.grade.answer, 'fourchette');
      expect(view.offersTypo, isFalse);
      expect(store.answers.single.typed, isNull);
    });

    test('the session row is written once', () async {
      final store = FakeStore(
        cards: [
          newCard(itemId: 'n.fourchette', id: 1),
          newCard(itemId: 'n.ecole', id: 2),
        ],
        items: const {'n.fourchette': fourchette, 'n.ecole': ecole},
      );
      final (session, _) = await open(store);
      await session.next();
      await session.giveUp();
      await session.next();
      await session.giveUp();
      expect(store.sessionsStarted, hasLength(1));
      expect(store.answers, hasLength(2));
    });

    test('answering when no card waits is a mistake', () async {
      final (session, _) = await open(oneNoun());
      expect(() => session.submit('x'), throwsStateError);
      expect(session.giveUp, throwsStateError);
    });
  });

  group('the overrides', () {
    test('Faute de frappe makes it Hard, saved over the same row', () async {
      final store = oneNoun();
      final (session, _) = await open(store);
      await session.next();
      await session.submit('zz');
      expect(session.summary.correct, 0);

      final view = await session.override() as CardFeedback;
      expect(view.grade.rating, Rating.hard);
      expect(view.grade.errorType, ErrorType.typoOverride);
      expect(view.overridden, isTrue);
      expect(view.offersTypo, isFalse);

      final (logId, answer) = store.replaced.single;
      expect(logId, 101);
      expect(answer.outcome.rating, Rating.hard);
      expect(answer.typed, 'zz');
      expect(session.summary.correct, 1);
      expect(session.override, throwsStateError);
    });

    test('Trop facile makes it Easy', () async {
      final store = oneNoun();
      final (session, _) = await open(store);
      await session.next();
      await session.submit('fourchette');
      final view = await session.override() as CardFeedback;
      expect(view.grade.rating, Rating.easy);
      expect(store.replaced.single.$2.outcome.rating, Rating.easy);
      expect(session.summary.correct, 1);
    });

    test(
      'nothing to override before an answer, or after Je ne sais pas',
      () async {
        final (session, _) = await open(oneNoun());
        await session.next();
        expect(session.override, throwsStateError);
        await session.giveUp();
        expect(session.override, throwsStateError);
      },
    );
  });

  group('Je le connais', () {
    final genre = newCard(
      itemId: 'n.fourchette',
      drill: DrillType.gender,
      id: 3,
    );

    FakeStore twoNouns() => FakeStore(
      cards: [
        newCard(itemId: 'n.fourchette', id: 1),
        newCard(itemId: 'n.ecole', id: 2),
        genre,
      ],
      items: const {'n.fourchette': fourchette, 'n.ecole': ecole},
    );

    test("marks the noun's cards in every drill, and moves on", () async {
      final store = twoNouns();
      final (session, clock) = await open(store);
      final first = (await session.next() as CardQuestion).card;
      final (mark, view) = await session.markKnown();

      final (ids, at) = store.knownCalls.single;
      expect(
        ids,
        unorderedEquals([
          for (final c in store.cards)
            if (c.itemId == first.item.nounId) c.id,
        ]),
      );
      expect(at, clock.nowUtc());
      expect(mark.cards, hasLength(ids.length));
      expect(store.answers, isEmpty, reason: 'no grade, no review-log row');
      final next = (view as CardQuestion).card;
      expect(next.item.nounId, isNot(first.item.nounId));
    });

    test('a marked card is not served again; Annuler brings it back', () async {
      final store = twoNouns();
      final (session, _) = await open(store);
      final first = (await session.next() as CardQuestion).card;
      final (mark, _) = await session.markKnown();
      await session.giveUp();
      // Only the other noun is left before the marked one is undone.
      final afterMark = await session.next();
      expect(
        afterMark is CardQuestion &&
            afterMark.card.item.nounId == first.item.nounId,
        isFalse,
      );

      await session.undoKnown(mark);
      expect(store.knownCalls.last.$2, isNull);
      expect(
        store.knownCalls.last.$1,
        unorderedEquals(store.knownCalls.first.$1),
      );
    });

    test('works from the feedback panel too', () async {
      final store = twoNouns();
      final (session, _) = await open(store);
      await session.next();
      await session.giveUp();
      await session.markKnown();
      expect(store.knownCalls, hasLength(1));
    });

    test('nothing to mark when no card is shown', () async {
      final (session, _) = await open(FakeStore(cards: const []));
      await session.next();
      expect(session.markKnown, throwsStateError);
    });
  });

  group('the summary', () {
    test('cards answered, % correct and the time to the last answer', () async {
      final store = FakeStore(
        cards: [
          newCard(itemId: 'n.fourchette', id: 1),
          newCard(itemId: 'n.ecole', id: 2),
        ],
        items: const {'n.fourchette': fourchette, 'n.ecole': ecole},
      );
      final (session, clock) = await open(store);
      expect(session.summary.isEmpty, isTrue);
      expect(session.summary.percentCorrect, 0);

      final first = (await session.next() as CardQuestion).card;
      clock.advance(const Duration(seconds: 30));
      await session.submit(first.item.answer.word);
      await session.next();
      clock.advance(const Duration(seconds: 50));
      await session.submit('zz');
      clock.advance(const Duration(minutes: 5));

      final summary = session.summary;
      expect(summary.isEmpty, isFalse);
      expect(summary.answered, 2);
      expect(summary.correct, 1);
      expect(summary.percentCorrect, 50);
      expect(summary.duration, const Duration(seconds: 80));
    });

    test('% correct is rounded', () {
      const summary = SessionSummary(
        answered: 3,
        correct: 2,
        duration: Duration.zero,
      );
      expect(summary.percentCorrect, 67);
    });
  });

  test('leaving the app for over 30 minutes closes the session', () {
    expect(DrillSession.closesAfter(const Duration(minutes: 30)), isFalse);
    expect(
      DrillSession.closesAfter(const Duration(minutes: 30, seconds: 1)),
      isTrue,
    );
  });

  group('the item', () {
    test('an example sentence has the noun in bold', () {
      expect(
        ExampleSentence.of('zz fourchette zz', 'fourchette'),
        const ExampleSentence('zz fourchette zz', highlight: Span(3, 13)),
      );
      expect(ExampleSentence.of('zz', 'fourchette').highlight, isNull);
    });

    test('a noun with neither image nor definition cannot be asked', () {
      const bare = VocabularyItem(
        nounId: 'n.x',
        answer: VocabularyAnswer(word: 'x', gender: Gender.masculine),
      );
      expect(() => VocabularyPrompt.of(bare, () => 0), throwsStateError);
    });
  });
}
