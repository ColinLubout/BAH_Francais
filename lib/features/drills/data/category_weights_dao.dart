import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/features/drills/data/drill_tables.drift.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:drift/drift.dart';

/// Each drill's category weights. A category with no row is Normal, so
/// setting one back to Normal removes its row.
class CategoryWeightsDao {
  CategoryWeightsDao(this._db);

  final AppDatabase _db;

  /// [drill]'s weights by category id; categories not listed are Normal.
  Future<Map<String, CategoryWeight>> weights(DrillType drill) =>
      _ofDrill(drill).get().then(_byCategory);

  Stream<Map<String, CategoryWeight>> watchWeights(DrillType drill) =>
      _ofDrill(drill).watch().map(_byCategory);

  Future<void> setWeight(
    DrillType drill,
    String categoryId,
    CategoryWeight weight,
  ) async {
    if (weight == CategoryWeight.normal) {
      await (_db.delete(_db.categoryWeights)..where(
            (w) =>
                w.drillType.equalsValue(drill) &
                w.categoryId.equals(categoryId),
          ))
          .go();
    } else {
      await _db
          .into(_db.categoryWeights)
          .insertOnConflictUpdate(
            CategoryWeightsCompanion.insert(
              drillType: drill,
              categoryId: categoryId,
              weight: weight,
            ),
          );
    }
  }

  SimpleSelectStatement<$CategoryWeightsTable, CategoryWeightRow> _ofDrill(
    DrillType drill,
  ) =>
      _db.select(_db.categoryWeights)
        ..where((w) => w.drillType.equalsValue(drill));

  static Map<String, CategoryWeight> _byCategory(
    List<CategoryWeightRow> rows,
  ) => {for (final row in rows) row.categoryId: row.weight};
}
