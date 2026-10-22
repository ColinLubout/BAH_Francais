// The content's own nouns and verbs here are made-up tokens (brol, zoter);
// the other words are the French grammar words the rules are about.

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/sentence_words.dart';

ContentVerbForm present(Person person, String form) =>
    ContentVerbForm(tense: Tense.present, person: person, form: form);

final zoter = ContentVerb(
  id: 'v.zoter',
  infinitive: 'zoter',
  group: VerbGroup.er,
  auxiliary: Auxiliary.avoir,
  level: Level.debutant,
  categoryIds: const ['cat.v'],
  forms: [
    present(Person.firstSingular, 'zote'),
    const ContentVerbForm(
      tense: Tense.imparfait,
      person: Person.firstSingular,
      form: 'zotais',
    ),
  ],
);

final avoir = ContentVerb(
  id: 'v.avoir',
  infinitive: 'avoir',
  group: VerbGroup.irr,
  auxiliary: Auxiliary.avoir,
  level: Level.debutant,
  categoryIds: const ['cat.v'],
  forms: [present(Person.firstSingular, 'ai')],
);

final etre = ContentVerb(
  id: 'v.etre',
  infinitive: 'être',
  group: VerbGroup.irr,
  auxiliary: Auxiliary.avoir,
  level: Level.debutant,
  categoryIds: const ['cat.v'],
  forms: [present(Person.firstSingular, 'suis')],
);

const brol = ContentNoun(
  id: 'n.brol',
  word: 'brol',
  gender: Gender.masculine,
  level: Level.debutant,
  categoryIds: ['cat.n'],
);

const partsOfSpeech = {
  'je': {'pron'},
  'j’': {'pron'},
  'le': {'article', 'pron'},
  'la': {'article', 'pron'},
  'un': {'article', 'num'},
  'à': {'prep'},
  'vite': {'adv', 'adj'},
  'petit': {'adj', 'noun'},
  'chose': {'noun'},
  'genre': {'adv', 'noun'},
  'voir': {'adv', 'verb'},
  'hier': {'adv', 'verb'},
  'allé': {'verb'},
  'fini': {'adj', 'noun', 'verb'},
  'fatigué': {'adj', 'verb'},
  'zotais': {'verb'},
};

/// What the check says about [text], in content teaching [tenses].
List<String> findings(
  String text, {
  List<Tense> tenses = const [Tense.present],
}) => [
  for (final f in checkSentenceWords(
    ContentSet(
      tenses: tenses,
      verbs: [zoter, avoir, etre],
      nouns: const [brol],
      sentences: [ContentSentence(id: 's.a', text: text)],
    ),
    partsOfSpeech,
  ))
    f.message,
];

void main() {
  test('a sentence of the content’s own words, in a tense it teaches', () {
    expect(findings('Je zote le brol vite.'), isEmpty);
    expect(findings('Je zote un petit brol hier.'), isEmpty);
    expect(findings('J’ai un brol.'), isEmpty);
    expect(findings('Je zote les brols.'), ['"les" isn’t in the dictionary']);
  });

  test('a noun or verb the content doesn’t have', () {
    expect(findings('Je zote la chose.'), [
      '"chose" is a noun or verb the content doesn’t have',
    ]);
  });

  test('a word the dictionary doesn’t know', () {
    expect(findings('Je zote qwxz.'), ['"qwxz" isn’t in the dictionary']);
  });

  test('a form of the content’s verb in a tense it doesn’t teach', () {
    expect(findings('Je zotais vite.'), [
      '"zotais" is zoter in the imparfait, a tense the content doesn’t teach',
    ]);
    expect(
      findings('Je zotais vite.', tenses: [Tense.present, Tense.imparfait]),
      isEmpty,
    );
  });

  test('another verb’s infinitive the dictionary also gives as an '
      'adverb', () {
    expect(findings('Je zote voir.'), [
      '"voir" may be a verb the content doesn’t have',
    ]);
  });

  test('a word after a determiner, with none of the content’s nouns '
      'after it', () {
    expect(findings('Je zote un genre.'), [
      '"un genre": "genre" may be a noun the content doesn’t have',
    ]);
  });

  test('an infinitive straight after a conjugated verb, but not after a '
      'preposition', () {
    expect(findings('Je zote zoter.'), [
      '"zote … zoter": an infinitive straight after a conjugated verb',
    ]);
    expect(findings('Je zote à zoter.'), isEmpty);
  });

  test('avoir or être and a participle, unless the content teaches the '
      'passé composé', () {
    const compound =
        '"ai … fini" may be a compound tense, which the content doesn’t '
        'teach';
    expect(findings('J’ai fini.'), [compound]);
    expect(findings('Je suis allé.'), contains(contains('compound tense')));
    expect(findings('Je suis fatigué.'), isEmpty);
    expect(
      findings('J’ai fini.', tenses: [Tense.present, Tense.passeCompose]),
      isEmpty,
    );
  });

  group('words', () {
    test('elided words come off; a hyphenated word stays whole only if '
        'known', () {
      expect(sentenceTokens('J’ai l’heure', (_) => true), [
        'j’',
        'ai',
        'l’',
        'heure',
      ]);
      expect(sentenceTokens('Peut-être', (w) => w == 'peut-être'), [
        'peut-être',
      ]);
      expect(sentenceTokens('a-t-il', (_) => false), ['a', 't', 'il']);
      expect(sentenceTokens('aujourd’hui', (_) => false), ['aujourd’hui']);
    });

    test('the dictionary is asked about each word, whole and split', () {
      final words = sentenceWords(
        const ContentSet(
          sentences: [ContentSentence(id: 's.a', text: 'Est-ce qu’il zote ?')],
        ),
      );
      expect(
        words,
        containsAll(['est-ce', 'est', 'ce', 'qu’il', 'qu’', 'il', 'zote']),
      );
    });
  });
}
