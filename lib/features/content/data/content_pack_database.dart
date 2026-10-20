import 'package:bah_francais/features/content/data/content_pack_database.drift.dart';
import 'package:bah_francais/features/content/data/content_tables.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:drift/drift.dart';

/// A content pack: one SQLite file holding the app's content tables, built
/// by `tool/content_build.dart` and imported by the app.
///
/// Pure Dart, with no Flutter import, so the build tool can use it.
@DriftDatabase(
  tables: [
    Categories,
    Nouns,
    NounCategories,
    Verbs,
    VerbCategories,
    VerbForms,
    Sentences,
    SentenceVerbs,
    SentenceNouns,
    Images,
    ContentMeta,
  ],
)
class ContentPackDatabase extends $ContentPackDatabase
    implements ContentTables {
  ContentPackDatabase(super.e);

  /// A pack is always built fresh at its version and never migrated.
  @override
  int get schemaVersion => contentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
