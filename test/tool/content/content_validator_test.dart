import 'dart:convert';
import 'dart:io';

import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/content_files.dart';
import '../../../tool/src/content/content_validator.dart';

final schemas = ContentSchemas.read(Directory('content/schema'));
final sample = ContentFiles.read(Directory('content/sample'));

typedef Json = Map<String, Object?>;

/// The sample with the JSON of the file at [path] changed by [change].
ContentFiles edited(String path, void Function(Json json) change) {
  SourceFile apply(SourceFile file) {
    if (file.path != path) return file;
    final json = jsonDecode(file.text) as Json;
    change(json);
    return SourceFile(file.path, jsonEncode(json));
  }

  return ContentFiles(
    verbCategories: apply(sample.verbCategories!),
    nouns: [for (final f in sample.nouns) apply(f)],
    verbs: [for (final f in sample.verbs) apply(f)],
    images: sample.images,
  );
}

/// The sample with the image at [path] replaced by [svg].
ContentFiles withImage(String path, String svg) => ContentFiles(
  verbCategories: sample.verbCategories,
  nouns: sample.nouns,
  verbs: sample.verbs,
  images: {...sample.images, path: utf8.encode(svg)},
);

/// The noun [id] in a noun file's [json].
Json noun(Json json, String id) =>
    (json['nouns']! as List).cast<Json>().firstWhere((n) => n['id'] == id);

/// The sentence [id] in a verb file's [json].
Json sentence(Json json, String id) =>
    (json['sentences']! as List).cast<Json>().firstWhere((s) => s['id'] == id);

List<String> errorsOf(ContentFiles files) => [
  for (final e in validateContent(files, schemas).errors) e.toString(),
];

/// Expects [files] to have exactly one error, containing every fragment.
void expectError(ContentFiles files, List<String> fragments) {
  final errors = errorsOf(files);
  expect(errors, hasLength(1), reason: errors.join('\n'));
  for (final fragment in fragments) {
    expect(errors.single, contains(fragment));
  }
}

const cuisine = 'nouns/cuisine.json';
const animaux = 'nouns/animaux.json';
const essentiels = 'nouns/essentiels.json';
const aller = 'verbs/aller.json';

