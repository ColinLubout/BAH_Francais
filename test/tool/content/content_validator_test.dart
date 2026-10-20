// Each test breaks one rule in the valid sample. Where a test needs a word
// that no sample has (a made-up elided word), it uses a made-up token.

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
    sentences: [for (final f in sample.sentences) apply(f)],
    images: sample.images,
  );
}

/// The sample with the image at [path] replaced by [svg].
ContentFiles withImage(String path, String svg) => ContentFiles(
  verbCategories: sample.verbCategories,
  nouns: sample.nouns,
  verbs: sample.verbs,
  sentences: sample.sentences,
  images: {...sample.images, path: utf8.encode(svg)},
);

/// The noun [id] in a noun file's [json].
Json noun(Json json, String id) =>
    (json['nouns']! as List).cast<Json>().firstWhere((n) => n['id'] == id);

/// The sentence [id] in a sentence file's [json].
Json sentence(Json json, String id) =>
    (json['sentences']! as List).cast<Json>().firstWhere((s) => s['id'] == id);

/// The sample with sentence [id] in the file at [path] changed by [change].
ContentFiles editedSentence(
  String path,
  String id,
  void Function(Json sentence) change,
) => edited(path, (j) => change(sentence(j, id)));

/// The first verb a sentence uses.
Json firstVerb(Json sentence) => (sentence['verbs']! as List).cast<Json>()[0];

/// The first noun a sentence uses.
Json firstNoun(Json sentence) => (sentence['nouns']! as List).cast<Json>()[0];

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

/// Expects one of [files]'s errors to contain every fragment.
void expectAnError(ContentFiles files, List<String> fragments) => expect(
  errorsOf(files),
  contains(allOf([for (final f in fragments) contains(f)])),
);

