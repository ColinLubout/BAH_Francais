// The dictionary lines below copy the shape of Kaikki.org's data. The words
// are the spec's examples (fourchette, chien, élève, ciseaux, voiture/auto,
// aller, je paie/paye, se lever); made-up tokens stand in where no example
// fits.

import 'dart:convert';

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/dictionary.dart';

String nounLine(
  String word, {
  Map<String, Object?>? head,
  List<List<String>> senses = const [],
  String lang = 'fr',
}) => jsonEncode({
  'pos': 'noun',
  'head_templates': [?head],
  'word': word,
  'lang': 'French',
  'lang_code': lang,
  'senses': [
    for (final tags in senses)
      {
        'glosses': ['x'],
        'tags': tags,
      },
  ],
});

String verbLine(String word, List<Map<String, Object?>> forms) => jsonEncode({
  'pos': 'verb',
  'word': word,
  'lang': 'French',
  'lang_code': 'fr',
  'forms': forms,
  'senses': <Object?>[],
});

Map<String, Object?> form(String form, String tags) => {
  'form': form,
  'tags': tags.split(' '),
  'source': 'conjugation',
};

/// The start of a conjugation table.
List<Map<String, Object?>> table(String infinitive, String auxiliary) => [
  form('no-table-tags', 'table-tags'),
  form('fr-conj-auto', 'inflection-template'),
  form(
    infinitive,
    infinitive.startsWith('se ') ? 'infinitive reflexive' : 'infinitive',
  ),
  form('$auxiliary + past participle', 'infinitive multiword-construction'),
];

Map<String, Object?> present(String person, String number, String f) =>
    form(f, '$person indicative present $number');

const fourchette = ContentNoun(
  id: 'n.fourchette',
  word: 'fourchette',
  gender: Gender.feminine,
  level: Level.debutant,
  categoryIds: ['cat.a'],
);

ContentVerb verb(
  String infinitive,
  List<ContentVerbForm> forms, {
  Auxiliary auxiliary = Auxiliary.avoir,
}) => ContentVerb(
  id: 'v.x',
  infinitive: infinitive,
  group: VerbGroup.irr,
  auxiliary: auxiliary,
  level: Level.debutant,
  categoryIds: const ['cat.v'],
  forms: forms,
);

ContentVerbForm vf(
  Tense tense,
  Person person,
  String form, [
  List<String> alternatives = const [],
]) => ContentVerbForm(
  tense: tense,
  person: person,
  form: form,
  alternatives: alternatives,
);

Future<List<String>> findingsFor(
  List<String> lines,
  ContentSet content, {
  bool differences = true,
}) async {
  final dictionary = await Dictionary.read(
    Stream.fromIterable(lines),
    words: wordsToLook(content),
  );
  return [
    for (final f in compare(content, dictionary))
      if (f.difference == differences) f.toString(),
  ];
}

