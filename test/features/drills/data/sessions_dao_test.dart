import 'package:bah_francais/features/drills/data/sessions_dao.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/content_fixture.dart';

void main() {
  final start = DateTime.utc(2026, 10, 19, 8);

  test('a session starts with no answers, ending where it starts', () async {
    final dao = SessionsDao(openDatabase());
    final id = await dao.start(drill: DrillType.gender, at: start);

    final row = (await dao.session(id))!;
    expect(row.drillType, DrillType.gender);
    expect(row.startTime, start);
    expect(row.endTime, start);
    expect((row.answered, row.correct, row.incorrect), (0, 0, 0));
  });

  test('a mixed session has no drill, stored as mixed', () async {
    final db = openDatabase();
    final dao = SessionsDao(db);
    final id = await dao.start(drill: null, at: start);
    expect((await dao.session(id))!.drillType, isNull);

    final stored = await db
        .customSelect('SELECT drill_type FROM sessions')
        .getSingle();
    expect(stored.read<String>('drill_type'), 'mixed');
  });

  test('there is no session for an unknown id', () async {
    expect(await SessionsDao(openDatabase()).session(1), isNull);
  });

  test('past sessions stream newest first', () async {
    final dao = SessionsDao(openDatabase());
    final stream = dao.watchSessions();
    expect(await stream.first, isEmpty);

    await dao.start(drill: DrillType.gender, at: start);
    await dao.start(
      drill: DrillType.vocabulary,
      at: start.add(const Duration(hours: 1)),
    );
    expect((await stream.first).map((s) => s.drillType), [
      DrillType.vocabulary,
      DrillType.gender,
    ]);
  });
}
