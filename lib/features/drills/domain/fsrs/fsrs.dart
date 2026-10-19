// A Dart port of the scheduler in py-fsrs 6.3.2, the reference implementation
// of FSRS-6: https://github.com/open-spaced-repetition/py-fsrs
//
// MIT License. Copyright (c) 2022 Open Spaced Repetition.
// The full licence is in assets/licences/py-fsrs.txt and on the app's licence
// page.
//
// Ported rather than taken from the `fsrs` package on pub.dev, whose latest
// release (2.0.1) predates py-fsrs's updated default parameters (6.2.0) and
// its same-day Hard stability fix (6.3.2). The port follows py-fsrs line by
// line, including Python's rounding, and test/features/drills/domain/fsrs/
// runs py-fsrs's own tests against it. The optimizer, rescheduling and
// serialisation are left out: the app does not use them.

import 'dart:math' as math;

import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:meta/meta.dart';

/// The default FSRS-6 parameters (weights) from py-fsrs 6.3.2.
const List<double> defaultParameters = [
  0.212,
  1.2931,
  2.3065,
  8.2956,
  6.4133,
  0.8334,
  3.0194,
  0.001,
  1.8722,
  0.1666,
  0.796,
  1.4835,
  0.0614,
  0.2629,
  1.6483,
  0.6014,
  1.8729,
  0.5425,
  0.0912,
  0.0658,
  0.1542,
];

const double stabilityMin = 0.001;

const List<double> lowerBoundsParameters = [
  stabilityMin,
  stabilityMin,
  stabilityMin,
  stabilityMin,
  1,
  0.001,
  0.001,
  0.001,
  0,
  0,
  0.001,
  0.001,
  0.001,
  0.001,
  0,
  0,
  1,
  0,
  0,
  0,
  0.1,
];

const double initialStabilityMax = 100;

const List<double> upperBoundsParameters = [
  initialStabilityMax,
  initialStabilityMax,
  initialStabilityMax,
  initialStabilityMax,
  10,
  4,
  4,
  0.75,
  4.5,
  0.8,
  3.5,
  5,
  0.25,
  0.9,
  4,
  1,
  6,
  2,
  2,
  0.8,
  0.8,
];

const double minDifficulty = 1;
const double maxDifficulty = 10;

const List<({double start, double end, double factor})> _fuzzRanges = [
  (start: 2.5, end: 7, factor: 0.15),
  (start: 7, end: 20, factor: 0.1),
  (start: 20, end: double.infinity, factor: 0.05),
];

/// A card's state in FSRS. FSRS has no "new" state: a card that has never
/// been reviewed is in [learning] at step 0 with no stability yet.
enum FsrsState {
  learning(1),
  review(2),
  relearning(3);

  FsrsState(this.value);

  final int value;
}

/// A card's memory state as FSRS sees it.
@immutable
class FsrsCard {
  const FsrsCard({
    required this.due,
    this.state = FsrsState.learning,
    this.step = 0,
    this.stability,
    this.difficulty,
    this.lastReview,
  });

  final FsrsState state;

  /// The learning or relearning step, or null in the review state.
  final int? step;

  final double? stability;
  final double? difficulty;

  /// When the card is next due, in UTC.
  final DateTime due;

  /// When the card was last reviewed, in UTC.
  final DateTime? lastReview;

  @override
  bool operator ==(Object other) =>
      other is FsrsCard &&
      other.state == state &&
      other.step == step &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.due == due &&
      other.lastReview == lastReview;

  @override
  int get hashCode =>
      Object.hash(state, step, stability, difficulty, due, lastReview);

  @override
  String toString() =>
      'FsrsCard(state: ${state.name}, step: $step, stability: $stability, '
      'difficulty: $difficulty, due: $due, lastReview: $lastReview)';
}

/// The FSRS scheduler.
class FsrsScheduler {
  /// Creates a scheduler. [random] supplies the fuzz, as a number from 0 up
  /// to (not including) 1; tests pass a fixed sequence.
  FsrsScheduler({
    List<double> parameters = defaultParameters,
    this.desiredRetention = 0.9,
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.maximumInterval = 36500,
    this.enableFuzzing = true,
    double Function()? random,
  }) : parameters = List.unmodifiable(parameters),
       _random = random ?? math.Random().nextDouble {
    _validateParameters(parameters);
    _decay = -this.parameters[20];
    _factor = math.pow(0.9, 1 / _decay) - 1;
  }

  final List<double> parameters;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;

  /// The longest interval, in days.
  final int maximumInterval;

  final bool enableFuzzing;

  final double Function() _random;
  late final double _decay;
  late final double _factor;

