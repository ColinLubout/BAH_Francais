import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/data/content_tables.drift.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/content_fixture.dart';

void main() {
  test('official content reads back as it was written', () async {
    final db = await databaseWith(fixture);
    final read = await ContentStore(db, db).readOfficial();
    expect(read.toJson(), fixture.toJson());
  });

  test('a noun’s categories and images keep their order', () async {
    final db = await databaseWith(fixture);
    final noun = (await ContentStore(
      db,
      db,
    ).readOfficial()).nouns.firstWhere((n) => n.id == 'n.aa');
    expect(noun.categoryIds, ['cat.everyday', 'cat.topic']);
    expect(noun.imageIds, ['i.aa-1', 'i.aa-2']);
  });

  test('a sentence reads back with its verbs and nouns', () async {
    final db = await databaseWith(fixture);
    final sentences = {
      for (final s in (await ContentStore(db, db).readOfficial()).sentences)
        s.id: s,
    };
    final one = sentences['s.one']!;
    expect(one.text, 'one cc present 1s aa');
    expect(one.verbs.single.answer, 'cc present 1s');
    expect(one.verbs.single.alternatives, ['cc alt present']);
    expect(one.nouns.single.nounId, 'n.aa');
    expect(one.credit?.tatoebaId, 1234);
    expect(one.credit?.author, 'someone');
    expect(sentences['s.two']!.verbs.single.before, 'la');
    expect(sentences['s.two']!.credit, isNull);
    expect(sentences['s.three']!.verbs, isEmpty);
    expect(sentences['s.three']!.nouns.map((n) => n.word), ['aa', 'bbs']);
  });

  test('Perso and retired rows are not official content', () async {
    final db = await databaseWith(fixture);
    await db
        .into(db.nouns)
        .insert(
          NounsCompanion.insert(
            id: 'p.mine',
            word: 'mine',
            gender: Gender.masculine,
            source: const Value(ContentSource.perso),
          ),
        );
    await (db.update(db.nouns)..where((n) => n.id.equals('n.bb'))).write(
      const NounsCompanion(retired: Value(true)),
    );
    // The user's own sentence, and their own use of an official one.
    await db
        .into(db.sentences)
        .insert(
          SentencesCompanion.insert(
            id: 'p.sentence',
            sentenceText: 'mine cc present 1p',
            source: const Value(ContentSource.perso),
          ),
        );
    await db
        .into(db.sentenceVerbs)
        .insert(
          SentenceVerbsCompanion.insert(
            sentenceId: 's.three',
            verbId: 'v.cc',
            tense: Tense.imparfait,
            person: Person.firstPlural,
            answer: 'cc imparfait 1p',
            source: const Value(ContentSource.perso),
          ),
        );

    final read = await ContentStore(db, db).readOfficial();
    expect([for (final n in read.nouns) n.id], ['n.aa']);
    expect(
      read.sentences.map((s) => s.id),
      unorderedEquals(['s.one', 's.two', 's.three']),
    );
    expect(read.sentences.firstWhere((s) => s.id == 's.three').verbs, isEmpty);
  });

  test('a database with no content has no content info', () async {
    final db = openDatabase();
    expect(await ContentStore(db, db).info(), isNull);
  });

  test('content info reads back, and writing it again replaces it', () async {
    final db = openDatabase();
    final store = ContentStore(db, db);
    await store.writeInfo(
      const ContentInfo(version: 14, releasedAt: '2026-10-01'),
    );
    await store.writeInfo(
      const ContentInfo(version: 15, releasedAt: '2026-11-01'),
    );
    final info = (await store.info())!;
    expect(info.version, 15);
    expect(info.releasedAt, '2026-11-01');
    expect(info.schemaVersion, contentSchemaVersion);
  });

  test('categories of a kind stream in their listed order', () async {
    final db = await databaseWith(fixture);
    final store = ContentStore(db, db);
    final stream = store.watchCategories(CategoryKind.noun);

    expect((await stream.first).map((c) => c.id), [
      'cat.everyday',
      'cat.topic',
    ]);
    await (db.update(db.categories)..where((c) => c.id.equals('cat.topic')))
        .write(const CategoriesCompanion(retired: Value(true)));
    expect((await stream.first).map((c) => c.id), ['cat.everyday']);
  });

  test('the everyday categories of each kind', () async {
    final db = await databaseWith(fixture);
    final store = ContentStore(db, db);
    expect(await store.everydayCategoryIds(CategoryKind.noun), {
      'cat.everyday',
    });
    expect(await store.everydayCategoryIds(CategoryKind.verb), isEmpty);
  });

  test('an item’s images, in the order they were added', () async {
    final db = await databaseWith(fixture);
    final images = await ContentStore(db, db).images('n.aa');
    expect(images.map((i) => i.id), ['i.aa-1', 'i.aa-2']);
    expect(images.first.svg, '<svg viewBox="0 0 1 1"/>');
    expect(images.first.credit, 'aa credit');
    expect(images.last.bytes, [1, 2, 3]);
    expect(await ContentStore(db, db).images('n.bb'), isEmpty);
  });

  group('an image is an SVG with markup or a PNG or JPEG with bytes', () {
    Future<void> insert(ImageFormat format, {String? svg, List<int>? bytes}) =>
        databaseWith(fixture).then(
          (db) => db
              .into(db.images)
              .insert(
                ImagesCompanion.insert(
                  id: 'i.other',
                  itemId: 'n.bb',
                  format: format,
                  svg: Value(svg),
                  bytes: Value(
                    bytes == null ? null : Uint8List.fromList(bytes),
                  ),
                  createdAt: DateTime.utc(2026),
                ),
              ),
        );

    test('an SVG with bytes is refused', () {
      expect(
        insert(ImageFormat.svg, svg: '<svg/>', bytes: [1]),
        throwsA(isA<Exception>()),
      );
    });

    test('a PNG with markup is refused', () {
      expect(insert(ImageFormat.png, svg: '<svg/>'), throwsA(isA<Exception>()));
    });

    test('an image with neither is refused', () {
      expect(insert(ImageFormat.jpeg), throwsA(isA<Exception>()));
    });
  });

  test('a link to a missing category is refused', () async {
    final db = await databaseWith(fixture);
    expect(
      db
          .into(db.nounCategories)
          .insert(
            NounCategoriesCompanion.insert(
              nounId: 'n.bb',
              categoryId: 'cat.missing',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a noun deletes its links and images', () async {
    final db = await databaseWith(fixture);
    await (db.delete(db.nouns)..where((n) => n.id.equals('n.aa'))).go();
    expect(await db.select(db.images).get(), isEmpty);
    expect((await db.select(db.sentenceNouns).get()).map((l) => l.nounId), [
      'n.bb',
    ]);
    expect((await db.select(db.nounCategories).get()).map((l) => l.nounId), [
      'n.bb',
    ]);
    // The sentences stay: they can be used by other words.
    expect(await db.select(db.sentences).get(), hasLength(3));
  });

  test('deleting a sentence deletes its links', () async {
    final db = await databaseWith(fixture);
    await (db.delete(db.sentences)..where((s) => s.id.equals('s.one'))).go();
    expect((await db.select(db.sentenceVerbs).get()).map((l) => l.sentenceId), [
      's.two',
    ]);
    expect((await db.select(db.sentenceNouns).get()).map((l) => l.sentenceId), [
      's.three',
      's.three',
    ]);
  });
}
