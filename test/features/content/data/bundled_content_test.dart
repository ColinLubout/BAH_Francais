import 'dart:io';
import 'dart:typed_data';

import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/content/data/content_pack_database.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/src/content/content_files.dart';
import '../../../../tool/src/content/content_validator.dart';
import '../../../helpers/content_fixture.dart';
import '../../../helpers/fake_clock.dart';

final pack = File(bundledPackAsset);

/// Reads the bundled pack's file, as the app reads the asset.
Future<ByteData> loadAsset(String key) async {
  expect(key, bundledPackAsset);
  return ByteData.sublistView(pack.readAsBytesSync());
}

void main() {
  test('the bundled pack is the content in content/, as version 1', () async {
    final content = validateContent(
      ContentFiles.read(Directory('content')),
      ContentSchemas.read(Directory('content/schema')),
    ).content;
    final db = ContentPackDatabase(NativeDatabase(pack));
    addTearDown(db.close);
    final store = ContentStore(db, db);
    expect(
      (await store.readOfficial()).toJson(),
      content.toJson(),
      reason:
          'Rebuild it: dart run tool/content_build.dart content --version 1 '
          '--out $bundledPackAsset',
    );
    expect((await store.info())!.version, 1);
  });

  group('the first launch', () {
    late Directory temp;
    setUp(() {
      temp = Directory.systemTemp.createTempSync('bah_bundled_');
      addTearDown(() => temp.deleteSync(recursive: true));
    });

    test('imports the bundled pack, with its cards, and tidies up', () async {
      final db = openDatabase();
      final info = await BundledContent(
        db,
        FakeClock(DateTime.utc(2026, 10, 22)),
        loadAsset,
        temp,
      ).ensureImported();

      expect(info.version, 1);
      final dao = CardsDao(db);
      final nouns = (await ContentStore(db, db).readOfficial()).nouns;
      expect(await dao.cards(DrillType.vocabulary), hasLength(nouns.length));
      expect(temp.listSync(), isEmpty, reason: 'the temporary copy is gone');
    });

    test('does nothing once content is installed', () async {
      final db = openDatabase();
      final bundled = BundledContent(
        db,
        FakeClock(DateTime.utc(2026, 10, 22)),
        loadAsset,
        temp,
      );
      await bundled.ensureImported();
      final cards = await CardsDao(db).cards(DrillType.vocabulary);

      final again = await BundledContent(
        db,
        FakeClock(DateTime.utc(2026, 10, 23)),
        (_) => fail('the asset is not read again'),
        temp,
      ).ensureImported();
      expect(again.version, 1);
      expect(await CardsDao(db).cards(DrillType.vocabulary), cards);
    });
  });
}
