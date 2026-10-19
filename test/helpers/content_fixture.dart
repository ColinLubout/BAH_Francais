import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small content set that uses every column. Its words are made-up
/// tokens, not French.
final fixture = ContentSet(
  categories: const [
    ContentCategory(
      id: 'cat.topic',
      name: 'Topic',
      kind: CategoryKind.noun,
      sortOrder: 2,
    ),
    ContentCategory(
      id: 'cat.everyday',
      name: 'Everyday',
      kind: CategoryKind.noun,
      sortOrder: 1,
      everyday: true,
    ),
    ContentCategory(
      id: 'cat.verbs',
      name: 'Verbs',
      kind: CategoryKind.verb,
      sortOrder: 1,
    ),
  ],
  nouns: const [
    ContentNoun(
      id: 'n.aa',
      word: 'aa',
      gender: Gender.feminine,
      elides: true,
      level: Level.debutant,
      rank: 1,
      definition: 'aa definition',
      gloss: 'aa gloss',
      endingHint: 'aa hint',
      synonyms: [
        Synonym('ab', gender: Gender.masculine),
        Synonym('ac'),
      ],
      categoryIds: ['cat.everyday', 'cat.topic'],
      examples: ['aa one', 'aa two'],
      imageIds: ['i.aa-1', 'i.aa-2'],
    ),
    ContentNoun(
      id: 'n.bb',
      word: 'bb',
      gender: Gender.both,
      pluralOnly: true,
      level: Level.avance,
      categoryIds: ['cat.topic'],
      examples: ['bb one'],
    ),
  ],
  verbs: [
    ContentVerb(
      id: 'v.cc',
      infinitive: 'cc',
      group: VerbGroup.irr,
      auxiliary: Auxiliary.etre,
      pronominal: true,
      hAspire: true,
      level: Level.intermediaire,
      rank: 7,
      categoryIds: const ['cat.verbs'],
      forms: [
        for (final tense in Tense.values)
          for (final person in Person.values)
            ContentVerbForm(
              tense: tense,
              person: person,
              form: 'cc ${tense.id} ${person.id}',
              alternatives: person == Person.firstSingular
                  ? ['cc alt ${tense.id}']
                  : const [],
            ),
      ],
      sentences: const [
        ContentSentence(
          id: 's.cc.1',
          tense: Tense.present,
          person: Person.firstSingular,
          text: 'cc ___ one',
          answer: 'cc present 1s',
          alternatives: ['cc alt present'],
        ),
        ContentSentence(
          id: 's.cc.2',
          tense: Tense.passeCompose,
          person: Person.thirdPlural,
          text: 'cc ___ two',
          answer: 'cc passe_compose 3p',
        ),
      ],
    ),
  ],
  images: const [
    ContentImage(
      id: 'i.aa-1',
      itemId: 'n.aa',
      format: ImageFormat.svg,
      svg: '<svg viewBox="0 0 1 1"/>',
      credit: 'aa credit',
    ),
    ContentImage(
      id: 'i.aa-2',
      itemId: 'n.aa',
      format: ImageFormat.png,
      bytes: [1, 2, 3],
    ),
  ],
);

/// An in-memory app database, closed after the test.
AppDatabase openDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// An in-memory app database holding [content], as official rows.
Future<AppDatabase> databaseWith(ContentSet content) async {
  final db = openDatabase();
  await ContentStore(db, db).write(content, now: DateTime.utc(2026, 10, 19));
  return db;
}
