import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';

/// Picks the next new card.
///
/// A category is chosen at random, weighted by its setting (Moins 0.5,
/// Normal 1, Plus 2), among the categories that still have new cards. Within
/// it, Perso words come first, oldest first; then official items by level
/// (débutant → intermédiaire → avancé), then, for conjugation cards, by tense
/// (présent → passé composé → imparfait → futur simple), then by frequency
/// rank. A noun in several categories can come through any of them not set
/// to Jamais.
class NewCardPicker {
  /// [_random] gives a number from 0 up to (not including) 1; tests pass
  /// fixed values.
  NewCardPicker(this._random);

  final double Function() _random;

  /// The next new card among [candidates] (new, scheduled cards), or null.
  QueueCard? pick(List<QueueCard> candidates, QueueSettings settings) {
    final pools = <String, List<QueueCard>>{};
    for (final candidate in candidates) {
      final ids = candidate.categoryIds.isEmpty
          ? const ['']
          : candidate.categoryIds;
      for (final id in ids) {
        if (settings.weightOf(id) == CategoryWeight.jamais) continue;
        (pools[id] ??= []).add(candidate);
      }
    }
    if (pools.isEmpty) return null;

    // A stable order, so the same random number always picks the same pool.
    final categories = pools.keys.toList()..sort();
    final total = categories.fold<double>(
      0,
      (sum, id) => sum + settings.weightOf(id).share,
    );
    var roll = _random() * total;
    var chosen = categories.last;
    for (final id in categories) {
      roll -= settings.weightOf(id).share;
      if (roll < 0) {
        chosen = id;
        break;
      }
    }

    final pool = pools[chosen]!..sort(compareNewCards);
    return pool.first;
  }
}

/// The order of new cards within a category.
int compareNewCards(QueueCard a, QueueCard b) {
  if (a.isPerso != b.isPerso) return a.isPerso ? -1 : 1;
  if (a.isPerso) {
    final byAdded = a.card.createdAt.compareTo(b.card.createdAt);
    if (byAdded != 0) return byAdded;
    return a.card.id.compareTo(b.card.id);
  }
  final byLevel = _compareNullsLast(a.level?.index, b.level?.index);
  if (byLevel != 0) return byLevel;
  final byTense = _compareNullsLast(a.card.tense?.index, b.card.tense?.index);
  if (byTense != 0) return byTense;
  final byRank = _compareNullsLast(a.rank, b.rank);
  if (byRank != 0) return byRank;
  final byItem = a.card.itemId.compareTo(b.card.itemId);
  if (byItem != 0) return byItem;
  return a.card.id.compareTo(b.card.id);
}

int _compareNullsLast(int? a, int? b) {
  if (a == b) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
