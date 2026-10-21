import 'package:bah_francais/features/content/data/content_tables.dart';
import 'package:bah_francais/features/content/data/content_tables.drift.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:drift/drift.dart';

/// Reads and writes content in a database with the content tables: the
/// app's, or a content pack.
class ContentStore {
  /// Takes the database and its content tables. Both databases are their
  /// own [ContentTables], so callers pass the same object twice.
  ContentStore(this._db, this._tables);

  final GeneratedDatabase _db;
  final ContentTables _tables;

  static const _versionKey = 'content_version';
  static const _releasedKey = 'released_at';
  static const _schemaKey = 'schema_version';

  /// What the installed content says about itself; null if there is none.
  Future<ContentInfo?> info() async {
    final rows = await _db.select(_tables.contentMeta).get();
    final values = {for (final row in rows) row.key: row.value};
    final version = values[_versionKey];
    if (version == null) return null;
    return ContentInfo(
      version: int.parse(version),
      releasedAt: values[_releasedKey] ?? '',
      schemaVersion: int.parse(values[_schemaKey] ?? '$contentSchemaVersion'),
    );
  }

  Future<void> writeInfo(ContentInfo info) => _db.batch(
    (batch) => batch.insertAllOnConflictUpdate(_tables.contentMeta, [
      ContentMetaCompanion.insert(key: _versionKey, value: '${info.version}'),
      ContentMetaCompanion.insert(key: _releasedKey, value: info.releasedAt),
      ContentMetaCompanion.insert(
        key: _schemaKey,
        value: '${info.schemaVersion}',
      ),
    ]),
  );

  /// Adds [content] as official rows, with its images dated [now]. Every
  /// row is written in one batch, in an order the foreign keys allow.
  Future<void> write(ContentSet content, {required DateTime now}) {
    final t = _tables;
    return _db.batch((batch) {
      batch
        ..insertAll(t.categories, [
          for (final c in content.categories)
            CategoriesCompanion.insert(
              id: c.id,
              name: c.name,
              kind: c.kind,
              sortOrder: c.sortOrder,
              everyday: Value(c.everyday),
            ),
        ])
        ..insertAll(t.nouns, [
          for (final n in content.nouns)
            NounsCompanion.insert(
              id: n.id,
              word: n.word,
              gender: n.gender,
              elides: Value(n.elides),
              pluralOnly: Value(n.pluralOnly),
              definition: Value(n.definition),
              gloss: Value(n.gloss),
              synonyms: Value(n.synonyms),
              endingHint: Value(n.endingHint),
              level: Value(n.level),
              rank: Value(n.rank),
            ),
        ])
        ..insertAll(t.nounCategories, [
          for (final n in content.nouns)
            for (final id in n.categoryIds)
              NounCategoriesCompanion.insert(nounId: n.id, categoryId: id),
        ])
        ..insertAll(t.verbs, [
          for (final v in content.verbs)
            VerbsCompanion.insert(
              id: v.id,
              infinitive: v.infinitive,
              verbGroup: v.group,
              auxiliary: v.auxiliary,
              pronominal: Value(v.pronominal),
              hAspire: Value(v.hAspire),
              level: v.level,
              rank: Value(v.rank),
            ),
        ])
        ..insertAll(t.verbCategories, [
          for (final v in content.verbs)
            for (final id in v.categoryIds)
              VerbCategoriesCompanion.insert(verbId: v.id, categoryId: id),
        ])
        ..insertAll(t.verbForms, [
          for (final v in content.verbs)
            for (final f in v.forms)
              VerbFormsCompanion.insert(
                verbId: v.id,
                tense: f.tense,
                person: f.person,
                form: f.form,
                alternatives: Value(f.alternatives),
              ),
        ])
        ..insertAll(t.sentences, [
          for (final s in content.sentences)
            SentencesCompanion.insert(
              id: s.id,
              sentenceText: s.text,
              tatoebaId: Value(s.credit?.tatoebaId),
              tatoebaAuthor: Value(s.credit?.author),
            ),
        ])
        ..insertAll(t.sentenceVerbs, [
          for (final s in content.sentences)
            for (final v in s.verbs)
              SentenceVerbsCompanion.insert(
                sentenceId: s.id,
                verbId: v.verbId,
                tense: v.tense,
                person: v.person,
                answer: v.answer,
                alternatives: Value(v.alternatives),
                before: Value(v.before),
              ),
        ])
        ..insertAll(t.sentenceNouns, [
          for (final s in content.sentences)
            for (final n in s.nouns)
              SentenceNounsCompanion.insert(
                sentenceId: s.id,
                nounId: n.nounId,
                word: n.word,
              ),
        ])
        ..insertAll(t.images, [
          for (final i in content.images)
            ImagesCompanion.insert(
              id: i.id,
              itemId: i.itemId,
              format: i.format,
              svg: Value(i.svg),
              bytes: Value(switch (i.bytes) {
                final bytes? => Uint8List.fromList(bytes),
                null => null,
              }),
              source: Value(i.credit),
              createdAt: now,
            ),
        ]);
    });
  }

