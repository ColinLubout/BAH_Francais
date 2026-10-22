import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/grading.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:meta/meta.dart';

/// A Vocabulaire card as the drill screen shows it.
@immutable
class VocabularyCard {
  const VocabularyCard({
    required this.card,
    required this.item,
    required this.prompt,
    this.sentence,
  });

  final DrillCard card;
  final VocabularyItem item;
  final VocabularyPrompt prompt;

  /// The sentence the answer box sits in, the noun blanked; none when the
  /// noun has no sentence with it as it is typed.
  final ExampleSentence? sentence;

  /// Every way of typing a right answer, for live feedback. The article is
  /// optional: the sentence around the box already has one (decision 70).
  List<String> get typings => item.answer.typings();

  /// The word is seen for the first time: *Trop facile* is offered, with no
  /// answer needed (decision 72).
  bool get offersTooEasy => card.state == CardState.newCard;
}

/// What the drill screen shows.
@immutable
sealed class DrillView {
  const DrillView();
}

/// A card waiting for its answer.
class CardQuestion extends DrillView {
  const CardQuestion(this.card, {this.startsFreePractice = false});

  final VocabularyCard card;

  /// The session has just moved into free practice: *Tout est à jour !* shows
  /// above this card, once.
  final bool startsFreePractice;
}

/// The correction after an answer that wasn't Correct: *Presque*,
/// *Incorrect* or *Je ne sais pas*. The card stays as it was, with what was
/// typed, and the answer shows under it (decision 71). A Correct answer has
/// none: the next card comes at once.
class CardFeedback extends DrillView {
  const CardFeedback(
    this.card,
    this.grade, {
    this.typed,
    this.overridden = false,
  });

  final VocabularyCard card;
  final Grade grade;

  /// What was typed; none after *Je ne sais pas*.
  final String? typed;

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

/// The numbers the session summary shows.
@immutable
class SessionSummary {
  const SessionSummary({
    required this.answered,
    required this.correct,
    required this.duration,
  });

  final int answered;

  /// Answers graded anything but Again.
  final int correct;

  /// From the start of the session to its last answer.
  final Duration duration;

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