void main() {
  group('nouns', () {
    test('a gender that agrees is no finding', () async {
      final lines = [
        nounLine(
          'fourchette',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'f'},
          },
        ),
      ];
      const content = ContentSet(nouns: [fourchette]);
      expect(await findingsFor(lines, content), isEmpty);
      expect(await findingsFor(lines, content, differences: false), isEmpty);
    });

    test('a gender that disagrees is a difference', () async {
      final lines = [
        nounLine(
          'fourchette',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'm'},
          },
        ),
      ];
      const message =
          'n.fourchette: "fourchette" is feminine here; the dictionary has '
          'masculine';
      expect(await findingsFor(lines, const ContentSet(nouns: [fourchette])), [
        message,
      ]);
    });

    test('the gender also comes from a plain head or the senses', () async {
      const chien = ContentNoun(
        id: 'n.chien',
        word: 'chien',
        gender: Gender.masculine,
        level: Level.debutant,
        categoryIds: ['cat.a'],
      );
      final viaHead = [
        nounLine(
          'chien',
          head: {
            'name': 'head',
            'args': {'1': 'fr', '2': 'noun', 'g': 'm'},
          },
        ),
      ];
      final viaSenses = [
        nounLine(
          'chien',
          senses: [
            ['masculine'],
          ],
        ),
      ];
      const content = ContentSet(nouns: [chien]);
      expect(await findingsFor(viaHead, content), isEmpty);
      expect(await findingsFor(viaSenses, content), isEmpty);
    });

    test('a noun whose gender follows the person is both', () async {
      const eleve = ContentNoun(
        id: 'n.eleve',
        word: 'élève',
        gender: Gender.both,
        elides: true,
        level: Level.debutant,
        categoryIds: ['cat.a'],
      );
      const content = ContentSet(nouns: [eleve]);
      expect(
        await findingsFor([
          nounLine(
            'élève',
            head: {
              'name': 'fr-noun',
              'args': {'1': 'mfbysense'},
            },
          ),
        ], content),
        isEmpty,
      );
      expect(
        await findingsFor([
          nounLine(
            'élève',
            senses: [
              ['by-personal-gender', 'feminine', 'masculine'],
            ],
          ),
        ], content),
        isEmpty,
      );
    });

    test('another gender in another entry is a note', () async {
      const note =
          'n.fourchette: the dictionary also has "fourchette" as masculine '
          '(another meaning?)';
      final lines = [
        nounLine(
          'fourchette',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'f'},
          },
        ),
        nounLine(
          'fourchette',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'm'},
          },
        ),
      ];
      expect(
        await findingsFor(
          lines,
          const ContentSet(nouns: [fourchette]),
          differences: false,
        ),
        [note],
      );
    });

    test('plural-only must agree, either way', () async {
      const ciseaux = ContentNoun(
        id: 'n.ciseaux',
        word: 'ciseaux',
        gender: Gender.masculine,
        pluralOnly: true,
        level: Level.debutant,
        categoryIds: ['cat.a'],
      );
      final pluralOnly = [
        nounLine(
          'ciseaux',
          head: {
            'name': 'head',
            'args': {'g': 'm-p'},
          },
        ),
      ];
      final notPluralOnly = [
        nounLine(
          'ciseaux',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'm'},
          },
        ),
      ];
      expect(
        await findingsFor(pluralOnly, const ContentSet(nouns: [ciseaux])),
        isEmpty,
      );
      expect(
        await findingsFor(notPluralOnly, const ContentSet(nouns: [ciseaux])),
        ['n.ciseaux: "ciseaux" is plural only here, not in the dictionary'],
      );
      const notHere = ContentNoun(
        id: 'n.ciseaux',
        word: 'ciseaux',
        gender: Gender.masculine,
        level: Level.debutant,
        categoryIds: ['cat.a'],
      );
      expect(
        await findingsFor(pluralOnly, const ContentSet(nouns: [notHere])),
        ['n.ciseaux: "ciseaux" is plural only in the dictionary'],
      );
      expect(
        await findingsFor([
          nounLine(
            'ciseaux',
            senses: [
              ['masculine', 'plural', 'plural-only'],
            ],
          ),
        ], const ContentSet(nouns: [ciseaux])),
        isEmpty,
      );
    });

    test('synonyms are checked with their own gender', () async {
      const voiture = ContentNoun(
        id: 'n.voiture',
        word: 'voiture',
        gender: Gender.feminine,
        level: Level.debutant,
        categoryIds: ['cat.a'],
        synonyms: [Synonym('auto', gender: Gender.masculine)],
      );
      final lines = [
        nounLine(
          'voiture',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'f'},
          },
        ),
        nounLine(
          'auto',
          head: {
            'name': 'fr-noun',
            'args': {'1': 'f'},
          },
        ),
      ];
      const message =
          'n.voiture: synonym "auto" is masculine here; the dictionary has '
          'feminine';
      expect(await findingsFor(lines, const ContentSet(nouns: [voiture])), [
        message,
      ]);
    });

    test('a word missing from the dictionary is a note', () async {
      expect(
        await findingsFor(
          const [],
          const ContentSet(nouns: [fourchette]),
          differences: false,
        ),
        ['n.fourchette: "fourchette" is not in the dictionary'],
      );
    });

    test('entries in other languages are ignored', () async {
      expect(
        await findingsFor(
          [
            nounLine(
              'fourchette',
              head: {
                'name': 'fr-noun',
                'args': {'1': 'm'},
              },
              lang: 'en',
            ),
          ],
          const ContentSet(nouns: [fourchette]),
          differences: false,
        ),
        ['n.fourchette: "fourchette" is not in the dictionary'],
      );
    });
  });

  group('verbs', () {
    final aller = verbLine('aller', [
      ...table('aller', 'être'),
      form('allé', 'participle past'),
      present('first-person', 'singular', 'vais'),
      present('second-person', 'singular', 'vas'),
      // Rows that are not spellings.
      present('first-person', 'singular', '/vɛ/'),
      present('second-person', 'singular', '-'),
      present('first-person', 'singular', 'vø'),
    ]);

    test('forms that agree, and the passé composé built from the auxiliary '
        'and the participle', () async {
      final content = ContentSet(
        verbs: [
          verb('aller', [
            vf(Tense.present, Person.firstSingular, 'vais'),
            vf(Tense.present, Person.secondSingular, 'vas'),
            vf(Tense.passeCompose, Person.firstPlural, 'sommes allé'),
          ], auxiliary: Auxiliary.etre),
        ],
      );
      expect(await findingsFor([aller], content), isEmpty);
      expect(await findingsFor([aller], content, differences: false), isEmpty);
    });

    test('a form or auxiliary that disagrees is a difference', () async {
      final content = ContentSet(
        verbs: [
          verb('aller', [
            vf(Tense.present, Person.secondSingular, 'vat'),
            vf(Tense.passeCompose, Person.firstSingular, 'ai allé'),
          ]),
        ],
      );
      const passeCompose =
          'v.x: passe_compose 1s: "ai allé" here; the dictionary has '
          '"suis allé"';
      expect(await findingsFor([aller], content), [
        'v.x: its auxiliary is avoir here; the dictionary has etre',
        'v.x: present 2s: "vat" here; the dictionary has "vas"',
        passeCompose,
      ]);
    });

    test('a missing form or a variant the content lacks is a note', () async {
      final payer = verbLine('payer', [
        ...table('payer', 'avoir'),
        present('first-person', 'singular', 'paie'),
        present('first-person', 'singular', 'paye'),
      ]);
      final content = ContentSet(
        verbs: [
          verb('payer', [
            vf(Tense.present, Person.firstSingular, 'paie'),
            vf(Tense.imparfait, Person.firstSingular, 'payais'),
          ]),
        ],
      );
      expect(await findingsFor([payer], content, differences: false), [
        'v.x: present 1s: the dictionary also has "paye"',
        'v.x: imparfait 1s: the dictionary has no form',
      ]);
      final withAlternative = ContentSet(
        verbs: [
          verb('payer', [
            vf(Tense.present, Person.firstSingular, 'paie', ['paye']),
          ]),
        ],
      );
      expect(
        await findingsFor([payer], withAlternative, differences: false),
        isEmpty,
      );
    });

    test('a verb with several entries is compared with the closest', () async {
      final other = verbLine('aller', [
        ...table('aller', 'avoir'),
        present('first-person', 'singular', 'alle'),
      ]);
      final content = ContentSet(
        verbs: [
          verb('aller', [
            vf(Tense.present, Person.firstSingular, 'vais'),
          ], auxiliary: Auxiliary.etre),
        ],
      );
      expect(await findingsFor([other, aller], content), isEmpty);
    });

    test(
      'a reflexive verb uses its own table when the entry has one',
      () async {
        // Made up: a verb whose entry holds a reflexive table.
        final zoper = verbLine('zoper', [
          ...table('zoper', 'avoir'),
          present('first-person', 'singular', 'zope'),
          ...table('se zoper', 's’être'),
          form('zopé', 'participle past'),
          form('me zope', 'first-person indicative present reflexive singular'),
        ]);
        final content = ContentSet(
          verbs: [
            verb('se zoper', [
              vf(Tense.present, Person.firstSingular, 'me zope'),
              vf(Tense.passeCompose, Person.thirdSingular, 's’est zopé'),
            ], auxiliary: Auxiliary.etre),
          ],
        );
        expect(await findingsFor([zoper], content), isEmpty);
        expect(
          await findingsFor([zoper], content, differences: false),
          isEmpty,
        );
      },
    );

    test('otherwise its forms are built from the verb, eliding me, te and '
        'se', () async {
      final lever = verbLine('lever', [
        ...table('lever', 'avoir'),
        form('levé', 'participle past'),
        present('first-person', 'singular', 'lève'),
        present('first-person', 'plural', 'levons'),
      ]);
      final content = ContentSet(
        verbs: [
          verb('se lever', [
            vf(Tense.present, Person.firstSingular, 'me lève'),
            vf(Tense.present, Person.firstPlural, 'nous levons'),
            vf(Tense.passeCompose, Person.secondSingular, 't’es levé'),
          ], auxiliary: Auxiliary.etre),
        ],
      );
      expect(await findingsFor([lever], content), isEmpty);
      const built =
          'v.x: its reflexive forms are built from "lever", which has no '
          'reflexive table';
      expect(await findingsFor([lever], content, differences: false), [built]);

      // Made up: a verb starting with a vowel.
      final ourber = verbLine('ourber', [
        ...table('ourber', 'avoir'),
        present('first-person', 'singular', 'ourbe'),
      ]);
      expect(
        await findingsFor(
          [ourber],
          ContentSet(
            verbs: [
              verb('s’ourber', [
                vf(Tense.present, Person.firstSingular, 'm’ourbe'),
              ], auxiliary: Auxiliary.etre),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('a verb missing from the dictionary is a note', () async {
      final content = ContentSet(
        verbs: [
          verb('aller', [vf(Tense.present, Person.firstSingular, 'vais')]),
        ],
      );
      expect(await findingsFor(const [], content, differences: false), [
        'v.x: "aller" is not in the dictionary',
      ]);
    });
  });

  test('a reflexive verb is looked up under the verb', () {
    expect(verbLemma('se lever'), 'lever');
    expect(verbLemma('s’appeler'), 'appeler');
    expect(verbLemma("s'appeler"), 'appeler');
    expect(verbLemma('aller'), 'aller');
  });

  test('lines naming none of the words are not read', () async {
    const entry =
        '{"word": "fourchette", "pos": "noun", "lang_code": "fr", '
        '"head_templates": [], "senses": []}';
    final dictionary = await Dictionary.read(
      Stream.fromIterable([
        'not json at all',
        entry,
        '{"word": "fourchette" broken',
      ]),
      words: {'fourchette'},
    );
    expect(dictionary.nouns.keys, ['fourchette']);
  });

  test('the parts of speech of the words asked for, inflected forms '
      'too', () async {
    String entry(String word, String pos, {String lang = 'fr'}) =>
        '{"word": "$word", "pos": "$pos", "lang_code": "$lang", '
        '"senses": []}';
    final dictionary = await Dictionary.read(
      Stream.fromIterable([
        entry('chiens', 'noun'),
        entry('petit', 'adj'),
        entry('petit', 'noun'),
        entry('chiens', 'verb', lang: 'en'),
        entry('loin', 'adv'),
      ]),
      words: const {},
      partsOfSpeechFor: {'chiens', 'petit'},
    );
    expect(dictionary.partsOfSpeech, {
      'chiens': {'noun'},
      'petit': {'adj', 'noun'},
    });
    expect(dictionary.nouns, isEmpty);
  });
}