void main() {
  group('the sample', () {
    final report = validateContent(sample, schemas);

    test('is valid, with no warnings', () {
      expect(report.errors, isEmpty);
      expect(report.warnings, isEmpty);
    });

    test('becomes the content it describes', () {
      final content = report.content;
      final nouns = {for (final n in content.nouns) n.id: n};
      expect(nouns['n.voiture']!.synonyms, [
        const Synonym('auto', elides: true),
      ]);
      expect(nouns['n.velo']!.synonyms, [
        const Synonym('bicyclette', gender: Gender.feminine),
      ]);
      expect(nouns['n.eau']!.categoryIds, ['cat.essentiels', 'cat.cuisine']);
      expect(nouns['n.fourchette']!.imageIds, [
        'i.fourchette-1',
        'i.fourchette-2',
      ]);
      expect(nouns['n.lunettes']!.pluralOnly, isTrue);
      expect(nouns['n.preparation']!.endingHint, '-tion → féminin');
      expect(nouns['n.chien']!.definition, isNull);

      final maison = content.images.firstWhere((i) => i.id == 'i.maison-1');
      expect(maison.itemId, 'n.maison');
      expect(maison.format, ImageFormat.svg);
      expect(maison.credit, 'Dessin d’exemple');
      expect(maison.svg, startsWith('<svg'));

      final verbs = {for (final v in content.verbs) v.id: v};
      expect(
        verbs['v.payer']!
            .form(Tense.present, Person.firstSingular)!
            .alternatives,
        ['paye'],
      );
      expect(verbs['v.se-lever']!.pronominal, isTrue);
      expect(verbs['v.aller']!.auxiliary, Auxiliary.etre);
      final everyday = content.categories.where((c) => c.everyday);
      expect(everyday.map((c) => c.id), {
        'cat.essentiels',
        'cat.verbes-essentiels',
      });
    });
  });

  group('JSON and the schema', () {
    test('a file that is not JSON', () {
      final files = ContentFiles(
        verbCategories: sample.verbCategories,
        nouns: [const SourceFile(cuisine, '{"category": ')],
      );
      expect(
        errorsOf(files),
        contains(allOf(contains(cuisine), contains('not valid JSON'))),
      );
    });

    test('a missing required field', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau').remove('gender')),
        [cuisine, '/nouns/1', 'gender'],
      );
    });

    test('a value that is not allowed', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['gender'] = 'n'),
        [cuisine, '/nouns/1/gender'],
      );
    });

    test('a badly formed id', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['id'] = 'couteau'),
        ['/nouns/1/id'],
      );
    });

    test('a field the format does not have', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['colour'] = 'gris'),
        ['/nouns/1', 'colour'],
      );
    });

    test('a noun with no example', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['examples'] = <String>[]),
        ['/nouns/1/examples'],
      );
    });

    test('a noun category file holding a verb category', () {
      expectError(
        edited(cuisine, (j) => (j['category']! as Json)['kind'] = 'verb'),
        ['/category/kind'],
      );
    });

    test('an image file name the format does not allow', () {
      expectError(
        edited(
          cuisine,
          (j) => noun(j, 'n.couteau')['images'] = ['Couteau.png'],
        ),
        ['/nouns/1/images/0'],
      );
    });

    test('a verb missing a form', () {
      expectError(
        edited(
          aller,
          (j) => ((j['forms']! as Json)['present']! as Json).remove('1s'),
        ),
        [aller, '/forms/present', '1s'],
      );
    });

    test('a verb missing a tense', () {
      expectError(
        edited(aller, (j) => (j['forms']! as Json).remove('imparfait')),
        [aller, '/forms', 'imparfait'],
      );
    });
  });

  group('every id is unique', () {
    test('nouns', () {
      // Files are read in name order: the second use is the error.
      expectError(
        edited(animaux, (j) => noun(j, 'n.oiseau')['id'] = 'n.couteau'),
        [cuisine, 'noun id n.couteau is already used in $animaux'],
      );
    });

    test('categories', () {
      final errors = errorsOf(
        edited(animaux, (j) => (j['category']! as Json)['id'] = 'cat.cuisine'),
      );
      expect(
        errors,
        contains(contains('category id cat.cuisine is already used')),
      );
    });

    test('sentences', () {
      expectError(
        edited(
          aller,
          (j) => sentence(j, 's.aller.pr.2s.01')['id'] = 's.aller.pr.1s.01',
        ),
        ['sentence id s.aller.pr.1s.01 is already used'],
      );
    });

    test('image file names, across nouns', () {
      final files = edited(
        animaux,
        (j) => noun(j, 'n.chat')['images'] = ['chien-1.svg'],
      );
      final withFile = ContentFiles(
        verbCategories: files.verbCategories,
        nouns: files.nouns,
        verbs: files.verbs,
        images: {
          ...files.images,
          'images/chat/chien-1.svg': files.images['images/chien/chien-1.svg']!,
        },
      );
      expectError(withFile, ['image id i.chien-1 is already used']);
    });
  });

  test('every noun has an image or a definition', () {
    expectError(
      edited(cuisine, (j) => noun(j, 'n.couteau').remove('definition')),
      [cuisine, 'n.couteau', 'neither an image nor a definition'],
    );
  });

  group('categories', () {
    test('also_in names a noun category that exists', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['also_in'] = ['cat.nulle']),
        ['n.couteau', 'also_in: no noun category cat.nulle'],
      );
    });

    test('also_in names a noun category, not a verb one', () {
      expectError(
        edited(
          cuisine,
          (j) => noun(j, 'n.couteau')['also_in'] = ['cat.vie-quotidienne'],
        ),
        ['also_in: no noun category cat.vie-quotidienne'],
      );
    });

    test('also_in does not repeat the noun’s own category', () {
      expectError(
        edited(
          cuisine,
          (j) => noun(j, 'n.couteau')['also_in'] = ['cat.cuisine'],
        ),
        ['also_in repeats its own category cat.cuisine'],
      );
    });

    test('a verb’s categories are verb categories that exist', () {
      expectError(edited(aller, (j) => j['categories'] = ['cat.nulle']), [
        aller,
        'v.aller',
        'no verb category cat.nulle',
      ]);
      expectError(edited(aller, (j) => j['categories'] = ['cat.cuisine']), [
        'no verb category cat.cuisine',
      ]);
    });

    test('at most one everyday noun category', () {
      expectError(
        edited(cuisine, (j) => (j['category']! as Json)['everyday'] = true),
        [
          essentiels,
          'only one noun category can be everyday',
          'cat.cuisine already is',
        ],
      );
    });

    test('at most one everyday verb category', () {
      expectError(
        edited(
          'verb-categories.json',
          (j) => (j['categories']! as List).cast<Json>()[1]['everyday'] = true,
        ),
        ['only one verb category can be everyday'],
      );
    });
  });

  group('words starting with h', () {
    test('a noun states whether it takes l’', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.haricot').remove('elides')),
        ['n.haricot', 'starts with h: state "elides"'],
      );
    });

    test('a verb with forms starting with h states h_aspire', () {
      expectError(edited('verbs/habiter.json', (j) => j.remove('h_aspire')), [
        'v.habiter',
        'state "h_aspire"',
      ]);
    });

    test('no other verb states h_aspire', () {
      expectError(edited(aller, (j) => j['h_aspire'] = false), [
        'v.aller',
        'h_aspire only applies when a form starts with h',
      ]);
    });
  });

  group('sentences', () {
    void editSentence(
      String id,
      void Function(Json s) change,
      List<String> fragments,
    ) => expectError(edited(aller, (j) => change(sentence(j, id))), [
      aller,
      id,
      ...fragments,
    ]);

    test('every tense and person has one', () {
      expectError(
        edited(
          aller,
          (j) => (j['sentences']! as List).removeWhere(
            (s) => (s as Json)['id'] == 's.aller.im.2p.01',
          ),
        ),
        ['v.aller', 'no sentence for imparfait 2p'],
      );
    });

    test('has a blank', () {
      editSentence(
        's.aller.pr.1s.01',
        (s) => s['text'] = 'Je vais au marché.',
        ['has no ___'],
      );
    });

    test('has the blank once', () {
      editSentence('s.aller.pr.1s.01', (s) => s['text'] = 'Je ___ au ___.', [
        'has ___ more than once',
      ]);
    });

    test('has a blank of three underscores', () {
      editSentence(
        's.aller.pr.1s.01',
        (s) => s['text'] = 'Je ____ au marché.',
        ['three underscores'],
      );
    });

    test('writes the word before the blank in full', () {
      editSentence(
        's.aller.fs.1s.01',
        (s) => s['text'] = 'Demain, j’___ à la banque.',
        ['the word before ___ is elided'],
      );
      editSentence(
        's.aller.fs.1s.01',
        (s) => s['text'] = "Demain, j' ___ à la banque.",
        ['the word before ___ is elided'],
      );
    });

    test('its answer is the stored form', () {
      editSentence('s.aller.pr.1s.01', (s) => s['answer'] = 'va', [
        '"va" is not the present 1s form, "vais"',
      ]);
    });

    test('its answer includes nothing but the verb', () {
      editSentence('s.aller.fs.1s.01', (s) => s['answer'] = 'j’irai', [
        '"j’irai" is not the futur_simple 1s form',
      ]);
    });

    test('its alternatives are stored forms too', () {
      expectError(
        edited(
          'verbs/payer.json',
          (j) => sentence(j, 's.payer.pr.1s.01')['alternatives'] = ['payé'],
        ),
        ['"payé" is not the present 1s form, "paie" or "paye"'],
      );
    });

    test('a form’s alternative is a right answer', () {
      expect(
        errorsOf(
          edited(
            'verbs/payer.json',
            (j) => sentence(j, 's.payer.pr.1s.01')['answer'] = 'paye',
          ),
        ),
        isEmpty,
      );
    });

    test('a compound tense allows agreement, and nothing else', () {
      for (final agreed in ['est allé', 'est allée', 'est allés']) {
        expect(
          errorsOf(
            edited(
              aller,
              (j) => sentence(j, 's.aller.pc.3s.01')['answer'] = agreed,
            ),
          ),
          isEmpty,
          reason: agreed,
        );
      }
      editSentence('s.aller.pc.3s.01', (s) => s['answer'] = 'est allées.', [
        'allowing for agreement',
      ]);
    });

    test('a simple tense allows no agreement', () {
      editSentence('s.aller.pr.1p.01', (s) => s['answer'] = 'allonss', [
        '"allons"',
      ]);
    });
  });

  group('images', () {
    test('a listed image exists', () {
      expectError(
        edited(
          cuisine,
          (j) => noun(j, 'n.fourchette')['images'] = ['fourchette-3.svg'],
        ),
        ['image images/fourchette/fourchette-3.svg not found'],
      );
    });

    test('an image is UTF-8 text', () {
      final files = ContentFiles(
        verbCategories: sample.verbCategories,
        nouns: sample.nouns,
        verbs: sample.verbs,
        images: {
          ...sample.images,
          'images/chien/chien-1.svg': [0xff, 0xfe, 0x00],
        },
      );
      expectError(files, ['images/chien/chien-1.svg', 'is not UTF-8 text']);
    });

    test('an image follows the SVG rules', () {
      expectError(
        withImage(
          'images/chien/chien-1.svg',
          '<svg viewBox="0 0 10 10"><text>wouf</text></svg>',
        ),
        ['images/chien/chien-1.svg', 'has text'],
      );
    });

    test('a big image is a warning, not an error', () {
      final report = validateContent(
        withImage(
          'images/chien/chien-1.svg',
          '<svg viewBox="0 0 10 10"><!-- ${'x' * 21000} --></svg>',
        ),
        schemas,
      );
      expect(report.isValid, isTrue);
      expect(
        report.warnings.single.toString(),
        allOf(
          contains('images/chien/chien-1.svg'),
          contains('over the 20 KB target'),
        ),
      );
    });
  });
}
