import 'package:bah_francais/features/drills/domain/card.dart';

/// A display-only level shown in the word and verb lists and in the stats.
/// It never affects scheduling.
enum MasteryLevel {
  /// Nouveau: never reviewed.
  newCard,

  /// En apprentissage: in learning or relearning steps.
  learning,

  /// Fragile: stability under 7 days.
  fragile,

  /// Acquis: stability from 7 to 90 days.
  acquired,

  /// Maîtrisé: stability over 90 days.
  mastered,

  /// Connu: marked known by the user.
  known;

  static MasteryLevel of(DrillCard card) {
    if (card.isKnown) return known;
    return switch (card.state) {
      CardState.newCard => newCard,
      CardState.learning || CardState.relearning => learning,
      CardState.review => switch (card.stability!) {
        < 7 => fragile,
        <= 90 => acquired,
        _ => mastered,
      },
    };
  }
}