  /// The official content still in use: no Perso rows, nothing retired.
  Future<ContentSet> readOfficial() async {
    final t = _tables;
    const official = ContentSource.official;

    final categories = await (_db.select(
      t.categories,
    )..where((c) => c.source.equalsValue(official) & c.retired.not())).get();
    final nouns = await (_db.select(
      t.nouns,
    )..where((n) => n.source.equalsValue(official) & n.retired.not())).get();
    final nounLinks =
        await (_db.select(t.nounCategories)
              ..where((l) => l.source.equalsValue(official) & l.retired.not())
              ..orderBy([(l) => OrderingTerm(expression: l.rowId)]))
            .get();
    final images = await (_db.select(
      t.images,
    )..orderBy([(i) => OrderingTerm(expression: i.rowId)])).get();
    final verbs = await (_db.select(
      t.verbs,
    )..where((v) => v.source.equalsValue(official) & v.retired.not())).get();
    final verbLinks =
        await (_db.select(t.verbCategories)
              ..where((l) => l.source.equalsValue(official) & l.retired.not())
              ..orderBy([(l) => OrderingTerm(expression: l.rowId)]))
            .get();
    final forms = await (_db.select(
      t.verbForms,
    )..where((f) => f.source.equalsValue(official) & f.retired.not())).get();
    final sentences = await (_db.select(
      t.sentences,
    )..where((s) => s.source.equalsValue(official) & s.retired.not())).get();
    final sentenceVerbs = await (_db.select(
      t.sentenceVerbs,
    )..where((l) => l.source.equalsValue(official) & l.retired.not())).get();
    final sentenceNouns = await (_db.select(
      t.sentenceNouns,
    )..where((l) => l.source.equalsValue(official) & l.retired.not())).get();

    final nounIds = {for (final n in nouns) n.id};
    final officialImages = [
      for (final i in images)
        if (nounIds.contains(i.itemId)) i,
    ];

    return ContentSet(
      categories: [
        for (final c in categories)
          ContentCategory(
            id: c.id,
            name: c.name,
            kind: c.kind,
            sortOrder: c.sortOrder,
            everyday: c.everyday,
          ),
      ],
      nouns: [
        for (final n in nouns)
          ContentNoun(
            id: n.id,
            word: n.word,
            gender: n.gender,
            elides: n.elides,
            pluralOnly: n.pluralOnly,
            definition: n.definition,
            gloss: n.gloss,
            synonyms: n.synonyms,
            endingHint: n.endingHint,
            // Official nouns always have a level.
            level: n.level!,
            rank: n.rank,
            categoryIds: [
              for (final l in nounLinks)
                if (l.nounId == n.id) l.categoryId,
            ],
            imageIds: [
              for (final i in officialImages)
                if (i.itemId == n.id) i.id,
            ],
          ),
      ],
      verbs: [
        for (final v in verbs)
          ContentVerb(
            id: v.id,
            infinitive: v.infinitive,
            group: v.verbGroup,
            auxiliary: v.auxiliary,
            pronominal: v.pronominal,
            hAspire: v.hAspire,
            level: v.level,
            rank: v.rank,
            categoryIds: [
              for (final l in verbLinks)
                if (l.verbId == v.id) l.categoryId,
            ],
            forms: [
              for (final f in forms)
                if (f.verbId == v.id)
                  ContentVerbForm(
                    tense: f.tense,
                    person: f.person,
                    form: f.form,
                    alternatives: f.alternatives,
                  ),
            ],
          ),
      ],
      sentences: [
        for (final s in sentences)
          ContentSentence(
            id: s.id,
            text: s.sentenceText,
            credit: s.tatoebaId == null || s.tatoebaAuthor == null
                ? null
                : SentenceCredit(
                    tatoebaId: s.tatoebaId!,
                    author: s.tatoebaAuthor!,
                  ),
            verbs: [
              for (final l in sentenceVerbs)
                if (l.sentenceId == s.id)
                  SentenceVerb(
                    verbId: l.verbId,
                    tense: l.tense,
                    person: l.person,
                    answer: l.answer,
                    alternatives: l.alternatives,
                    before: l.before,
                  ),
            ],
            nouns: [
              for (final l in sentenceNouns)
                if (l.sentenceId == s.id)
                  SentenceNoun(nounId: l.nounId, word: l.word),
            ],
          ),
      ],
      images: [for (final i in officialImages) _image(i)],
    );
  }

  /// The categories of [kind] still in use, in their listed order.
  Stream<List<ContentCategory>> watchCategories(CategoryKind kind) =>
      (_db.select(_tables.categories)
            ..where((c) => c.kind.equalsValue(kind) & c.retired.not())
            ..orderBy([
              (c) => OrderingTerm(expression: c.sortOrder),
              (c) => OrderingTerm(expression: c.id),
            ]))
          .watch()
          .map(
            (rows) => [
              for (final c in rows)
                ContentCategory(
                  id: c.id,
                  name: c.name,
                  kind: c.kind,
                  sortOrder: c.sortOrder,
                  everyday: c.everyday,
                ),
            ],
          );

  /// The everyday categories of [kind]: at most one per kind.
  Future<Set<String>> everydayCategoryIds(CategoryKind kind) async {
    final rows =
        await (_db.select(_tables.categories)..where(
              (c) => c.kind.equalsValue(kind) & c.everyday & c.retired.not(),
            ))
            .get();
    return {for (final c in rows) c.id};
  }

  /// [itemId]'s images, in the order they were added.
  Future<List<ContentImage>> images(String itemId) async {
    final rows =
        await (_db.select(_tables.images)
              ..where((i) => i.itemId.equals(itemId))
              ..orderBy([(i) => OrderingTerm(expression: i.rowId)]))
            .get();
    return [for (final row in rows) _image(row)];
  }

  static ContentImage _image(ImageRow row) => ContentImage(
    id: row.id,
    itemId: row.itemId,
    format: row.format,
    svg: row.svg,
    bytes: row.bytes,
    credit: row.source,
  );
}
