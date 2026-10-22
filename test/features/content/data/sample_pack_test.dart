// The milestone 2 check: the sample pack builds, imports and reads back
// unchanged.

import 'dart:io';

import 'package:bah_francais/features/content/data/content_importer.dart';
import 'package:bah_francais/features/content/data/content_pack_database.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/src/content/content_files.dart';
import '../../../../tool/src/content/content_validator.dart';
import '../../../../tool/src/content/pack_builder.dart';
import '../../../helpers/content_fixture.dart';
import '../../../helpers/fake_clock.dart';

void main() {
  final report = validateContent(
    ContentFiles.read(Directory('content/sample')),
    ContentSchemas.read(Directory('content/schema')),
  );
  final sample = report.content;

  test('the sample content is valid, with no warnings', () {
    expect(report.errors, isEmpty);
    expect(report.warnings, isEmpty);
  });

  test('the sample is 3 noun categories of 10 nouns and 5 verbs', () {
    final nounCategories = sample.categories.where((c) => c.kind.id == 'noun');
    expect(nounCategories, hasLength(3));
    for (final category in nounCategories) {
      expect(
        sample.nouns.where((n) => n.categoryIds.first == category.id),
        hasLength(10),
      );
    }
    expect(sample.verbs, hasLength(5));
    for (final verb in sample.verbs) {
      expect(verb.forms, hasLength(24));
      final uses = {
        for (final s in sample.sentences)
          for (final v in s.verbs)
            if (v.verbId == verb.id) (v.tense, v.person),
      };
      expect(uses, hasLength(24), reason: verb.id);
    }
  });

  test('some sentences serve several words', () {
    expect(
      sample.sentences.where((s) => s.verbs.length + s.nouns.length > 1),
      isNotEmpty,
    );
  });

  test('the sample pack builds, imports and reads back unchanged', () async {
    final dir = Directory.systemTemp.createTempSync('bah_sample_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/content-pack.sqlite');
    await buildPack(
      sample,
      const ContentInfo(version: 1, releasedAt: '2026-10-19'),
      file,
      now: DateTime.utc(2026, 10, 19),
    );

    final pack = ContentPackDatabase(NativeDatabase(file));
    final inPack = await ContentStore(pack, pack).readOfficial();
    await pack.close();
    expect(inPack.toJson(), sample.toJson());

    final db = openDatabase();
    final info = await ContentImporter(
      db,
      FakeClock(DateTime.utc(2026, 10, 19, 7)),
    ).importPack(file.path);
    expect(info.version, 1);
    expect(info.releasedAt, '2026-10-19');
    expect(
      (await ContentStore(db, db).readOfficial()).toJson(),
      sample.toJson(),
    );
    // Genre and Vocabulaire for 30 nouns, four tenses for 5 verbs.
    expect(await db.select(db.cards).get(), hasLength(30 * 2 + 5 * 4));
  });
}