const cuisine = 'nouns/cuisine.json';
const animaux = 'nouns/animaux.json';
const essentiels = 'nouns/essentiels.json';
const aller = 'verbs/aller.json';
const allerSentences = 'sentences/aller.json';
const cuisineSentences = 'sentences/cuisine.json';
const payerSentences = 'sentences/payer.json';

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

      final sentences = {for (final s in content.sentences) s.id: s};
      final house = sentences['s.maison.01']!;
      expect(house.text, 'Ils habitent dans une grande maison.');
      expect(house.nouns.single.nounId, 'n.maison');
      expect(house.verbs.single.verbId, 'v.habiter');
      expect(house.verbs.single.person, Person.thirdPlural);
      final paid = sentences['s.payer.pc.1s.02']!.verbs.single;
      expect(paid.answer, 'ai payé');
      expect(paid.before, 'le');
      expect(sentences['s.aller.pc.1s.01']!.verbs.single.alternatives, [
        'suis allée',
      ]);
    });
  });

  group('JSON and the schema', () {
    test('a file that is not JSON', () {
      final files = ContentFiles(
        verbCategories: sample.verbCategories,
        nouns: [const SourceFile(cuisine, '{"category": ')],
      );
      expectAnError(files, [cuisine, 'not valid JSON']);
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
      expectAnError(
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

    test('a sentence that uses no verb and no noun', () {
      expectAnError(
        editedSentence(cuisineSentences, 's.couteau.01', (s) {
          s.remove('nouns');
        }),
        [cuisineSentences, '/sentences/1'],
      );
    });

    test('a sentence’s verb without an answer', () {
      expectError(
        editedSentence(
          allerSentences,
          's.aller.pr.1s.01',
          (s) => firstVerb(s).remove('answer'),
        ),
        [allerSentences, '/sentences/0/verbs/0', 'answer'],
      );
    });

    test('before is le or la', () {
      expectError(
        editedSentence(
          payerSentences,
          's.payer.pc.1s.02',
          (s) => firstVerb(s)['before'] = 'les',
        ),
        [payerSentences, 'before'],
      );
    });

    test('a refused sentence file says nothing about what lacks one', () {
      final errors = errorsOf(
        editedSentence(
          allerSentences,
          's.aller.pr.1s.01',
          (s) => firstVerb(s)['tense'] = 'futur',
        ),
      );
      expect(errors, isNotEmpty);
      expect(errors, everyElement(startsWith(allerSentences)));
    });
  });

  group('every id is unique', () {
    test('nouns', () {
      // Files are read in name order: the second use is the error.
      expectAnError(
        edited(animaux, (j) => noun(j, 'n.oiseau')['id'] = 'n.couteau'),
        [cuisine, 'noun id n.couteau is already used in $animaux'],
      );
    });

    test('categories', () {
      expectAnError(
        edited(animaux, (j) => (j['category']! as Json)['id'] = 'cat.cuisine'),
        ['category id cat.cuisine is already used'],
      );
    });

    test('sentences', () {
      expectError(
        editedSentence(
          allerSentences,
          's.aller.pr.2s.01',
          (s) => s['id'] = 's.aller.pr.1s.01',
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
        sentences: files.sentences,
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

  group('a noun is written without its article', () {
    test('the noun', () {
      expectError(
        edited(cuisine, (j) => noun(j, 'n.couteau')['word'] = 'le couteau'),
        ['n.couteau', '"le couteau" starts with an article'],
      );
      expectError(
        edited(cuisine, (j) => noun(j, 'n.assiette')['word'] = 'l’assiette'),
        ['"l’assiette" starts with an article'],
      );
    });

    test('its synonyms', () {
      expectError(
        edited(
          essentiels,
          (j) => noun(j, 'n.voiture')['synonyms'] = ['une auto'],
        ),
        ['n.voiture', '"une auto" starts with an article'],
      );
    });

    test('letters that only look like an article are part of the word', () {
      // No space or apostrophe after them: not an article (decision 38).
      expect(
        errorsOf(
          edited(cuisine, (j) => noun(j, 'n.couteau')['word'] = 'lecouteau'),
        ),
        isEmpty,
      );
    });
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

  group('every item has its sentences', () {
    test('a verb, one for each tense and person', () {
      expectError(
        edited(
          allerSentences,
          (j) => (j['sentences']! as List).removeWhere(
            (s) => (s as Json)['id'] == 's.aller.im.2p.01',
          ),
        ),
        [aller, 'v.aller', 'no sentence for imparfait 2p'],
      );
    });

    test('a noun, as an example', () {
      expectError(
        edited(
          cuisineSentences,
          (j) => (j['sentences']! as List).removeWhere(
            (s) => (s as Json)['id'] == 's.couteau.01',
          ),
        ),
        [cuisine, 'n.couteau', 'no sentence uses it as an example'],
      );
    });
  });

  group('sentences', () {
    void expectSentenceError(
      String path,
      String id,
      void Function(Json s) change,
      List<String> fragments,
    ) =>
        expectError(editedSentence(path, id, change), [path, id, ...fragments]);

    test('are written in full', () {
      expectSentenceError(
        allerSentences,
        's.aller.pr.1s.01',
        (s) => s['text'] = 'Je vais au ___ le samedi.',
        ['is written in full, with no ___'],
      );
    });

    test('use verbs and nouns that exist', () {
      expectSentenceError(
        allerSentences,
        's.aller.pr.1s.01',
        (s) => (s['verbs']! as List).add({...firstVerb(s), 'verb': 'v.nulle'}),
        ['no verb v.nulle'],
      );
      expectSentenceError(
        cuisineSentences,
        's.couteau.01',
        (s) => (s['nouns']! as List).add({'noun': 'n.nulle', 'word': 'Passe'}),
        ['no noun n.nulle'],
      );
    });

    test('use each verb and noun once', () {
      expectSentenceError(
        allerSentences,
        's.aller.pr.1s.01',
        (s) => (s['verbs']! as List).add(firstVerb(s)),
        ['uses v.aller present 1s twice'],
      );
      expectSentenceError(
        cuisineSentences,
        's.couteau.01',
        (s) => (s['nouns']! as List).add(firstNoun(s)),
        ['uses n.couteau twice'],
      );
    });

    test('hold a verb’s answer exactly once, as whole words', () {
      expectSentenceError(
        allerSentences,
        's.aller.pr.1s.01',
        (s) => s['text'] = 'Je vais au marché, je vais au parc.',
        ['the answer "vais" (v.aller) is not in the text exactly once'],
      );
      expectSentenceError(
        allerSentences,
        's.aller.pr.1s.01',
        (s) => s['text'] = 'Je vaisselle.',
        ['the answer "vais" (v.aller) is not in the text exactly once'],
      );
    });

    test('hold a noun’s word exactly once, as whole words', () {
      expectSentenceError(
        cuisineSentences,
        's.couteau.01',
        (s) => firstNoun(s)['word'] = 'couteaux',
        ['"couteaux" (n.couteau) is not in the text exactly once'],
      );
    });

    group('the word before a verb', () {
      test('says le or la after l’', () {
        expectSentenceError(
          payerSentences,
          's.payer.pc.1s.02',
          (s) => firstVerb(s).remove('before'),
          ['"ai payé" follows l’: say whether it is le or la'],
        );
      });

      test('is written in full by the app after j’, n’ and the others', () {
        expect(
          errorsOf(
            editedSentence(
              allerSentences,
              's.aller.fs.1s.01',
              (s) => s['text'] = 'Demain, j’irai à la banque.',
            ),
          ),
          isEmpty,
        );
      });

      test('says nothing when it isn’t l’', () {
        expectSentenceError(
          allerSentences,
          's.aller.pr.1s.01',
          (s) => firstVerb(s)['before'] = 'le',
          ['"before" only applies when the answer follows l’'],
        );
      });

      test('can be written in full', () {
        // A made-up word ending in an elided qu’.
        expectSentenceError(
          allerSentences,
          's.aller.pr.1s.01',
          (s) => s['text'] = 'Zibqu’vais au marché.',
          ['"vais" follows zibqu’, which the prompt can’t write in full'],
        );
      });
    });

    group('answers', () {
      test('are the stored form', () {
        expectSentenceError(allerSentences, 's.aller.pr.1s.01', (s) {
          s['text'] = 'Je va au marché le samedi.';
          firstVerb(s)['answer'] = 'va';
        }, ['"va" is not the v.aller present 1s form, "vais"']);
      });

      test('include nothing but the verb', () {
        expectSentenceError(
          allerSentences,
          's.aller.fs.1s.01',
          (s) => firstVerb(s)['answer'] = 'j’irai',
          ['"j’irai" is not the v.aller futur_simple 1s form'],
        );
      });

      test('alternatives are stored forms too', () {
        expectSentenceError(
          payerSentences,
          's.payer.pr.1s.01',
          (s) => firstVerb(s)['alternatives'] = ['payé'],
          ['"payé" is not the v.payer present 1s form, "paie" or "paye"'],
        );
      });

      test('a form’s alternative is a right answer', () {
        expect(
          errorsOf(
            editedSentence(payerSentences, 's.payer.pr.1s.01', (s) {
              s['text'] = 'Je paye toujours en espèces.';
              firstVerb(s)['answer'] = 'paye';
            }),
          ),
          isEmpty,
        );
      });

      test('a compound tense allows agreement, and nothing else', () {
        for (final agreed in ['est allé', 'est allée', 'est allés']) {
          expect(
            errorsOf(
              editedSentence(allerSentences, 's.aller.pc.3s.01', (s) {
                s['text'] = 'Elle $agreed au travail en bus.';
                firstVerb(s)['answer'] = agreed;
              }),
            ),
            isEmpty,
            reason: agreed,
          );
        }
        expectSentenceError(allerSentences, 's.aller.pc.3s.01', (s) {
          s['text'] = 'Elle est allâs au travail en bus.';
          firstVerb(s)['answer'] = 'est allâs';
        }, ['allowing for agreement']);
      });

      test('a simple tense allows no agreement', () {
        expectSentenceError(allerSentences, 's.aller.pr.1p.01', (s) {
          s['text'] = 'Nous allonss souvent à la plage en été.';
          firstVerb(s)['answer'] = 'allonss';
        }, ['"allons"']);
      });
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
        sentences: sample.sentences,
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
