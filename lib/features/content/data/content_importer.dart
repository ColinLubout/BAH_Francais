import 'dart:io';

import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/features/content/data/content_pack_database.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Why a content pack can't be imported.
class ContentPackException implements Exception {
  const ContentPackException(this.message);

  final String message;

  @override
  String toString() => 'ContentPackException: $message';
}

/// Imports a content pack into a database with no content yet: the bundled
/// pack, on the first launch. Content updates merge instead (milestone 7).
class ContentImporter {
  ContentImporter(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Imports the pack at [path], with New cards for every noun, and for
  /// every verb in each tense the pack teaches, and returns what the pack
  /// says about itself.
  ///
  /// The pack is opened read-only and everything is written in one
  /// transaction, so a failure, or the app closing, leaves nothing behind
  /// and the import starts again next time.
  Future<ContentInfo> importPack(String path) async {
    final app = ContentStore(_db, _db);
    if (await app.info() != null) {
      throw StateError('Content is already installed: updates merge');
    }
    if (!File(path).existsSync()) {
      throw ContentPackException('No content pack at $path');
    }

    final ContentPackDatabase pack;
    try {
      pack = ContentPackDatabase(
        NativeDatabase.opened(sqlite3.open(path, mode: OpenMode.readOnly)),
      );
    } on SqliteException catch (e) {
      throw ContentPackException('Not a content pack: ${e.message}');
    }
    try {
      final store = ContentStore(pack, pack);
      final ContentInfo? info;
      final ContentSet content;
      try {
        info = await store.info();
        content = await store.readOfficial();
      } on Exception catch (e) {
        throw ContentPackException('Not a content pack: $e');
      }
      if (info == null) {
        throw const ContentPackException('Not a content pack: no version');
      }
      if (info.schemaVersion > contentSchemaVersion) {
        throw ContentPackException(
          'The pack needs content schema ${info.schemaVersion}; '
          'this app reads $contentSchemaVersion',
        );
      }

      final now = _clock.nowUtc();
      await _db.transaction(() async {
        await app.write(content, now: now);
        await app.writeInfo(info!);
        await CardsDao(_db).createCards(
          at: now,
          nounIds: [for (final n in content.nouns) n.id],
          verbIds: [for (final v in content.verbs) v.id],
          tenses: content.tenses,
        );
      });
      return info;
    } finally {
      await pack.close();
    }
  }
}
