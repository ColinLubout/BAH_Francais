import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:meta/meta.dart';

/// What a drill's queue is built with: the drill's settings, and its everyday
/// categories, whose new cards come first.
@immutable
class DrillQueueSetup {
  const DrillQueueSetup({
    this.settings = const QueueSettings(),
    this.everydayCategoryIds = const {},
  });

  final QueueSettings settings;
  final Set<String> everydayCategoryIds;
}

/// What a drill session reads and saves. The data layer implements it over
/// the database; tests use a fake.
abstract interface class DrillStore {
  /// Every card of [drill], with what the queue needs about its item.
  Future<List<QueueCard>> queueCards(DrillType drill);

  /// The queue's settings for [drill]: its category weights and limits.
  Future<DrillQueueSetup> queueSetup(DrillType drill);

  /// What [day]'s answers in [drill] have used of the daily limits.
  Future<DayCounts> dayCounts(DrillType drill, StudyDay day);

  /// Starts a session, with its first answer, and returns its id.
  Future<int> startSession({required DrillType? drill, required DateTime at});

  /// Saves an answer: the card, its review-log row and the session's counts,
  /// together. Returns the row's id.
  Future<int> recordAnswer(Answer answer);

  /// Replaces the answer saved as [logId], as the override buttons do.
  Future<void> replaceAnswer(int logId, Answer answer);

  /// Every card of the item [itemId], in every drill.
  Future<List<DrillCard>> cardsOfItem(String itemId);

  /// Marks the cards known at [at], or brings them back when [at] is null.
  Future<void> setKnownAt(Iterable<int> cardIds, DateTime? at);

  /// What a Vocabulaire card needs from the noun [nounId].
  Future<VocabularyItem> vocabularyItem(String nounId);
}
