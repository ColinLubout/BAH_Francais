import 'dart:math' as math;

import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/new_card_picker.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:meta/meta.dart';

/// What a study day's answers have used of the daily limits.
@immutable
class DayCounts {
  const DayCounts({this.newCards = 0, this.reviews = 0});

  /// Cards answered for the first time: counts against the new-card limit.
  final int newCards;

  /// Answers to cards in the review state: counts against the review limit.
  /// Learning and relearning steps don't count.
  final int reviews;

  /// Counts [outcome], if it uses a limit.
  DayCounts adding(ReviewOutcome outcome) => switch (outcome.stateBefore) {
    CardState.newCard => DayCounts(newCards: newCards + 1, reviews: reviews),
    CardState.review => DayCounts(newCards: newCards, reviews: reviews + 1),
    _ => this,
  };
}

/// Why a card is being shown, in the order the session serves them.
enum CardSource {
  /// A new or failed card whose learning step has come round.
  learningStep,

  /// A review card due today, lowest retrievability first.
  dueReview,

  /// A new card, about one for every four reviews, up to the daily limit.
  newCard,

  /// Nothing is due and the new-card limit is reached: an early review of
  /// the card closest to forgetting, or a learning card before its step.
  freePractice,

  /// The review limit is reached: a learning card shown before its step,
  /// since learning continues while reviews wait.
  earlyLearningStep,
}

/// What the session shows next.
@immutable
sealed class NextStep {
  const NextStep();
}

class ShowCard extends NextStep {
  const ShowCard(this.item, this.source, {this.startsFreePractice = false});

  final QueueCard item;
  final CardSource source;

  /// The first free-practice card of the session: shown with *Tout est à
  /// jour !* above it.
  final bool startsFreePractice;

  DrillCard get card => item.card;
}

/// The review limit is reached and no learning or new card is left: the
/// user has reached today's goal.
class DailyGoalReached extends NextStep {
  const DailyGoalReached();
}

/// Nothing can be shown: no content, or every category is off.
class NoCardsAvailable extends NextStep {
  const NoCardsAvailable();
}

/// The cards a session serves: one drill's ([SessionQueue]), or all three's
/// ([MixedQueue]).
abstract interface class CardQueue {
  /// What to show now, by [clock].
  NextStep next(Clock clock);

  /// Records an answer: the card's new state, and the limits it used.
  void record(ReviewOutcome outcome);

  /// Records an override of an answer already recorded.
  void recordRegrade(ReviewOutcome regraded);

  /// Updates a card changed outside a review, such as one marked known.
  void update(DrillCard card);
}

/// The queue of a mixed session (decision 80): each drill's queue offers its
/// next card, and the most urgent is shown, the drills taking turns.
///
/// Learning steps come first; then due reviews and new cards, each drill
/// keeping its own rhythm of one new card per four reviews; then free
/// practice. Among equally urgent cards, the drill shown least recently goes
/// first, and a card for the word just shown waits a turn, unless nothing
/// else is left. Each drill keeps its own limits; one that has reached its
/// daily goal, or has nothing, drops out.
class MixedQueue implements CardQueue {
  MixedQueue(this._queues);

  /// Each drill's queue, in the order drills take their first turn.
  final Map<DrillType, SessionQueue> _queues;

  /// When each drill last had a card shown, counted in cards.
  final Map<DrillType, int> _shownAt = {};
  int _shown = 0;
  String? _lastItemId;
  bool _inFreePractice = false;

  @override
  NextStep next(Clock clock) {
    final offers = <(DrillType, ShowCard)>[];
    var goalReached = false;
    for (final MapEntry(key: drill, value: queue) in _queues.entries) {
      switch (queue.peek(clock)) {
        case final ShowCard step:
          offers.add((drill, step));
        case DailyGoalReached():
          goalReached = true;
        case NoCardsAvailable():
          break;
      }
    }
    if (offers.isEmpty) {
      return goalReached ? const DailyGoalReached() : const NoCardsAvailable();
    }
    final order = [for (final o in offers) o]
      ..sort((a, b) {
        final byUrgency = _urgency(a.$2.source) - _urgency(b.$2.source);
        if (byUrgency != 0) return byUrgency;
        final byTurn = (_shownAt[a.$1] ?? -1) - (_shownAt[b.$1] ?? -1);
        if (byTurn != 0) return byTurn;
        // Sorting isn't stable: drills never shown keep their order.
        return offers.indexOf(a) - offers.indexOf(b);
      });
    final (drill, step) = order.firstWhere(
      (o) => o.$2.card.itemId != _lastItemId,
      orElse: () => order.first,
    );
    _queues[drill]!.shown(step);
    _shownAt[drill] = _shown++;
    _lastItemId = step.card.itemId;
    final practice = step.source == CardSource.freePractice;
    final starts = practice && !_inFreePractice;
    if (practice) _inFreePractice = true;
    return ShowCard(step.item, step.source, startsFreePractice: starts);
  }