  static void _validateParameters(List<double> parameters) {
    if (parameters.length != lowerBoundsParameters.length) {
      throw ArgumentError(
        'Expected ${lowerBoundsParameters.length} parameters, '
        'got ${parameters.length}.',
      );
    }
    String outOfBounds(int i) =>
        'parameters[$i] = ${parameters[i]} is out of bounds: '
        '(${lowerBoundsParameters[i]}, ${upperBoundsParameters[i]})';

    final errors = [
      for (var i = 0; i < parameters.length; i++)
        if (!(lowerBoundsParameters[i] <= parameters[i] &&
            parameters[i] <= upperBoundsParameters[i]))
          outOfBounds(i),
    ];
    if (errors.isNotEmpty) {
      throw ArgumentError(
        'One or more parameters are out of bounds:\n${errors.join('\n')}',
      );
    }
  }

  /// The predicted probability of recalling [card] at [now]. Whole days
  /// only, as in py-fsrs: a card reviewed today is at 1.
  double retrievability(FsrsCard card, DateTime now) {
    final lastReview = card.lastReview;
    final stability = card.stability;
    if (lastReview == null || stability == null) return 0;
    final elapsedDays = math.max(0, _days(now.difference(lastReview)));
    return math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();
  }

  /// Reviews [card] with [rating] at [reviewTime], which must be UTC.
  FsrsCard review(FsrsCard card, Rating rating, DateTime reviewTime) {
    if (!reviewTime.isUtc) {
      throw ArgumentError.value(reviewTime, 'reviewTime', 'must be UTC');
    }

    final lastReview = card.lastReview;
    final daysSinceLastReview = lastReview == null
        ? null
        : _days(reviewTime.difference(lastReview));
    final sameDay = daysSinceLastReview != null && daysSinceLastReview < 1;

    var state = card.state;
    var step = card.step;
    var stability = card.stability;
    var difficulty = card.difficulty;
    Duration nextInterval;

    Duration reviewInterval(double s) => Duration(days: _nextInterval(s));

    switch (state) {
      case FsrsState.learning:
        // Update stability and difficulty.
        if (stability == null || difficulty == null) {
          stability = _initialStability(rating);
          difficulty = _initialDifficulty(rating, clamp: true);
        } else if (sameDay) {
          stability = _shortTermStability(stability, rating);
          difficulty = _nextDifficulty(difficulty, rating);
        } else {
          stability = _nextStability(
            difficulty,
            stability,
            retrievability(card, reviewTime),
            rating,
          );
          difficulty = _nextDifficulty(difficulty, rating);
        }

        // The first case covers a card left at a step the current scheduler
        // no longer has.
        if (learningSteps.isEmpty ||
            (step! >= learningSteps.length && rating != Rating.again)) {
          state = FsrsState.review;
          step = null;
          nextInterval = reviewInterval(stability);
        } else {
          (state, step, nextInterval) = _stepThrough(
            steps: learningSteps,
            step: step,
            rating: rating,
            stepState: FsrsState.learning,
            graduate: () => reviewInterval(stability!),
          );
        }

      case FsrsState.review:
        stability = sameDay
            ? _shortTermStability(stability!, rating)
            : _nextStability(
                difficulty!,
                stability!,
                retrievability(card, reviewTime),
                rating,
              );
        difficulty = _nextDifficulty(difficulty!, rating);

        if (rating == Rating.again && relearningSteps.isNotEmpty) {
          state = FsrsState.relearning;
          step = 0;
          nextInterval = relearningSteps[0];
        } else {
          nextInterval = reviewInterval(stability);
        }

      case FsrsState.relearning:
        if (sameDay) {
          stability = _shortTermStability(stability!, rating);
          difficulty = _nextDifficulty(difficulty!, rating);
        } else {
          stability = _nextStability(
            difficulty!,
            stability!,
            retrievability(card, reviewTime),
            rating,
          );
          difficulty = _nextDifficulty(difficulty, rating);
        }

        if (relearningSteps.isEmpty ||
            (step! >= relearningSteps.length && rating != Rating.again)) {
          state = FsrsState.review;
          step = null;
          nextInterval = reviewInterval(stability);
        } else {
          (state, step, nextInterval) = _stepThrough(
            steps: relearningSteps,
            step: step,
            rating: rating,
            stepState: FsrsState.relearning,
            graduate: () => reviewInterval(stability!),
          );
        }
    }

    if (enableFuzzing && state == FsrsState.review) {
      nextInterval = Duration(days: _fuzzedIntervalDays(nextInterval.inDays));
    }

    return FsrsCard(
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      due: reviewTime.add(nextInterval),
      lastReview: reviewTime,
    );
  }

  /// The learning and relearning steps, which work the same way.
  (FsrsState, int?, Duration) _stepThrough({
    required List<Duration> steps,
    required int step,
    required Rating rating,
    required FsrsState stepState,
    required Duration Function() graduate,
  }) {
    switch (rating) {
      case Rating.again:
        return (stepState, 0, steps[0]);
      case Rating.hard:
        // The step stays the same.
        if (step == 0 && steps.length == 1) {
          return (stepState, step, _scaled(steps[0], 1.5));
        }
        if (step == 0 && steps.length >= 2) {
          return (stepState, step, _scaled(steps[0] + steps[1], 0.5));
        }
        return (stepState, step, steps[step]);
      case Rating.good:
        if (step + 1 == steps.length) {
          return (FsrsState.review, null, graduate());
        }
        return (stepState, step + 1, steps[step + 1]);
      case Rating.easy:
        return (FsrsState.review, null, graduate());
    }
  }

