import 'dart:io';

import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/content_importer.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bundled_content.g.dart';

/// The content pack every build ships with, built from `content/` with
/// `dart run tool/content_build.dart content --version <n> --out <this>`.
const bundledPackAsset = 'assets/content/content-pack.sqlite';

/// Imports the bundled pack on the first launch, when the database has no
/// content yet (Content updates → First launch). The import runs in one
/// transaction, so one cut short by the app closing leaves nothing and
/// starts again on the next launch.
class BundledContent {
  BundledContent(this._db, this._clock, this._loadAsset, this._tempDir);

  final AppDatabase _db;
  final Clock _clock;
  final Future<ByteData> Function(String key) _loadAsset;
  final Directory _tempDir;

  /// The installed content's info, importing the bundled pack first if
  /// nothing is installed.
  Future<ContentInfo> ensureImported() async {
    final installed = await ContentStore(_db, _db).info();
    if (installed != null) return installed;
    // SQLite opens files, not assets: the pack goes to a temporary file,
    // deleted once imported or rejected.
    final bytes = await _loadAsset(bundledPackAsset);
    final file = File('${_tempDir.path}/bundled-content-pack.sqlite');
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    try {
      return await ContentImporter(_db, _clock).importPack(file.path);
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }
}

/// The content, ready for the drills: the bundled pack imported on the first
/// launch. Drills wait for it; Accueil shows *Préparation du contenu…*.
@Riverpod(keepAlive: true)
Future<ContentInfo> contentReady(Ref ref) => BundledContent(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
  rootBundle.load,
  Directory.systemTemp,
).ensureImported();