  @override
  void record(ReviewOutcome outcome) =>
      _queues[outcome.after.drill]?.record(outcome);

  @override
  void recordRegrade(ReviewOutcome regraded) =>
      _queues[regraded.after.drill]?.recordRegrade(regraded);

  @override
  void update(DrillCard card) => _queues[card.drill]?.update(card);

  /// Learning steps first, then due reviews and new cards, then practice.
  static int _urgency(CardSource source) => switch (source) {
    CardSource.learningStep => 0,
    CardSource.dueReview || CardSource.newCard => 1,
    CardSource.freePractice || CardSource.earlyLearningStep => 2,
  };
}

/// Decides which card comes next in a session of one drill.
///
/// Cards come in this order:
///
/// 1. learning steps that have come round, earliest first;
/// 2. reviews due today (before the next 04:00), lowest retrievability first,
///    with a new card after every four reviews, up to the daily new-card
///    limit;
/// 3. free practice: learning cards before their step, soonest first, then
///    early reviews, closest to forgetting first.
///
/// When the daily review limit is reached, due reviews stop but learning
/// steps and new cards carry on; once those run out the session reports
/// [DailyGoalReached] instead of offering free practice.
///
/// Known and retired cards, cards whose categories are all Jamais, and
/// conjugation cards of a paused tense or verb group are never shown. The
/// same card is never shown twice in a row while another could be.
class SessionQueue implements CardQueue {
  SessionQueue({
    required List<QueueCard> cards,
    required this.settings,
    required this._countsOn,
    required this._scheduler,
    required double Function() random,
    Set<String> everydayCategoryIds = const {},
  }) : _cards = {for (final c in cards) c.card.id: c},
       _picker = NewCardPicker(
         random,
         everydayCategoryIds: everydayCategoryIds,
       );

  /// The drill's settings. Changes apply from the next card.
  QueueSettings settings;

  final Map<int, QueueCard> _cards;
  final DayCounts Function(StudyDay day) _countsOn;
  final Map<StudyDay, DayCounts> _counts = {};
  final DrillScheduler _scheduler;
  final NewCardPicker _picker;

  /// Reviews answered since the last new card, for the 1-in-4 rhythm.
  int _reviewsSinceNew = 0;
  bool _inFreePractice = false;
  int? _lastShownId;

  /// A new card already drawn and not yet answered, so asking again doesn't
  /// draw another.
  int? _drawnNewId;

  static const reviewsPerNewCard = 4;

  /// What to show now, by [clock]: [peek], then [shown].
  @override
  NextStep next(Clock clock) {
    final step = peek(clock);
    if (step is ShowCard) shown(step);
    return step;
  }

  /// The card this drill would show now, without counting it as shown: the
  /// mixed session asks each drill before choosing one (decision 80).
  NextStep peek(Clock clock) {
    final now = clock.nowUtc();
    final utcOffset = clock.utcOffset();
    final day = StudyDay.of(now, utcOffset);
    final endOfDay = day.endUtc(utcOffset);
    final counts = _countsFor(day);
    final reviewLimit = settings.maxReviewsPerDay;
    final reviewLimitReached =
        reviewLimit != null && counts.reviews >= reviewLimit;

    final scheduled = [
      for (final c in _cards.values)
        if (c.isScheduled(settings)) c,
    ];

    // 1. Learning steps that have come round.
    final dueSteps = [
      for (final c in scheduled)
        if (_inSteps(c.card) && !c.card.due!.isAfter(now)) c,
    ]..sort(_byDue);
    if (dueSteps.isNotEmpty) {
      return _show(dueSteps.first, CardSource.learningStep);
    }

    // 2. Due reviews and new cards.
    final dueReviews = reviewLimitReached
        ? const <QueueCard>[]
        : _byRetrievability([
            for (final c in scheduled)
              if (c.card.state == CardState.review &&
                  c.card.due!.isBefore(endOfDay))
                c,
          ], now);
    final newCandidates = counts.newCards < settings.newPerDay
        ? [
            for (final c in scheduled)
              if (c.card.state == CardState.newCard) c,
          ]
        : const <QueueCard>[];

    final newTurn = dueReviews.isEmpty || _reviewsSinceNew >= reviewsPerNewCard;
    if (newCandidates.isNotEmpty && newTurn) {
      final drawn = _drawnNewId == null ? null : _cards[_drawnNewId];
      final card = drawn != null && newCandidates.contains(drawn)
          ? drawn
          : _picker.pick(newCandidates, settings);
      if (card != null) {
        _drawnNewId = card.card.id;
        return _show(card, CardSource.newCard);
      }
    }
    if (dueReviews.isNotEmpty) {
      return _show(_avoidRepeat(dueReviews), CardSource.dueReview);
    }

    // 3. Nothing due.
    final waiting = [
      for (final c in scheduled)
        if (_inSteps(c.card)) c,
    ]..sort(_byDue);

    if (reviewLimitReached) {
      if (waiting.isEmpty) return const DailyGoalReached();
      return _show(_avoidRepeat(waiting), CardSource.earlyLearningStep);
    }

    final practice = [
      ...waiting,
      ..._byRetrievability([
        for (final c in scheduled)
          if (c.card.state == CardState.review) c,
      ], now),
    ];
    if (practice.isEmpty) return const NoCardsAvailable();
    return _show(
      _avoidRepeat(practice),
      CardSource.freePractice,
      startsFreePractice: !_inFreePractice,
    );
  }

