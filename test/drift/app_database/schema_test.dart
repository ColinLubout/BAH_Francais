// The app's schema against the versions dumped in drift_schemas/.
//
// Every schema change raises AppDatabase.schemaVersion, adds a migration,
// and is dumped with `dart run drift_dev make-migrations`. That command also
// writes a migration test template here: fill it in so the test opens a
// database at the previous version, with data, and checks the data survives.

import 'package:bah_francais/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('the schema version is the latest one dumped', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, GeneratedHelper.versions.last);
  });

  test('the tables match the dumped schema of their version', () async {
    final version = GeneratedHelper.versions.last;
    final schema = await verifier.schemaAt(version);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, version);
  });
}
