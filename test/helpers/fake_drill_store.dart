import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/session/conjugation_item.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';

/// A store in memory that records what the session saves.
class FakeStore implements DrillStore {
  FakeStore({
    required this.cards,
    this.items = const {},
    this.verbs = const {},
    this.setup = const DrillQueueSetup(),
    this.counts = const DayCounts(),
  });

  final List<DrillCard> cards;
  final Map<String, NounItem> items;

  /// Conjugaison items, by verb id and tense.
  final Map<(String, Tense), ConjugationItem> verbs;
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
  Future<NounItem> nounItem(String nounId) async => items[nounId]!;

  @override
  Future<ConjugationItem> conjugationItem(String verbId, Tense tense) async =>
      verbs[(verbId, tense)]!;
}
