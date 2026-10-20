import 'package:bah_francais/core/database/app_database.drift.dart';
import 'package:bah_francais/features/content/data/content_tables.dart';
import 'package:bah_francais/features/drills/data/drill_tables.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

/// The app's SQLite database. Everything the app stores lives here, on the
/// device.
///
/// Every schema change raises [schemaVersion], ships with a migration, and
/// is dumped with `dart run drift_dev make-migrations` so a test can open
/// the previous version. Nothing may drop or rebuild a table holding review
/// history.
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
    Cards,
    ReviewLogs,
    Sessions,
    CategoryWeights,
  ],
)
class AppDatabase extends $AppDatabase implements ContentTables {
  /// Opens the database file on the device, or [executor] if given (tests
  /// pass an in-memory database).
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bah_francais'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
