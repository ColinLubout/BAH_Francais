import 'dart:io';

import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/features/content/data/content_importer.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../tool/src/content/pack_builder.dart';
import '../../../helpers/content_fixture.dart';
import '../../../helpers/fake_clock.dart';

final importedAt = DateTime.utc(2026, 10, 19, 7);

/// A new, empty directory, deleted after the test.
Directory tempDir() {
  final dir = Directory.systemTemp.createTempSync('bah_pack_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// A pack of [content] in a new temporary file.
Future<File> packOf(
  ContentSet content, {
  ContentInfo info = const ContentInfo(version: 3, releasedAt: '2026-10-01'),
}) async {
  final file = File('${tempDir().path}/pack.sqlite');
  await buildPack(content, info, file, now: DateTime.utc(2026, 10));
  return file;
}

ContentImporter importer(AppDatabase db) =>
    ContentImporter(db, FakeClock(importedAt));

/// Whether [db] still has no content, cards or content info.
Future<void> expectEmpty(AppDatabase db) async {
  expect(await ContentStore(db, db).info(), isNull);
  expect(await db.select(db.nouns).get(), isEmpty);
  expect(await db.select(db.verbs).get(), isEmpty);
  expect(await db.select(db.cards).get(), isEmpty);
}

void main() {
  test('imports the content and its info, with New cards', () async {
    final db = openDatabase();
    final info = await importer(db).importPack((await packOf(fixture)).path);

    expect(info.version, 3);
    expect(info.releasedAt, '2026-10-01');
    expect((await ContentStore(db, db).info())!.version, 3);
    expect(
      (await ContentStore(db, db).readOfficial()).toJson(),
      fixture.toJson(),
    );

    final dao = CardsDao(db);
    expect(await dao.cards(DrillType.gender), hasLength(2));
    expect(await dao.cards(DrillType.vocabulary), hasLength(2));
    final conjugation = await dao.cards(DrillType.conjugation);
    expect(conjugation, hasLength(4));
    for (final card in conjugation) {
      expect(card.state, CardState.newCard);
      expect(card.createdAt, importedAt);
    }
  });

  test('refuses once content is installed', () async {
    final db = openDatabase();
    final pack = await packOf(fixture);
    await importer(db).importPack(pack.path);
    expect(importer(db).importPack(pack.path), throwsStateError);
  });

  test('refuses a missing file', () async {
    final db = openDatabase();
    await expectLater(
      importer(db).importPack('${tempDir().path}/none.sqlite'),
      throwsA(isA<ContentPackException>()),
    );
    await expectEmpty(db);
  });

  test('refuses a file that is not a database', () async {
    final db = openDatabase();
    final file = File('${tempDir().path}/pack.sqlite')
      ..writeAsStringSync('not a database');
    await expectLater(
      importer(db).importPack(file.path),
      throwsA(isA<ContentPackException>()),
    );
    await expectEmpty(db);
  });

  test('refuses a database that is not a content pack', () async {
    final db = openDatabase();
    final path = '${tempDir().path}/other.sqlite';
    sqlite3.open(path)
      ..execute('CREATE TABLE other (id INTEGER)')
      ..close();
    await expectLater(
      importer(db).importPack(path),
      throwsA(isA<ContentPackException>()),
    );
    await expectEmpty(db);
  });

  test('refuses a pack that needs a newer app', () async {
    final db = openDatabase();
    final pack = await packOf(
      fixture,
      info: const ContentInfo(
        version: 3,
        releasedAt: '2026-10-01',
        schemaVersion: contentSchemaVersion + 1,
      ),
    );
    await expectLater(
      importer(db).importPack(pack.path),
      throwsA(isA<ContentPackException>()),
    );
    await expectEmpty(db);
  });

  test('a failure part-way leaves nothing behind', () async {
    final db = openDatabase();
    final pack = await packOf(fixture);
    // A link to a category the pack doesn't have: the app's foreign keys
    // refuse it after the categories and nouns are written.
    sqlite3.open(pack.path)
      ..execute(
        'INSERT INTO noun_categories (noun_id, category_id) '
        "VALUES ('n.bb', 'cat.missing')",
      )
      ..close();

    await expectLater(
      importer(db).importPack(pack.path),
      throwsA(isA<Exception>()),
    );
    await expectEmpty(db);
    expect(await db.select(db.categories).get(), isEmpty);
  });
}
