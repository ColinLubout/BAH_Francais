// The real content in content/: so far the everyday categories.

import 'dart:io';

import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/content_files.dart';
import '../../../tool/src/content/content_validator.dart';

void main() {
  final report = validateContent(
    ContentFiles.read(Directory('content')),
    ContentSchemas.read(Directory('content/schema')),
  );
  final content = report.content;

  test('the content is valid, with no warnings', () {
    expect(report.errors, isEmpty);
    expect(report.warnings, isEmpty);
  });

  test('it has an everyday category of 30 nouns and one of 10 verbs', () {
    final everyday = {
      for (final c in content.categories)
        if (c.everyday) c.kind: c.id,
    };
    expect(everyday.keys, unorderedEquals(CategoryKind.values));
    expect(
      content.nouns.where(
        (n) => n.categoryIds.contains(everyday[CategoryKind.noun]),
      ),
      hasLength(30),
    );
    expect(
      content.verbs.where(
        (v) => v.categoryIds.contains(everyday[CategoryKind.verb]),
      ),
      hasLength(10),
    );
  });

  test('the everyday verbs are the ten most common the spec names', () {
    expect(
      content.verbs.map((v) => v.infinitive),
      unorderedEquals([
        'être',
        'avoir',
        'faire',
        'dire',
        'aller',
        'voir',
        'pouvoir',
        'savoir',
        'vouloir',
        'venir',
      ]),
    );
  });

  test('every word and verb has its own rank', () {
    final nounRanks = content.nouns.map((n) => n.rank).toSet();
    final verbRanks = content.verbs.map((v) => v.rank).toSet();
    expect(nounRanks, hasLength(content.nouns.length));
    expect(verbRanks, hasLength(content.verbs.length));
    expect([...nounRanks, ...verbRanks], isNot(contains(null)));
  });
}
