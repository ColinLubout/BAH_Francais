import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:meta/meta.dart';

/// A card with what the queue needs to know about its item.
@immutable
class QueueCard {
  const QueueCard({
    required this.card,
    this.categoryIds = const [],
    this.level,
    this.rank,
    this.isPerso = false,
    this.retired = false,
    this.verbGroup,
  });

  final DrillCard card;

  /// The item's categories: several for a noun in more than one.
  final List<String> categoryIds;

  /// Official items only.
  final Level? level;

  /// Frequency rank, 1 the most common; official items only.
  final int? rank;

  /// The user's own word. Perso words come first among all new cards, oldest
  /// first, since the user added them to learn them.
  final bool isPerso;

  /// Removed from the official content: never scheduled.
  final bool retired;

  /// Conjugation cards only.
  final VerbGroup? verbGroup;

  QueueCard withCard(DrillCard card) => QueueCard(
    card: card,
    categoryIds: categoryIds,
    level: level,
    rank: rank,
    isPerso: isPerso,
    retired: retired,
    verbGroup: verbGroup,
  );

  /// Whether the card is scheduled at all under [settings]: not known, not
  /// retired, not in a paused tense or verb group, and not only in
  /// categories set to Jamais.
  bool isScheduled(QueueSettings settings) {
    if (card.isKnown || retired) return false;
    final tense = card.tense;
    if (tense != null && !settings.enabledTenses.contains(tense)) return false;
    final group = verbGroup;
    if (group != null && !settings.enabledGroups.contains(group)) return false;
    if (categoryIds.isEmpty) return true;
    return categoryIds.any(
      (id) => settings.weightOf(id) != CategoryWeight.jamais,
    );
  }
}
