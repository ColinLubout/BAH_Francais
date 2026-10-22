import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/grading.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:bah_francais/features/drills/domain/session/session_card.dart';
import 'package:meta/meta.dart';

/// What the drill screen shows.
@immutable
sealed class DrillView {
  const DrillView();
}

/// A card waiting for its answer.
class CardQuestion extends DrillView {
  const CardQuestion(this.card, {this.startsFreePractice = false});

  final SessionCard card;

  /// The session has just moved into free practice: *Tout est à jour !* shows
  /// above this card, once.
  final bool startsFreePractice;
}

/// The correction after an answer that wasn't Correct: *Presque*,
/// *Incorrect* or *Je ne sais pas*. The card stays as it was, with what was
/// answered, and the correction shows under it (decisions 71 and 75). A
/// Correct answer has none: the next card comes at once.
class CardFeedback extends DrillView {
  const CardFeedback(
    this.card,
    this.grade, {
    this.typed,
    this.chosen,
    this.overridden = false,
  });

  final SessionCard card;
  final Grade grade;

  /// What was typed; none after *Je ne sais pas*, or in Genre.
  final String? typed;

  /// The tile tapped, in Genre.
  final Gender? chosen;

  /// *Faute de frappe* was used: it isn't offered any more.
  final bool overridden;

  /// *Faute de frappe* is offered after a wrong answer.
  bool get offersTypo => !overridden && grade.canMarkTypo;
}

/// The review limit is reached and nothing else is left:
/// *Ça suffit pour aujourd’hui.*
class GoalReached extends DrillView {
  const GoalReached();
}

/// No card to show: no content, or every category is off.
class NoCards extends DrillView {
  const NoCards();
}

/// The numbers the session summary shows: for the whole session, and in a
/// mixed session for each drill.
@immutable
class SessionSummary {
  const SessionSummary({
    required this.answered,
    required this.correct,
    required this.duration,
    this.byDrill = const {},
  });

  final int answered;

  /// Answers graded anything but Again.
  final int correct;

  /// From the start of the session to its last answer; for one drill of a
  /// mixed session, the time spent answering its cards.
  final Duration duration;

  /// Each drill's numbers, in a mixed session, for the drills answered.
  final Map<DrillType, SessionSummary> byDrill;

  /// No card was answered: no summary is shown, and no session was saved.
  bool get isEmpty => answered == 0;

  /// % correct, rounded; 0 when nothing was answered.
  int get percentCorrect =>
      answered == 0 ? 0 : (correct * 100 / answered).round();
}

/// A *Je le connais* mark, kept for its *Annuler*.
@immutable
class KnownMark {
  const KnownMark(this.cards);

  /// The cards marked, as they were before the mark.
  final List<DrillCard> cards;
}

/// One session of one drill, or of all three (a mixed session): serves cards
/// in the order Session flow sets, grades the answers and saves each at
/// once, so a session can stop at any moment without losing one.
///
/// The session row is written with the first answer; a session with none
/// leaves nothing behind.
class DrillSession {
  DrillSession._({
    required this.drill,
    required this._store,
    required this._clock,
    required this._scheduler,
    required this._random,
    required this._queue,
    required this._showsGenderImage,
    required this.startedAt,
  });

  /// Opens a session of [drill], or a mixed session when [drill] is null:
  /// builds its queue from the store, without showing a card yet (call
  /// [next]). [showsGenderImage] is Genre's *Afficher l’image*.
  static Future<DrillSession> open({
    required DrillType? drill,
    required DrillStore store,
    required Clock clock,
    required DrillScheduler scheduler,
    required double Function() random,
    bool showsGenderImage = true,
  }) async {
    Future<SessionQueue> queueOf(DrillType drill) => queueFor(
      drill,
      store: store,
      clock: clock,
      scheduler: scheduler,
      random: random,
    );
    return DrillSession._(
      drill: drill,
      store: store,
      clock: clock,
      scheduler: scheduler,
      random: random,
      queue: drill == null
          ? MixedQueue({for (final d in DrillType.values) d: await queueOf(d)})
          : await queueOf(drill),
      showsGenderImage: showsGenderImage,
      startedAt: clock.nowUtc(),
    );
  }

  /// [drill]'s queue as it stands now: its cards, settings, everyday
  /// categories, and what today's answers have used of the limits. Accueil
  /// reads its due count from it.
  static Future<SessionQueue> queueFor(
    DrillType drill, {
    required DrillStore store,
    required Clock clock,
    required DrillScheduler scheduler,
    required double Function() random,
  }) async {
    final today = StudyDay.today(clock);
    final cards = await store.queueCards(drill);
    final setup = await store.queueSetup(drill);
    final counts = await store.dayCounts(drill, today);
    return SessionQueue(
      cards: cards,
      settings: setup.settings,
      countsOn: (day) => day == today ? counts : const DayCounts(),
      scheduler: scheduler,
      random: random,
      everydayCategoryIds: setup.everydayCategoryIds,
    );
  }

