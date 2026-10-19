import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:flutter_test/flutter_test.dart';

ContentNoun noun(String id, {List<String> categories = const ['cat.b']}) =>
    ContentNoun(
      id: id,
      word: id,
      gender: Gender.masculine,
      level: Level.debutant,
      categoryIds: categories,
      examples: const ['one'],
    );

void main() {
  test('example ids number the examples from 01', () {
    expect(ContentNoun.exampleId('n.aa', 0), 'n.aa.ex01');
    expect(ContentNoun.exampleId('n.aa', 11), 'n.aa.ex12');
  });

  test('an official image’s id is its file name without the extension', () {
    expect(ContentImage.idFor('fourchette-1.svg'), 'i.fourchette-1');
    expect(ContentImage.idFor('dessin'), 'i.dessin');
  });

  test('an SVG has markup and no bytes; a PNG or JPEG has bytes', () {
    expect(
      () => ContentImage(
        id: 'i.a',
        itemId: 'n.a',
        format: ImageFormat.svg,
        bytes: const [1],
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ContentImage(
        id: 'i.a',
        itemId: 'n.a',
        format: ImageFormat.png,
        svg: '<svg/>',
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a verb has a form per tense and person, or none', () {
    const form = ContentVerbForm(
      tense: Tense.imparfait,
      person: Person.secondPlural,
      form: 'f',
    );
    const verb = ContentVerb(
      id: 'v.a',
      infinitive: 'a',
      group: VerbGroup.er,
      auxiliary: Auxiliary.avoir,
      level: Level.debutant,
      categoryIds: ['cat.v'],
      forms: [form],
      sentences: [],
    );
    expect(verb.form(Tense.imparfait, Person.secondPlural), form);
    expect(verb.form(Tense.present, Person.secondPlural), isNull);
  });

  test('two sets compare equal whatever order they were read in', () {
    final a = ContentSet(
      nouns: [
        noun('n.b', categories: ['cat.y', 'cat.x']),
        noun('n.a'),
      ],
    );
    final b = ContentSet(
      nouns: [
        noun('n.a'),
        noun('n.b', categories: ['cat.x', 'cat.y']),
      ],
    );
    expect(a.toJson(), b.toJson());
    expect((a.toJson()['nouns']! as List).map((n) => (n as Map)['id']), [
      'n.a',
      'n.b',
    ]);
  });

  test('a synonym stores only what differs from its noun', () {
    expect(synonymToJson(const Synonym('auto')), {'word': 'auto'});
    expect(
      synonymToJson(
        const Synonym('bicyclette', gender: Gender.feminine, elides: false),
      ),
      {'word': 'bicyclette', 'gender': 'f', 'elides': false},
    );
  });

  test('content info defaults to the app’s content schema', () {
    const info = ContentInfo(version: 2, releasedAt: '2026-10-01');
    expect(info.schemaVersion, contentSchemaVersion);
  });

  group('content types', () {
    test('only the passé composé is compound', () {
      expect(
        [
          for (final t in Tense.values)
            if (t.isCompound) t,
        ],
        [Tense.passeCompose],
      );
    });

    test('ids are the values content files use', () {
      expect(Person.values.map((p) => p.id), [
        '1s',
        '2s',
        '3s',
        '1p',
        '2p',
        '3p',
      ]);
      expect(Auxiliary.values.map((a) => a.id), ['avoir', 'etre']);
      expect(CategoryKind.values.map((k) => k.id), ['noun', 'verb']);
      expect(ContentSource.values.map((s) => s.id), ['official', 'perso']);
      expect(ImageFormat.values.map((f) => f.id), ['svg', 'png', 'jpeg']);
    });

    test('a value is found by its id', () {
      expect(byId(Person.values, '3p', (p) => p.id), Person.thirdPlural);
      expect(byId(Person.values, '4p', (p) => p.id), isNull);
    });
  });
}
