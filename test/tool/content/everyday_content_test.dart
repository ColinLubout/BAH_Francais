// The real content in content/: so far the everyday categories.

import 'dart:convert';
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

  test('it teaches the present only (decision 62)', () {
    expect(content.tenses, [Tense.present]);
  });

  test('every sentence is A1, the content’s max_level, with its grammar '
      'concepts (decision 65)', () {
    final grammar =
        jsonDecode(File('content/grammar.json').readAsStringSync()) as Map;
    expect(grammar['max_level'], 'A1');
    for (final file in Directory('content/sentences').listSync()) {
      final json = jsonDecode((file as File).readAsStringSync()) as Map;
      for (final s
          in (json['sentences'] as List).cast<Map<String, Object?>>()) {
        expect(s['level'], 'A1', reason: '${s['id']}');
        expect(s['grammar'], isNotEmpty, reason: '${s['id']}');
      }
    }
  });

  test('it has an everyday category of 10 nouns and one of 6 verbs', () {
    final everyday = {
      for (final c in content.categories)
        if (c.everyday) c.kind: c.id,
    };
    expect(everyday.keys, unorderedEquals(CategoryKind.values));
    expect(
      content.nouns.where(
        (n) => n.categoryIds.contains(everyday[CategoryKind.noun]),
      ),
      hasLength(10),
    );
    expect(
      content.verbs.where(
        (v) => v.categoryIds.contains(everyday[CategoryKind.verb]),
      ),
      hasLength(6),
    );
  });

  test('the everyday words are the owner’s lists (decision 62)', () {
    expect(
      content.verbs.map((v) => v.infinitive),
      unorderedEquals(['être', 'avoir', 'aller', 'faire', 'dire', 'finir']),
    );
    expect(
      content.nouns.map((n) => n.word),
      unorderedEquals([
        'homme',
        'femme',
        'jour',
        'chat',
        'chien',
        'soir',
        'voiture',
        'travail',
        'heure',
        'maison',
      ]),
    );
  });

  test('every verb keeps its forms for all four tenses', () {
    for (final verb in content.verbs) {
      for (final tense in Tense.values) {
        for (final person in Person.values) {
          expect(verb.form(tense, person), isNotNull, reason: verb.id);
        }
      }
    }
  });

  group('everyday sentences', () {
    final everydayIds = {
      for (final c in content.categories)
        if (c.everyday) c.id,
    };
    final nouns = {
      for (final n in content.nouns)
        if (n.categoryIds.any(everydayIds.contains)) n.id,
    };
    final verbs = {
      for (final v in content.verbs)
        if (v.categoryIds.any(everydayIds.contains)) v.id,
    };
    // Those that use only everyday words and verbs.
    final sentences = [
      for (final s in content.sentences)
        if (s.verbs.every((v) => verbs.contains(v.verbId)) &&
            s.nouns.every((n) => nouns.contains(n.nounId)))
          s,
    ];

    test('two or more for each verb and person in each tense taught, and '
        'each noun', () {
      final perSlot = <(String, Tense, Person), int>{};
      final perNoun = <String, int>{};
      for (final s in sentences) {
        for (final v in s.verbs) {
          final slot = (v.verbId, v.tense, v.person);
          perSlot[slot] = (perSlot[slot] ?? 0) + 1;
        }
        for (final n in s.nouns) {
          perNoun[n.nounId] = (perNoun[n.nounId] ?? 0) + 1;
        }
      }
      for (final verb in verbs) {
        for (final tense in content.tenses) {
          for (final person in Person.values) {
            expect(
              perSlot[(verb, tense, person)] ?? 0,
              greaterThanOrEqualTo(2),
              reason: '$verb ${tense.id} ${person.id}',
            );
          }
        }
      }
      for (final noun in nouns) {
        expect(perNoun[noun] ?? 0, greaterThanOrEqualTo(2), reason: noun);
      }
    });

    test('name no one: no capital letter after the first', () {
      final capital = RegExp(r'(?<=.)\p{Lu}', unicode: true);
      for (final s in sentences) {
        expect(capital.hasMatch(s.text), isFalse, reason: s.text);
      }
    });

    test('a sentence from Tatoeba is credited, and its id is its number', () {
      for (final s in sentences) {
        final credit = s.credit;
        if (credit == null) {
          expect(s.id, isNot(startsWith('s.tatoeba.')));
        } else {
          expect(s.id, 's.tatoeba.${credit.tatoebaId}');
          expect(credit.author, isNotEmpty);
        }
      }
    });
  });

  test('every word and verb has its own rank', () {
    final nounRanks = content.nouns.map((n) => n.rank).toSet();
    final verbRanks = content.verbs.map((v) => v.rank).toSet();
    expect(nounRanks, hasLength(content.nouns.length));
    expect(verbRanks, hasLength(content.verbs.length));
    expect([...nounRanks, ...verbRanks], isNot(contains(null)));
  });
}
