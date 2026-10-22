import 'dart:io';

import 'package:bah_francais/features/content/data/content_pack_database.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:drift/native.dart';

/// Writes [content] and [info] to a new content pack at [out], replacing
/// any file there. [now] dates the images.
Future<void> buildPack(
  ContentSet content,
  ContentInfo info,
  File out, {
  required DateTime now,
}) async {
  if (out.existsSync()) out.deleteSync();
  out.parent.createSync(recursive: true);
  final pack = ContentPackDatabase(NativeDatabase(out));
  try {
    await pack.transaction(() async {
      final store = ContentStore(pack, pack);
      await store.write(content, now: now);
      await store.writeInfo(info);
    });
  } finally {
    await pack.close();
  }
}