  /// [step], from [peek], is on screen.
  void shown(ShowCard step) {
    _lastShownId = step.card.id;
    if (step.source == CardSource.freePractice) _inFreePractice = true;
  }

  /// Records an answer: the card's new state, and the limits it used.
  @override
  void record(ReviewOutcome outcome) {
    _replace(outcome.after);
    _counts[outcome.studyDay] = _countsFor(outcome.studyDay).adding(outcome);
    switch (outcome.stateBefore) {
      case CardState.newCard:
        _reviewsSinceNew = 0;
      case CardState.review:
        _reviewsSinceNew++;
      case CardState.learning || CardState.relearning:
        break;
    }
    if (outcome.after.id == _drawnNewId) _drawnNewId = null;
  }

  /// Records an override (*Faute de frappe*) of an answer already recorded:
  /// the card changes, the limits don't.
  @override
  void recordRegrade(ReviewOutcome regraded) => _replace(regraded.after);

  /// Updates a card changed outside a review, such as one marked known.
  @override
  void update(DrillCard card) {
    _replace(card);
    if (card.id == _drawnNewId) _drawnNewId = null;
  }

  /// How many cards are due today, as Accueil shows it: learning steps and
  /// reviews due before the next 04:00, reviews capped by what the review
  /// limit leaves. New cards are not counted.
  int dueToday(Clock clock) {
    final utcOffset = clock.utcOffset();
    final day = StudyDay.of(clock.nowUtc(), utcOffset);
    final endOfDay = day.endUtc(utcOffset);
    var steps = 0;
    var reviews = 0;
    for (final c in _cards.values) {
      if (!c.isScheduled(settings)) continue;
      final due = c.card.due;
      if (due == null || !due.isBefore(endOfDay)) continue;
      if (_inSteps(c.card)) steps++;
      if (c.card.state == CardState.review) reviews++;
    }
    final limit = settings.maxReviewsPerDay;
    if (limit != null) {
      reviews = math.min(reviews, math.max(0, limit - _countsFor(day).reviews));
    }
    return steps + reviews;
  }

  /// The drill this queue serves, if it has any cards.
  DrillType? get drill =>
      _cards.isEmpty ? null : _cards.values.first.card.drill;

  DayCounts _countsFor(StudyDay day) => _counts[day] ??= _countsOn(day);

  void _replace(DrillCard card) {
    final item = _cards[card.id];
    if (item != null) _cards[card.id] = item.withCard(card);
  }

  ShowCard _show(
    QueueCard item,
    CardSource source, {
    bool startsFreePractice = false,
  }) => ShowCard(item, source, startsFreePractice: startsFreePractice);

  /// The first of [ordered], unless it was just shown and another exists.
  QueueCard _avoidRepeat(List<QueueCard> ordered) =>
      ordered.length > 1 && ordered.first.card.id == _lastShownId
      ? ordered[1]
      : ordered.first;

  List<QueueCard> _byRetrievability(List<QueueCard> cards, DateTime now) {
    final r = {
      for (final c in cards) c.card.id: _scheduler.retrievability(c.card, now),
    };
    return cards..sort((a, b) {
      final byR = r[a.card.id]!.compareTo(r[b.card.id]!);
      return byR != 0 ? byR : _byDue(a, b);
    });
  }

  static bool _inSteps(DrillCard card) =>
      card.state == CardState.learning || card.state == CardState.relearning;

  static int _byDue(QueueCard a, QueueCard b) {
    final byDue = a.card.due!.compareTo(b.card.due!);
    return byDue != 0 ? byDue : a.card.id.compareTo(b.card.id);
  }
}
