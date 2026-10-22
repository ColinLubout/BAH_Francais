import 'package:bah_francais/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens with every table and foreign keys on', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final keys = await database.customSelect('PRAGMA foreign_keys').getSingle();
    expect(keys.read<int>('foreign_keys'), 1);

    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((t) => t.read<String>('name')),
      containsAll([
        'categories',
        'nouns',
        'noun_categories',
        'sentence_verbs',
        'sentence_nouns',
        'verbs',
        'verb_categories',
        'verb_forms',
        'sentences',
        'images',
        'content_meta',
        'cards',
        'review_logs',
        'sessions',
        'category_weights',
      ]),
    );
  });
}
