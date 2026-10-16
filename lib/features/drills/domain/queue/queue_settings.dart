import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:meta/meta.dart';

/// How often a category's new cards come up, relative to the others.
enum CategoryWeight {
  /// None, and the category's cards are paused: not even reviewed.
  jamais('jamais', 0),
  moins('moins', 0.5),
  normal('normal', 1),
  plus('plus', 2);

  CategoryWeight(this.id, this.share);

  /// The value stored in the database.
  final String id;

  /// The category's share of new cards.
  final double share;
}

/// The parts of a drill's settings that decide which card comes next.
@immutable
class QueueSettings {
  const QueueSettings({
    this.newPerDay = defaultNewPerDay,
    this.maxReviewsPerDay,
    this.categoryWeights = const {},
    this.enabledTenses = const {...Tense.values},
    this.enabledGroups = const {...VerbGroup.values},
  }) : assert(
         newPerDay >= 0 && newPerDay <= maxNewPerDay,
         'Nouvelles cartes par jour is 0–$maxNewPerDay',
       ),
       assert(
         maxReviewsPerDay == null ||
             (maxReviewsPerDay >= minReviewLimit &&
                 maxReviewsPerDay <= maxReviewLimit),
         'Révisions max par jour is unlimited or '
         '$minReviewLimit–$maxReviewLimit',
       );

  static const defaultNewPerDay = 15;
  static const maxNewPerDay = 100;
  static const minReviewLimit = 10;
  static const maxReviewLimit = 999;

  /// Nouvelles cartes par jour, across all of the drill's categories.
  final int newPerDay;

  /// Révisions max par jour; null is unlimited.
  final int? maxReviewsPerDay;

  /// Weights by category id. A category not listed is [CategoryWeight.normal].
  final Map<String, CategoryWeight> categoryWeights;

  /// Conjugaison: the tenses practised. Cards of other tenses are paused.
  final Set<Tense> enabledTenses;

  /// Conjugaison: the verb groups practised. Other verbs' cards are paused.
  final Set<VerbGroup> enabledGroups;

  CategoryWeight weightOf(String categoryId) =>
      categoryWeights[categoryId] ?? CategoryWeight.normal;
}