  /// Leaving the app for longer than this closes the session; returning
  /// sooner resumes the same card.
  static const resumeWindow = Duration(minutes: 30);

  /// Whether a session left for [away] is closed.
  static bool closesAfter(Duration away) => away > resumeWindow;

  /// The drill; null for a mixed session.
  final DrillType? drill;

  /// When the session started, UTC.
  final DateTime startedAt;

  final DrillStore _store;
  final Clock _clock;
  final DrillScheduler _scheduler;
  final double Function() _random;
  final CardQueue _queue;
  final bool _showsGenderImage;

  DrillView _view = const NoCards();
  DateTime? _shownAt;
  int? _sessionId;
  DateTime? _lastAnswerAt;

  /// Each drill's answers, correct answers and time answering.
  final Map<DrillType, (int, int, Duration)> _tallies = {};

  /// The answer now corrected on screen, for *Faute de frappe*.
  ReviewOutcome? _outcome;
  int? _logId;

  /// What the screen shows now.
  DrillView get view => _view;

  SessionSummary get summary {
    var answered = 0;
    var correct = 0;
    for (final (a, c, _) in _tallies.values) {
      answered += a;
      correct += c;
    }
    return SessionSummary(
      answered: answered,
      correct: correct,
      duration: (_lastAnswerAt ?? startedAt).difference(startedAt),
      byDrill: drill != null
          ? const {}
          : {
              for (final d in DrillType.values)
                if (_tallies[d] case (final a, final c, final time))
                  d: SessionSummary(answered: a, correct: c, duration: time),
            },
    );
  }

  /// Moves on to the next card, or to what the session shows when none is
  /// left.
  Future<DrillView> next() async {
    final step = _queue.next(_clock);
    switch (step) {
      case ShowCard():
        final card = await _cardFor(step.card);
        _shownAt = _clock.nowUtc();
        _outcome = null;
        _logId = null;
        return _view = CardQuestion(
          card,
          startsFreePractice: step.startsFreePractice,
        );
      case DailyGoalReached():
        return _view = const GoalReached();
      case NoCardsAvailable():
        return _view = const NoCards();
    }
  }

  /// Grades [typed], in Vocabulaire or Conjugaison, and saves the answer.
  /// [capsGrade] means a letter went red or orange while typing, which caps
  /// the grade at Hard.
  ///
  /// A Correct answer moves straight on to the next card; any other answer
  /// shows its correction (decision 71).
  Future<DrillView> submit(String typed, {bool capsGrade = false}) async {
    final card = switch (_question.card) {
      final TypedCard card => card,
      GenderCard() => throw StateError('A Genre card is answered by a tile'),
    };
    final grade = switch (card) {
      VocabularyCard(:final item) => gradeVocabulary(
        typed: typed,
        noun: item.answer,
        flaggedWhileTyping: capsGrade,
      ),
      ConjugationCard(:final sentence) => gradeConjugation(
        typed: typed,
        answer: sentence.answer,
        alternatives: sentence.alternatives,
        flaggedWhileTyping: capsGrade,
      ),
    };
    await _answer(card, grade, typed: typed);
    if (_isCorrect(grade)) return await next();
    return _view = CardFeedback(card, grade, typed: typed);
  }

  /// Grades the tile [chosen], in Genre, and saves the answer: a Correct
  /// answer moves straight on, a wrong one shows its correction (decision
  /// 75).
  Future<DrillView> choose(Gender chosen) async {
    final card = switch (_question.card) {
      final GenderCard card => card,
      TypedCard() => throw StateError('Only a Genre card has tiles'),
    };
    final grade = gradeGender(correct: card.item.answer.gender, chosen: chosen);
    await _answer(card, grade);
    if (_isCorrect(grade)) return await next();
    return _view = CardFeedback(card, grade, chosen: chosen);
  }

  /// *Je ne sais pas*, in Vocabulaire or Conjugaison: Again, and the answer
  /// is shown.
  Future<DrillView> giveUp() async {
    final card = switch (_question.card) {
      final TypedCard card => card,
      GenderCard() => throw StateError('Genre has no Je ne sais pas'),
    };
    final grade = Grade.gaveUp(card.answer);
    await _answer(card, grade);
    return _view = CardFeedback(card, grade);
  }

  /// *Trop facile*, on a word seen for the first time: Easy with no answer,
  /// and the next card at once (decision 72).
  Future<DrillView> tooEasy() async {
    final card = _question.card;
    if (!card.offersTooEasy) throw StateError('Trop facile is not offered');
    await _answer(card, const Grade.tooEasy());
    return await next();
  }