  double _clampDifficulty(double d) =>
      math.min(math.max(d, minDifficulty), maxDifficulty);

  double _clampStability(double s) => math.max(s, stabilityMin);

  double _initialStability(Rating rating) =>
      _clampStability(parameters[rating.value - 1]);

  double _initialDifficulty(Rating rating, {required bool clamp}) {
    final d = parameters[4] - math.exp(parameters[5] * (rating.value - 1)) + 1;
    return clamp ? _clampDifficulty(d) : d;
  }

  int _nextInterval(double stability) {
    final interval =
        (stability / _factor) * (math.pow(desiredRetention, 1 / _decay) - 1);
    // Intervals are whole days, at least one and at most the maximum.
    return math.min(math.max(pythonRound(interval), 1), maximumInterval);
  }

  double _shortTermStability(double stability, Rating rating) {
    var increase =
        math.exp(parameters[17] * (rating.value - 3 + parameters[18])) *
        math.pow(stability, -parameters[19]);
    if (rating != Rating.again) increase = math.max(increase, 1);
    return _clampStability(stability * increase);
  }

  double _nextDifficulty(double difficulty, Rating rating) {
    final arg1 = _initialDifficulty(Rating.easy, clamp: false);
    final deltaDifficulty = -(parameters[6] * (rating.value - 3));
    final arg2 = difficulty + (10.0 - difficulty) * deltaDifficulty / 9.0;
    final next = parameters[7] * arg1 + (1 - parameters[7]) * arg2;
    return _clampDifficulty(next);
  }

  double _nextStability(
    double difficulty,
    double stability,
    double retrievability,
    Rating rating,
  ) {
    final next = rating == Rating.again
        ? _nextForgetStability(difficulty, stability, retrievability)
        : _nextRecallStability(difficulty, stability, retrievability, rating);
    return _clampStability(next);
  }

  double _nextForgetStability(
    double difficulty,
    double stability,
    double retrievability,
  ) {
    final longTerm =
        parameters[11] *
        math.pow(difficulty, -parameters[12]) *
        (math.pow(stability + 1, parameters[13]) - 1) *
        math.exp((1 - retrievability) * parameters[14]);
    final shortTerm = stability / math.exp(parameters[17] * parameters[18]);
    return math.min(longTerm, shortTerm);
  }

  double _nextRecallStability(
    double difficulty,
    double stability,
    double retrievability,
    Rating rating,
  ) {
    final hardPenalty = rating == Rating.hard ? parameters[15] : 1;
    final easyBonus = rating == Rating.easy ? parameters[16] : 1;
    return stability *
        (1 +
            math.exp(parameters[8]) *
                (11 - difficulty) *
                math.pow(stability, -parameters[9]) *
                (math.exp((1 - retrievability) * parameters[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  int _fuzzedIntervalDays(int intervalDays) {
    // No fuzz below 2.5 days.
    if (intervalDays < 2.5) return intervalDays;

    var delta = 1.0;
    for (final range in _fuzzRanges) {
      delta +=
          range.factor *
          math.max(
            math.min(intervalDays.toDouble(), range.end) - range.start,
            0,
          );
    }
    var minIvl = pythonRound(intervalDays - delta);
    var maxIvl = pythonRound(intervalDays + delta);
    minIvl = math.max(2, minIvl);
    maxIvl = math.min(maxIvl, maximumInterval);
    minIvl = math.min(minIvl, maxIvl);

    final fuzzed = _random() * (maxIvl - minIvl + 1) + minIvl;
    return math.min(pythonRound(fuzzed), maximumInterval);
  }
}

/// Python's `round()`: halves go to the nearest even number (2.5 → 2,
/// 3.5 → 4), unlike Dart's `round()`, which rounds them away from zero.
@visibleForTesting
int pythonRound(double x) {
  final floor = x.floorToDouble();
  final fraction = x - floor;
  final whole = floor.toInt();
  if (fraction < 0.5) return whole;
  if (fraction > 0.5) return whole + 1;
  return whole.isEven ? whole : whole + 1;
}

/// Whole days in [d], rounded down as Python's `timedelta.days` does, so a
/// negative duration of a second is -1 day, not 0.
int _days(Duration d) {
  final us = d.inMicroseconds;
  final days = us ~/ Duration.microsecondsPerDay;
  return us < 0 && us % Duration.microsecondsPerDay != 0 ? days - 1 : days;
}

/// [d] multiplied by [factor], rounded to the microsecond as Python's
/// `timedelta` does.
Duration _scaled(Duration d, double factor) =>
    Duration(microseconds: pythonRound(d.inMicroseconds * factor));
