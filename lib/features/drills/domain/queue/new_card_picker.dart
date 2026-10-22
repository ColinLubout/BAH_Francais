import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';

/// Picks the next new card.
///
/// The user's own (Perso) words come first, oldest first. Then come the
/// everyday categories' cards, the universally useful words, while any are
/// left. Then a category is chosen at random, weighted by its setting (Moins
/// 0.5, Normal 1, Plus 2), among the categories that still have new cards.
/// Within a category, cards go by level (débutant → intermédiaire → avancé),
/// then, for conjugation cards, by tense (présent → passé composé → imparfait
/// → futur simple), then by frequency rank. A card in several categories can
/// come through any of them not set to Jamais, and a category set to Jamais
/// gives none, Perso and everyday included.
class NewCardPicker {
  /// [_random] gives a number from 0 up to (not including) 1; tests pass
  /// fixed values. [everydayCategoryIds] are the content's everyday
  /// categories.
  NewCardPicker(this._random, {this.everydayCategoryIds = const {}});

  final double Function() _random;
  final Set<String> everydayCategoryIds;

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

    final perso = {
      for (final pool in pools.values)
        for (final card in pool)
          if (card.isPerso) card,
    };
    if (perso.isNotEmpty) {
      return (perso.toList()..sort(comparePersoCards)).first;
    }

    // A stable order, so the same random number always picks the same pool.
    final everyday = pools.keys.where(everydayCategoryIds.contains).toList();
    final categories = (everyday.isEmpty ? pools.keys.toList() : everyday)
      ..sort();
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

/// The order of the user's own new words: oldest first.
int comparePersoCards(QueueCard a, QueueCard b) {
  final byAdded = a.card.createdAt.compareTo(b.card.createdAt);
  if (byAdded != 0) return byAdded;
  return a.card.id.compareTo(b.card.id);
}

/// The order of official new cards within a category.
int compareNewCards(QueueCard a, QueueCard b) {
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
