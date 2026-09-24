import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';

/// 12:00 in Paris (UTC+2) on 24 September 2026.
final noon = DateTime.utc(2026, 9, 24, 10);
const paris = Duration(hours: 2);
final today = StudyDay.of(noon, paris);

var _nextId = 1;

/// A new card; pass [drill] and [tense] for conjugation.
DrillCard newCard({
  String itemId = 'n.item',
  DrillType drill = DrillType.vocabulary,
  Tense? tense,
  int? id,
  DateTime? createdAt,
}) => DrillCard(
  id: id ?? _nextId++,
  itemId: itemId,
  drill: drill,
  tense: drill == DrillType.conjugation ? (tense ?? Tense.present) : null,
  createdAt: createdAt ?? DateTime.utc(2026),
);

/// A card in the review state.
DrillCard reviewCard({
  required DateTime due,
  double stability = 10,
  DateTime? lastReview,
  String itemId = 'n.item',
  DrillType drill = DrillType.vocabulary,
  Tense? tense,
  int? id,
  DateTime? knownAt,
}) => DrillCard(
  id: id ?? _nextId++,
  itemId: itemId,
  drill: drill,
  tense: drill == DrillType.conjugation ? (tense ?? Tense.present) : null,
  createdAt: DateTime.utc(2026),
  state: CardState.review,
  stability: stability,
  difficulty: 5,
  due: due,
  lastReview: lastReview ?? due.subtract(Duration(days: stability.round())),
  reps: 3,
  knownAt: knownAt,
);

/// A card in a learning step, due at [due].
DrillCard learningCard({
  required DateTime due,
  String itemId = 'n.item',
  DrillType drill = DrillType.vocabulary,
  CardState state = CardState.learning,
  int? id,
}) => DrillCard(
  id: id ?? _nextId++,
  itemId: itemId,
  drill: drill,
  tense: drill == DrillType.conjugation ? Tense.present : null,
  createdAt: DateTime.utc(2026),
  state: state,
  step: 0,
  stability: 1,
  difficulty: 5,
  due: due,
  lastReview: due.subtract(const Duration(minutes: 1)),
  reps: 1,
);
