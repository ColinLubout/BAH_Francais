import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/fsrs/fsrs.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:meta/meta.dart';

/// Schedules reviews with FSRS.
///
/// Each drill has its own scheduler and parameter set, so each can be tuned
/// on its own later; all use FSRS's default parameters for now, with a
/// 1-minute and a 10-minute learning step, one 10-minute relearning step and
/// fuzz. The target retention is the one global setting they share.
class DrillScheduler {
  DrillScheduler({
    this.targetRetention = defaultRetention,
    Map<DrillType, List<double>> parameters = const {},
    double Function()? random,
  }) {
    if (targetRetention < minRetention || targetRetention > maxRetention) {
      throw ArgumentError.value(
        targetRetention,
        'targetRetention',
        'must be between $minRetention and $maxRetention',
      );
    }
    for (final drill in DrillType.values) {
      _schedulers[drill] = FsrsScheduler(
        parameters: parameters[drill] ?? defaultParameters,
        desiredRetention: targetRetention,
        random: random,
      );
    }
  }

  /// Rétention visée: the default and range of the global setting.
  static const defaultRetention = 0.90;
  static const minRetention = 0.80;
  static const maxRetention = 0.97;

  /// A card rated Again this many times in all becomes a leech.
  static const leechThreshold = 8;

  final double targetRetention;
  final Map<DrillType, FsrsScheduler> _schedulers = {};

  /// Answers [card] with [rating] at [at] (UTC), on study day [day].
  ReviewOutcome review(
    DrillCard card,
    Rating rating, {
    required DateTime at,
    required StudyDay day,
  }) {
    final fsrs = _schedulers[card.drill]!.review(card.toFsrs(at), rating, at);
    final againCount = card.againCount + (rating == Rating.again ? 1 : 0);
    final lapsed = card.state == CardState.review && rating == Rating.again;
    final after = card.withFsrs(
      fsrs,
      reps: card.reps + 1,
      lapses: card.lapses + (lapsed ? 1 : 0),
      againCount: againCount,
      isLeech: card.isLeech || againCount >= leechThreshold,
    );
    return ReviewOutcome(
      before: card,
      after: after,
      rating: rating,
      reviewedAt: at,
      studyDay: day,
    );
  }

  /// Replaces [outcome]'s rating with [rating], as the override buttons do:
  /// the card is scheduled again from its state before that answer, at the
  /// same time and on the same day.
  ReviewOutcome regrade(ReviewOutcome outcome, Rating rating) => review(
    outcome.before,
    rating,
    at: outcome.reviewedAt,
    day: outcome.studyDay,
  );

  /// The probability of recalling [card] at [at]: 0 for a new card, and in
  /// whole days, so 1 for a card reviewed today.
  double retrievability(DrillCard card, DateTime at) =>
      card.state == CardState.newCard
      ? 0
      : _schedulers[card.drill]!.retrievability(card.toFsrs(at), at);
}

/// The result of answering a card: its new state, and what the review log
/// records.
@immutable
class ReviewOutcome {
  const ReviewOutcome({
    required this.before,
    required this.after,
    required this.rating,
    required this.reviewedAt,
    required this.studyDay,
  });

  final DrillCard before;
  final DrillCard after;
  final Rating rating;

  /// UTC.
  final DateTime reviewedAt;

  /// The study day the review counts towards, stored with it.
  final StudyDay studyDay;

  CardState get stateBefore => before.state;

  /// Whole days since the previous review, never negative (the clock can go
  /// backwards); null for a card's first review.
  int? get elapsedDays {
    final last = before.lastReview;
    if (last == null) return null;
    final days = reviewedAt.difference(last).inDays;
    return days < 0 ? 0 : days;
  }

  /// Whole days until the card is due again: the interval this review set,
  /// 0 for a learning or relearning step.
  int get scheduledDays => after.due!.difference(reviewedAt).inDays;
}