  /// *Faute de frappe* after a wrong answer: it is saved again as Hard.
  Future<DrillView> markTypo() async {
    final feedback = _view;
    final outcome = _outcome;
    final logId = _logId;
    if (feedback is! CardFeedback || outcome == null || logId == null) {
      throw StateError('No answer to override');
    }
    if (!feedback.offersTypo) {
      throw StateError('Faute de frappe is not offered');
    }
    final grade = feedback.grade.markTypo();
    final regraded = _scheduler.regrade(outcome, grade.rating);
    await _store.replaceAnswer(
      logId,
      Answer(
        outcome: regraded,
        sessionId: _sessionId!,
        responseTime: _responseTime,
        errorType: grade.errorType,
        typed: feedback.typed,
      ),
    );
    _queue.recordRegrade(regraded);
    final drill = feedback.card.card.drill;
    if (_tallies[drill] case (final a, final c, final time)) {
      _tallies[drill] = (a, c + 1, time);
    }
    _outcome = regraded;
    return _view = CardFeedback(
      feedback.card,
      grade,
      typed: feedback.typed,
      chosen: feedback.chosen,
      overridden: true,
    );
  }

  /// *Je le connais*: a noun's cards in every drill leave practice, or for
  /// a verb, only its card in this tense; no grade and no review-log row,
  /// and the next card comes at once. Keep the mark for [undoKnown].
  Future<(KnownMark, DrillView)> markKnown() async {
    final card = switch (_view) {
      CardQuestion(:final card) || CardFeedback(:final card) => card.card,
      _ => throw StateError('No card to mark known'),
    };
    final cards = [
      for (final c in await _store.cardsOfItem(card.itemId))
        if (card.drill != DrillType.conjugation || c.tense == card.tense) c,
    ];
    final now = _clock.nowUtc();
    await _store.setKnownAt([for (final c in cards) c.id], now);
    for (final c in cards) {
      if (_serves(c)) _queue.update(c.withKnownAt(now));
    }
    return (KnownMark(cards), await next());
  }

  /// *Annuler* after *Je le connais*: the cards come back as they were.
  Future<void> undoKnown(KnownMark mark) async {
    await _store.setKnownAt([for (final c in mark.cards) c.id], null);
    for (final c in mark.cards) {
      if (_serves(c)) _queue.update(c.withKnownAt(null));
    }
  }

  CardQuestion get _question => switch (_view) {
    final CardQuestion q => q,
    _ => throw StateError('No card is waiting for an answer'),
  };

  /// The card is in this session's drill, or in any for a mixed session.
  bool _serves(DrillCard card) => drill == null || card.drill == drill;

  static bool _isCorrect(Grade grade) =>
      grade.rating == Rating.good || grade.rating == Rating.easy;

  Duration get _responseTime {
    final shown = _shownAt ?? startedAt;
    final time = (_lastAnswerAt ?? _clock.nowUtc()).difference(shown);
    return time.isNegative ? Duration.zero : time;
  }

  /// The card to show for [card], with what its drill needs.
  Future<SessionCard> _cardFor(DrillCard card) async {
    switch (card.drill) {
      case DrillType.gender:
        final item = await _store.nounItem(card.itemId);
        return GenderCard(
          card: card,
          item: item,
          imageId: _showsGenderImage ? _pick(item.imageIds) : null,
          example: _pick(item.examples),
        );
      case DrillType.vocabulary:
        final item = await _store.nounItem(card.itemId);
        return VocabularyCard(
          card: card,
          item: item,
          prompt: VocabularyPrompt.of(item, _random),
          sentence: _pick(item.sentencesToFill),
        );
      case DrillType.conjugation:
        final item = await _store.conjugationItem(card.itemId, card.tense!);
        // A person at random, then one of its sentences.
        final persons = {for (final s in item.sentences) s.person}.toList();
        final person = _pick(persons);
        final sentence = _pick([
          for (final s in item.sentences)
            if (s.person == person) s,
        ]);
        if (sentence == null) {
          throw StateError('${item.verbId} has no sentence in ${item.tense}');
        }
        return ConjugationCard(card: card, item: item, sentence: sentence);
    }
  }

  Future<void> _answer(SessionCard card, Grade grade, {String? typed}) async {
    final now = _clock.nowUtc();
    final outcome = _scheduler.review(
      card.card,
      grade.rating,
      at: now,
      day: StudyDay.of(now, _clock.utcOffset()),
    );
    final sessionId = _sessionId ??= await _store.startSession(
      drill: drill,
      at: startedAt,
    );
    _lastAnswerAt = now;
    final responseTime = _responseTime;
    _logId = await _store.recordAnswer(
      Answer(
        outcome: outcome,
        sessionId: sessionId,
        responseTime: responseTime,
        errorType: grade.errorType,
        typed: typed,
      ),
    );
    _queue.record(outcome);
    _outcome = outcome;
    final (a, c, time) = _tallies[card.card.drill] ?? (0, 0, Duration.zero);
    _tallies[card.card.drill] = (
      a + 1,
      grade.rating == Rating.again ? c : c + 1,
      time + responseTime,
    );
  }

  /// One of [items], chosen with the session's randomness.
  T? _pick<T>(List<T> items) => items.isEmpty
      ? null
      : items[(_random() * items.length).floor().clamp(0, items.length - 1)];
}
