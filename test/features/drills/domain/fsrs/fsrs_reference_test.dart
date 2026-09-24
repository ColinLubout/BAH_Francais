// py-fsrs 6.3.2's own tests (tests/test_basic.py), run against the Dart port.
// Each test keeps the name of the Python test it comes from. Tests of parts
// the port leaves out (serialisation, rescheduling, the optimizer) are
// skipped.

import 'package:bah_francais/features/drills/domain/fsrs/fsrs.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/python_random.dart';

final t0 = DateTime.utc(2022, 11, 29, 12, 30);

FsrsCard newCard([DateTime? due]) => FsrsCard(due: due ?? t0);

/// Whole days between [from] and [to], as Python's `timedelta.days`.
int days(DateTime from, DateTime to) =>
    (to.difference(from).inMicroseconds / Duration.microsecondsPerDay).floor();

/// `round(x)` in Python, for the tests' own assertions.
int roundPy(double x) => pythonRound(x);

const List<Rating> testRatings1 = [
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.again,
  Rating.again,
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.good,
  Rating.good,
];

void main() {
  group('PythonRandom', () {
    test('matches random.seed(42) in CPython', () {
      final random = PythonRandom(42);
      expect(random.random(), 0.6394267984578837);
      expect(random.random(), 0.025010755222666936);
      expect(random.random(), 0.27502931836911926);
    });
  });

  group('pythonRound', () {
    test('rounds halves to even, like Python', () {
      expect(pythonRound(0.5), 0);
      expect(pythonRound(1.5), 2);
      expect(pythonRound(2.5), 2);
      expect(pythonRound(3.5), 4);
      expect(pythonRound(-0.5), 0);
      expect(pythonRound(-1.5), -2);
      expect(pythonRound(2.4999), 2);
      expect(pythonRound(2.5001), 3);
    });
  });

  test('test_review_card', () {
    final scheduler = FsrsScheduler(enableFuzzing: false);
    var card = newCard();
    var reviewTime = t0;
    final intervals = <int>[];
    for (final rating in testRatings1) {
      card = scheduler.review(card, rating, reviewTime);
      intervals.add(days(card.lastReview!, card.due));
      reviewTime = card.due;
    }
    expect(intervals, [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21]);
  });

  test('test_repeated_correct_reviews', () {
    final scheduler = FsrsScheduler(enableFuzzing: false);
    var card = newCard();
    for (var i = 0; i < 10; i++) {
      card = scheduler.review(
        card,
        Rating.easy,
        t0.add(Duration(microseconds: i)),
      );
    }
    expect(card.difficulty, 1.0);
  });

  test('test_memo_state', () {
    final scheduler = FsrsScheduler();
    const ratings = [
      Rating.again,
      Rating.good,
      Rating.good,
      Rating.good,
      Rating.good,
      Rating.good,
    ];
    const intervals = [0, 0, 1, 3, 8, 21];
    var card = newCard();
    var reviewTime = t0;
    for (var i = 0; i < ratings.length; i++) {
      reviewTime = reviewTime.add(Duration(days: intervals[i]));
      card = scheduler.review(card, ratings[i], reviewTime);
    }
    expect(card.stability, closeTo(53.62691, 1e-4));
    expect(card.difficulty, closeTo(6.3574867, 1e-4));
  });

  test('test_custom_scheduler_args', () {
    final scheduler = FsrsScheduler(enableFuzzing: false);
    var card = newCard();
    var now = t0;
    final intervals = <int>[];
    for (final rating in testRatings1) {
      card = scheduler.review(card, rating, now);
      intervals.add(days(card.lastReview!, card.due));
      now = card.due;
    }
    expect(intervals, [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21]);

    const parameters2 = [
      0.1456,
      0.4186,
      1.1104,
      4.1315,
      5.2417,
      1.3098,
      0.8975,
      0.0010,
      1.5674,
      0.0567,
      0.9661,
      2.0275,
      0.1592,
      0.2446,
      1.5071,
      0.2272,
      2.8755,
      1.234,
      0.56789,
      0.1437,
      0.2,
    ];
    final scheduler2 = FsrsScheduler(
      parameters: parameters2,
      desiredRetention: 0.85,
      maximumInterval: 3650,
    );
    expect(scheduler2.parameters, parameters2);
    expect(scheduler2.desiredRetention, 0.85);
    expect(scheduler2.maximumInterval, 3650);
  });

  test('test_retrievability', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    expect(card.state, FsrsState.learning);
    expect(scheduler.retrievability(card, t0), 0);

    card = scheduler.review(card, Rating.good, t0);
    expect(card.state, FsrsState.learning);
    expect(scheduler.retrievability(card, t0), inInclusiveRange(0, 1));

    card = scheduler.review(card, Rating.good, t0);
    expect(card.state, FsrsState.review);
    expect(scheduler.retrievability(card, t0), inInclusiveRange(0, 1));

    card = scheduler.review(card, Rating.again, t0);
    expect(card.state, FsrsState.relearning);
    expect(scheduler.retrievability(card, t0), inInclusiveRange(0, 1));
  });

  test('test_good_learning_steps', () {
    final scheduler = FsrsScheduler();
    final createdAt = t0;
    var card = newCard();
    expect(card.state, FsrsState.learning);
    expect(card.step, 0);

    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.learning);
    expect(card.step, 1);
    // Due in about 10 minutes.
    expect(roundPy(card.due.difference(createdAt).inSeconds / 100), 6);

    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);
    // Due in over a day.
    expect(
      roundPy(card.due.difference(createdAt).inSeconds / 3600),
      greaterThanOrEqualTo(24),
    );
  });

  test('test_again_learning_steps', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.learning);
    expect(card.step, 0);
    // Due in about a minute.
    expect(roundPy(card.due.difference(t0).inSeconds / 10), 6);
  });

  test('test_hard_learning_steps', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    card = scheduler.review(card, Rating.hard, card.due);
    expect(card.state, FsrsState.learning);
    expect(card.step, 0);
    // Due in about 5.5 minutes.
    expect(roundPy(card.due.difference(t0).inSeconds / 10), 33);
  });

  test('test_easy_learning_steps', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    card = scheduler.review(card, Rating.easy, card.due);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);
    expect(
      roundPy(card.due.difference(t0).inSeconds / 86400),
      greaterThanOrEqualTo(1),
    );
  });

  test('test_review_state', () {
    final scheduler = FsrsScheduler(enableFuzzing: false);
    var card = newCard();
    card = scheduler.review(card, Rating.good, card.due);
    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);

    var prevDue = card.due;
    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.review);
    expect(
      roundPy(card.due.difference(prevDue).inSeconds / 3600),
      greaterThanOrEqualTo(24),
    );

    prevDue = card.due;
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    expect(roundPy(card.due.difference(prevDue).inSeconds / 60), 10);
  });

  test('test_relearning', () {
    final scheduler = FsrsScheduler(enableFuzzing: false);
    var card = newCard();
    card = scheduler.review(card, Rating.good, card.due);
    card = scheduler.review(card, Rating.good, card.due);
    card = scheduler.review(card, Rating.good, card.due);

    var prevDue = card.due;
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);
    expect(roundPy(card.due.difference(prevDue).inSeconds / 60), 10);

    prevDue = card.due;
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);
    expect(roundPy(card.due.difference(prevDue).inSeconds / 60), 10);

    prevDue = card.due;
    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);
    expect(
      roundPy(card.due.difference(prevDue).inSeconds / 3600),
      greaterThanOrEqualTo(24),
    );
  });

  test('test_fuzz', () {
    int thirdInterval(int seed) {
      final random = PythonRandom(seed);
      final scheduler = FsrsScheduler(random: random.random);
      var card = newCard();
      card = scheduler.review(card, Rating.good, t0);
      card = scheduler.review(card, Rating.good, card.due);
      final prevDue = card.due;
      card = scheduler.review(card, Rating.good, card.due);
      return days(prevDue, card.due);
    }

    expect(thirdInterval(42), 12);
    expect(thirdInterval(12345), 11);
  });

  test('test_no_learning_steps', () {
    final scheduler = FsrsScheduler(learningSteps: const []);
    expect(scheduler.learningSteps, isEmpty);
    final card = scheduler.review(newCard(), Rating.again, t0);
    expect(card.state, FsrsState.review);
    expect(days(card.lastReview!, card.due), greaterThanOrEqualTo(1));
  });

  test('test_no_relearning_steps', () {
    final scheduler = FsrsScheduler(relearningSteps: const []);
    expect(scheduler.relearningSteps, isEmpty);
    var card = scheduler.review(newCard(), Rating.good, t0);
    expect(card.state, FsrsState.learning);
    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.review);
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.review);
    expect(days(card.lastReview!, card.due), greaterThanOrEqualTo(1));
  });

  test('test_one_card_multiple_schedulers', () {
    final twoLearning = FsrsScheduler();
    final oneLearning = FsrsScheduler(
      learningSteps: const [Duration(minutes: 1)],
    );
    final noLearning = FsrsScheduler(learningSteps: const []);
    final twoRelearning = FsrsScheduler(
      relearningSteps: const [Duration(minutes: 1), Duration(minutes: 10)],
    );
    final oneRelearning = FsrsScheduler(
      relearningSteps: const [Duration(minutes: 1)],
    );
    final noRelearning = FsrsScheduler(relearningSteps: const []);

    var card = newCard();
    card = twoLearning.review(card, Rating.good, t0);
    expect(card.state, FsrsState.learning);
    expect(card.step, 1);

    card = oneLearning.review(card, Rating.again, t0);
    expect(card.state, FsrsState.learning);
    expect(card.step, 0);

    card = noLearning.review(card, Rating.hard, t0);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);

    card = twoRelearning.review(card, Rating.again, t0);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);

    card = twoRelearning.review(card, Rating.good, t0);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 1);

    card = oneRelearning.review(card, Rating.again, t0);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);

    card = noRelearning.review(card, Rating.hard, t0);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);
  });

  test('a card left at a step the scheduler no longer has graduates', () {
    // The edge case the py-fsrs comments describe: scheduled with more steps
    // than the current scheduler has.
    final oneLearning = FsrsScheduler(
      learningSteps: const [Duration(minutes: 1)],
    );
    final oneRelearning = FsrsScheduler(
      relearningSteps: const [Duration(minutes: 1)],
    );
    final learning = oneLearning.review(
      FsrsCard(due: t0, step: 1, stability: 2, difficulty: 5, lastReview: t0),
      Rating.good,
      t0.add(const Duration(minutes: 10)),
    );
    expect(learning.state, FsrsState.review);
    final relearning = oneRelearning.review(
      FsrsCard(
        due: t0,
        state: FsrsState.relearning,
        step: 1,
        stability: 2,
        difficulty: 5,
        lastReview: t0,
      ),
      Rating.good,
      t0.add(const Duration(minutes: 10)),
    );
    expect(relearning.state, FsrsState.review);
  });

  test('test_maximum_interval', () {
    final scheduler = FsrsScheduler(maximumInterval: 100);
    var card = newCard();
    for (final rating in [Rating.easy, Rating.good, Rating.easy, Rating.good]) {
      card = scheduler.review(card, rating, card.due);
      expect(days(card.lastReview!, card.due), lessThanOrEqualTo(100));
    }
  });

  test('test_stability_lower_bound', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    for (var i = 0; i < 1000; i++) {
      card = scheduler.review(
        card,
        Rating.again,
        card.due.add(const Duration(days: 1)),
      );
      expect(card.stability, greaterThanOrEqualTo(stabilityMin));
    }
  });

  test('test_same_day_hard_review_does_not_decrease_stability', () {
    final scheduler = FsrsScheduler(learningSteps: const []);
    final reviewTime = DateTime.utc(2026);
    var card = scheduler.review(newCard(reviewTime), Rating.good, reviewTime);
    final previousStability = card.stability;
    card = scheduler.review(
      card,
      Rating.hard,
      reviewTime.add(const Duration(minutes: 1)),
    );
    expect(card.stability, previousStability);
  });

  test('test_scheduler_parameter_validation', () {
    expect(FsrsScheduler.new, returnsNormally);

    List<double> modified(void Function(List<double>) change) =>
        [...defaultParameters]..let(change);

    expect(
      () => FsrsScheduler(parameters: modified((p) => p[6] = 100)),
      throwsArgumentError,
    );
    expect(
      () => FsrsScheduler(parameters: modified((p) => p[10] = -42)),
      throwsArgumentError,
    );
    expect(
      () => FsrsScheduler(
        parameters: modified((p) {
          p[0] = 0;
          p[3] = 101;
        }),
      ),
      throwsArgumentError,
    );
    expect(() => FsrsScheduler(parameters: const []), throwsArgumentError);
    expect(
      () => FsrsScheduler(
        parameters: defaultParameters.sublist(0, defaultParameters.length - 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => FsrsScheduler(parameters: [...defaultParameters, 1, 2, 3]),
      throwsArgumentError,
    );
  });

  test('test_learning_card_rate_hard_one_learning_step', () {
    const firstStep = Duration(minutes: 10);
    final scheduler = FsrsScheduler(learningSteps: const [firstStep]);
    var card = newCard();
    final initialDue = card.due;
    card = scheduler.review(card, Rating.hard, card.due);
    expect(card.state, FsrsState.learning);
    final expected = firstStep * 1.5;
    expect(
      (card.due.difference(initialDue) - expected).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );
  });

  test('test_learning_card_rate_hard_second_learning_step', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.learning);
    expect(card.step, 1);
    final dueAfterFirst = card.due;
    card = scheduler.review(card, Rating.hard, dueAfterFirst);
    expect(card.state, FsrsState.learning);
    expect(card.step, 1);
    expect(
      (card.due.difference(dueAfterFirst) - const Duration(minutes: 10)).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );
  });

  test('test_long_term_stability_learning_state', () {
    final scheduler = FsrsScheduler();
    var card = newCard();
    card = scheduler.review(card, Rating.easy, card.due);
    expect(card.state, FsrsState.review);
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    card = scheduler.review(
      card,
      Rating.good,
      card.due.add(const Duration(days: 1)),
    );
    expect(card.state, FsrsState.review);
  });

  test('a learning card reviewed a day or more later', () {
    // Covers the learning-state branch that py-fsrs reaches with
    // non-same-day reviews of a learning card.
    final scheduler = FsrsScheduler();
    var card = scheduler.review(newCard(), Rating.good, t0);
    expect(card.state, FsrsState.learning);
    final stabilityBefore = card.stability!;
    card = scheduler.review(card, Rating.good, t0.add(const Duration(days: 2)));
    expect(card.state, FsrsState.review);
    expect(card.stability, greaterThan(stabilityBefore));
  });

  test('test_relearning_card_rate_hard_one_relearning_step', () {
    const firstStep = Duration(minutes: 10);
    // Explicit, as in the Python test, although it is the default.
    // ignore: avoid_redundant_argument_values
    final scheduler = FsrsScheduler(relearningSteps: const [firstStep]);
    var card = newCard();
    card = scheduler.review(card, Rating.easy, card.due);
    expect(card.state, FsrsState.review);
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);
    final prevDue = card.due;
    card = scheduler.review(card, Rating.hard, prevDue);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);
    expect(
      (card.due.difference(prevDue) - firstStep * 1.5).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );
  });

  test('test_relearning_card_rate_hard_two_relearning_steps', () {
    const firstStep = Duration(minutes: 1);
    const secondStep = Duration(minutes: 10);
    final scheduler = FsrsScheduler(
      relearningSteps: const [firstStep, secondStep],
    );
    var card = newCard();
    card = scheduler.review(card, Rating.easy, card.due);
    expect(card.state, FsrsState.review);
    card = scheduler.review(card, Rating.again, card.due);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);

    var prevDue = card.due;
    card = scheduler.review(card, Rating.hard, prevDue);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 0);
    expect(
      (card.due.difference(prevDue) - (firstStep + secondStep) * 0.5).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );

    card = scheduler.review(card, Rating.good, card.due);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 1);

    prevDue = card.due;
    card = scheduler.review(card, Rating.hard, prevDue);
    expect(card.state, FsrsState.relearning);
    expect(card.step, 1);
    expect(
      (card.due.difference(prevDue) - secondStep).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );

    card = scheduler.review(card, Rating.easy, prevDue);
    expect(card.state, FsrsState.review);
    expect(card.step, isNull);
  });

  group('port specifics', () {
    test('review times must be UTC', () {
      expect(
        () => FsrsScheduler().review(
          newCard(),
          Rating.good,
          DateTime(2022, 11, 29, 12, 30),
        ),
        throwsArgumentError,
      );
    });

    test('a clock that went backwards counts as a same-day review', () {
      final scheduler = FsrsScheduler(enableFuzzing: false);
      var card = scheduler.review(newCard(), Rating.easy, t0);
      final before = card.stability!;
      // One second before the previous review.
      card = scheduler.review(
        card,
        Rating.good,
        t0.subtract(const Duration(seconds: 1)),
      );
      expect(card.stability, greaterThanOrEqualTo(before));
      expect(
        scheduler.retrievability(card, t0.subtract(const Duration(days: 3))),
        1,
      );
    });

    test('cards compare by value', () {
      final a = FsrsCard(due: t0, stability: 1, difficulty: 5, lastReview: t0);
      final b = FsrsCard(due: t0, stability: 1, difficulty: 5, lastReview: t0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(FsrsCard(due: t0)));
      expect(a.toString(), contains('learning'));
    });
  });
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