  /// The item's cards as they were before the mark.
  final List<DrillCard> cards;
}

/// One session of a drill: serves cards in the order Session flow sets,
/// grades the answers and saves each at once, so a session can stop at any
/// moment without losing one.
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
    required this.startedAt,
  });

  /// Opens a session of [drill]: builds its queue from the store, without
  /// showing a card yet (call [next]).
  static Future<DrillSession> open({
    required DrillType drill,
    required DrillStore store,
    required Clock clock,
    required DrillScheduler scheduler,
    required double Function() random,
  }) async {
    if (drill != DrillType.vocabulary) {
      throw UnsupportedError('Only the Vocabulaire drill exists so far');
    }
    final queue = await queueFor(
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
      queue: queue,
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

  final DrillType drill;

  /// When the session started, UTC.
  final DateTime startedAt;

  final DrillStore _store;
  final Clock _clock;
  final DrillScheduler _scheduler;
  final double Function() _random;
  final SessionQueue _queue;

  DrillView _view = const NoCards();
  DateTime? _shownAt;
  int? _sessionId;
  int _answered = 0;
  int _correct = 0;
  DateTime? _lastAnswerAt;

  /// The answer now corrected on screen, for *Faute de frappe*.
  ReviewOutcome? _outcome;
  int? _logId;

  /// What the screen shows now.
  DrillView get view => _view;

  SessionSummary get summary => SessionSummary(
    answered: _answered,
    correct: _correct,
    duration: (_lastAnswerAt ?? startedAt).difference(startedAt),
  );

  /// Moves on to the next card, or to what the session shows when none is
  /// left.
  Future<DrillView> next() async {
    final step = _queue.next(_clock);
    switch (step) {
      case ShowCard():
        final item = await _store.vocabularyItem(step.card.itemId);
        _shownAt = _clock.nowUtc();
        _outcome = null;
        _logId = null;
        return _view = CardQuestion(
          VocabularyCard(
            card: step.card,
            item: item,
            prompt: VocabularyPrompt.of(item, _random),
            sentence: _pick(item.sentencesToFill),
          ),
          startsFreePractice: step.startsFreePractice,
        );
      case DailyGoalReached():
        return _view = const GoalReached();
      case NoCardsAvailable():
        return _view = const NoCards();
    }
  }

  /// Grades [typed] and saves the answer. [capsGrade] means a letter went
  /// red or orange while typing, which caps the grade at Hard.
  ///
  /// A Correct answer moves straight on to the next card; any other answer
  /// shows its correction (decision 71).
  Future<DrillView> submit(String typed, {bool capsGrade = false}) async {
    final card = _question.card;
    final grade = gradeVocabulary(
      typed: typed,
      noun: card.item.answer,
      flaggedWhileTyping: capsGrade,
    );
    await _answer(card, grade, typed: typed);
    if (grade.rating == Rating.good || grade.rating == Rating.easy) {
      return await next();
    }
    return _view = CardFeedback(card, grade, typed: typed);
  }

  /// *Trop facile*, on a word seen for the first time: Easy with no answer
  /// typed, and the next card at once (decision 72).
  Future<DrillView> tooEasy() async {
    final card = _question.card;
    if (!card.offersTooEasy) throw StateError('Trop facile is not offered');
    await _answer(card, const Grade.tooEasy());
    return await next();
  }

  /// *Je ne sais pas*: Again, and the answer is shown.
  Future<DrillView> giveUp() async {
    final card = _question.card;
    final grade = Grade.gaveUp(card.item.answer.word);
    await _answer(card, grade);
    return _view = CardFeedback(card, grade);
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
    _outcome = await _regrade(
      outcome,
      logId,
      grade,
      responseTime: _responseTime,
      typed: feedback.typed,
    );
    return _view = CardFeedback(
      feedback.card,
      grade,
      typed: feedback.typed,
      overridden: true,
    );
  }

  /// *Je le connais*: the noun's cards in every drill leave practice, with
  /// no grade and no review-log row, and the next card comes at once. Keep
  /// the mark for [undoKnown].
  Future<(KnownMark, DrillView)> markKnown() async {
    final card = switch (_view) {
      CardQuestion(:final card) || CardFeedback(:final card) => card.card,
      _ => throw StateError('No card to mark known'),
    };
    final cards = await _store.cardsOfItem(card.itemId);
    final now = _clock.nowUtc();
    await _store.setKnownAt([for (final c in cards) c.id], now);
    for (final c in cards) {
      if (c.drill == drill) _queue.update(c.withKnownAt(now));
    }
    return (KnownMark(cards), await next());
  }

  /// *Annuler* after *Je le connais*: the cards come back as they were.
  Future<void> undoKnown(KnownMark mark) async {
    await _store.setKnownAt([for (final c in mark.cards) c.id], null);
    for (final c in mark.cards) {
      if (c.drill == drill) _queue.update(c.withKnownAt(null));
    }
  }

  CardQuestion get _question => switch (_view) {
    final CardQuestion q => q,
    _ => throw StateError('No card is waiting for an answer'),
  };

  Duration get _responseTime {
    final shown = _shownAt ?? startedAt;
    final time = (_lastAnswerAt ?? _clock.nowUtc()).difference(shown);
    return time.isNegative ? Duration.zero : time;
  }

  Future<void> _answer(
    VocabularyCard card,
    Grade grade, {
    String? typed,
  }) async {
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
    final logId = await _store.recordAnswer(
      Answer(
        outcome: outcome,
        sessionId: sessionId,
        responseTime: _responseTime,
        errorType: grade.errorType,
        typed: typed,
      ),
    );
    _queue.record(outcome);
    _outcome = outcome;
    _logId = logId;
    _answered++;
    if (grade.rating != Rating.again) _correct++;
  }

  /// Saves the answer [logId] again with [grade], scheduled again from the
  /// card's state before it.
  Future<ReviewOutcome> _regrade(
    ReviewOutcome outcome,
    int logId,
    Grade grade, {
    required Duration responseTime,
    String? typed,
  }) async {
    final regraded = _scheduler.regrade(outcome, grade.rating);
    await _store.replaceAnswer(
      logId,
      Answer(
        outcome: regraded,
        sessionId: _sessionId!,
        responseTime: responseTime,
        errorType: grade.errorType,
        typed: typed,
      ),
    );
    _queue.recordRegrade(regraded);
    if (outcome.rating == Rating.again && grade.rating != Rating.again) {
      _correct++;
    }
    return regraded;
  }

  /// One of [items], chosen with the session's randomness.
  T? _pick<T>(List<T> items) => items.isEmpty
      ? null
      : items[(_random() * items.length).floor().clamp(0, items.length - 1)];
}
