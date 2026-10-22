import 'package:bah_francais/features/drills/data/category_weights_dao.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/content_fixture.dart';

void main() {
  test('every category is Normal until set', () async {
    final dao = CategoryWeightsDao(openDatabase());
    expect(await dao.weights(DrillType.gender), isEmpty);
  });

  test('each drill has its own weights', () async {
    final dao = CategoryWeightsDao(openDatabase());
    await dao.setWeight(DrillType.gender, 'cat.a', CategoryWeight.plus);
    await dao.setWeight(DrillType.vocabulary, 'cat.a', CategoryWeight.jamais);

    expect(await dao.weights(DrillType.gender), {'cat.a': CategoryWeight.plus});
    expect(await dao.weights(DrillType.vocabulary), {
      'cat.a': CategoryWeight.jamais,
    });
    expect(await dao.weights(DrillType.conjugation), isEmpty);
  });

  test('setting a weight again replaces it, and Normal removes it', () async {
    final db = openDatabase();
    final dao = CategoryWeightsDao(db);
    await dao.setWeight(DrillType.gender, 'cat.a', CategoryWeight.plus);
    await dao.setWeight(DrillType.gender, 'cat.a', CategoryWeight.moins);
    expect(await dao.weights(DrillType.gender), {
      'cat.a': CategoryWeight.moins,
    });

    await dao.setWeight(DrillType.gender, 'cat.a', CategoryWeight.normal);
    expect(await db.select(db.categoryWeights).get(), isEmpty);
  });

  test('weights stream as they change', () async {
    final dao = CategoryWeightsDao(openDatabase());
    final stream = dao.watchWeights(DrillType.gender);
    expect(await stream.first, isEmpty);

    await dao.setWeight(DrillType.gender, 'cat.a', CategoryWeight.jamais);
    expect(await stream.first, {'cat.a': CategoryWeight.jamais});
  });
}
