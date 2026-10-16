import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/fsrs/fsrs.dart';
import 'package:meta/meta.dart';

/// Where a card is in its life.
enum CardState {
  /// Never reviewed (or reset by a content update).
  newCard('new'),

  /// In its first learning steps (about 1 and 10 minutes).
  learning('learning'),

  /// Graduated: scheduled in days by FSRS.
  review('review'),

  /// Failed a review and in its 10-minute relearning step.
  relearning('relearning');

  CardState(this.id);

  /// The value stored in the database.
  final String id;
}

/// One item in one drill: a noun in Genre or Vocabulaire, or a verb × tense in
/// Conjugaison. Each card is scheduled on its own.
@immutable
class DrillCard {
  const DrillCard({
    required this.id,
    required this.itemId,
    required this.drill,
    required this.createdAt,
    this.tense,
    this.state = CardState.newCard,
    this.step,
    this.stability,
    this.difficulty,
    this.due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.againCount = 0,
    this.isLeech = false,
    this.knownAt,
  }) : assert(
         (drill == DrillType.conjugation) == (tense != null),
         'Conjugation cards have a tense; other cards do not',
       );

  final int id;

  /// The noun (Genre, Vocabulaire) or verb (Conjugaison) the card is about.
  final String itemId;

  final DrillType drill;

  /// Conjugation cards only.
  final Tense? tense;

  final CardState state;

  /// The learning or relearning step; null otherwise.
  final int? step;

  final double? stability;
  final double? difficulty;

  /// When the card is next due, in UTC; null for a new card.
  final DateTime? due;

  /// When the card was last reviewed, in UTC.
  final DateTime? lastReview;

  /// How many times the card has been answered.
  final int reps;

  /// How many times a review-state card was failed (FSRS's lapses).
  final int lapses;

  /// How many answers ended rated Again, in any state. Eight make a leech.
  final int againCount;

  /// A *mot difficile*. Once set, it stays.
  final bool isLeech;

  /// When the user marked the card known, or null. Known cards are never
  /// scheduled, but keep their FSRS state for when they come back.
  final DateTime? knownAt;

  final DateTime createdAt;

  bool get isKnown => knownAt != null;

  /// The card as FSRS sees it. A new card is at learning step 0, due [now].
  FsrsCard toFsrs(DateTime now) => switch (state) {
    CardState.newCard => FsrsCard(due: now),
    _ => FsrsCard(
      due: due!,
      state: switch (state) {
        CardState.relearning => FsrsState.relearning,
        CardState.review => FsrsState.review,
        _ => FsrsState.learning,
      },
      step: step,
      stability: stability,
      difficulty: difficulty,
      lastReview: lastReview,
    ),
  };

  /// Marks the card known at [at], or brings it back into practice with its
  /// FSRS state when [at] is null.
  DrillCard withKnownAt(DateTime? at) => _copy(knownAt: at);

  DrillCard withFsrs(
    FsrsCard fsrs, {
    required int reps,
    required int lapses,
    required int againCount,
    required bool isLeech,
  }) => _copy(
    state: switch (fsrs.state) {
      FsrsState.learning => CardState.learning,
      FsrsState.review => CardState.review,
      FsrsState.relearning => CardState.relearning,
    },
    step: fsrs.step,
    stability: fsrs.stability,
    difficulty: fsrs.difficulty,
    due: fsrs.due,
    lastReview: fsrs.lastReview,
    reps: reps,
    lapses: lapses,
    againCount: againCount,
    isLeech: isLeech,
  );

  DrillCard _copy({
    CardState? state,
    int? step,
    double? stability,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    int? againCount,
    bool? isLeech,
    Object? knownAt = _keep,
  }) => DrillCard(
    id: id,
    itemId: itemId,
    drill: drill,
    tense: tense,
    createdAt: createdAt,
    state: state ?? this.state,
    // A new FSRS state replaces the step, which is null in review.
    step: state != null ? step : this.step,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    due: due ?? this.due,
    lastReview: lastReview ?? this.lastReview,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    againCount: againCount ?? this.againCount,
    isLeech: isLeech ?? this.isLeech,
    knownAt: identical(knownAt, _keep) ? this.knownAt : knownAt as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      other is DrillCard &&
      other.id == id &&
      other.itemId == itemId &&
      other.drill == drill &&
      other.tense == tense &&
      other.state == state &&
      other.step == step &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.due == due &&
      other.lastReview == lastReview &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.againCount == againCount &&
      other.isLeech == isLeech &&
      other.knownAt == knownAt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    drill,
    tense,
    state,
    step,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
    againCount,
    isLeech,
    knownAt,
    createdAt,
  );

  @override
  String toString() =>
      'DrillCard($id, $itemId, ${drill.name}'
      '${tense == null ? '' : ' ${tense!.id}'}, ${state.id})';
}

const _keep = Object();
