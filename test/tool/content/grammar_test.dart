// The sentences here are short textbook illustrations of each concept, made
// from the content's first verbs and nouns; they are test data, not content.

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/grammar.dart';

ContentVerb verb(
  String id,
  String infinitive,
  Map<Tense, List<String>> forms,
) => ContentVerb(
  id: id,
  infinitive: infinitive,
  group: VerbGroup.irr,
  auxiliary: Auxiliary.avoir,
  level: Level.debutant,
  categoryIds: const ['cat.v'],
  forms: [
    for (final MapEntry(key: tense, value: list) in forms.entries)
      for (var p = 0; p < list.length; p++)
        ContentVerbForm(tense: tense, person: Person.values[p], form: list[p]),
  ],
);

ContentNoun noun(String word) => ContentNoun(
  id: 'n.$word',
  word: word,
  gender: Gender.masculine,
  level: Level.debutant,
  categoryIds: const ['cat.n'],
);

final content = ContentSet(
  verbs: [
    verb('v.etre', 'être', {
      Tense.present: ['suis', 'es', 'est', 'sommes', 'êtes', 'sont'],
      Tense.imparfait: ['étais', 'étais', 'était'],
      Tense.futurSimple: ['serai'],
    }),
    verb('v.avoir', 'avoir', {
      Tense.present: ['ai', 'as', 'a', 'avons', 'avez', 'ont'],
    }),
    verb('v.aller', 'aller', {
      Tense.present: ['vais', 'vas', 'va', 'allons', 'allez', 'vont'],
    }),
    verb('v.dire', 'dire', {
      Tense.present: ['dis', 'dis', 'dit', 'disons', 'dites', 'disent'],
    }),
    verb('v.finir', 'finir', {
      Tense.present: [
        'finis',
        'finis',
        'finit',
        'finissons',
        'finissez',
        'finissent',
      ],
      Tense.passeCompose: ['ai fini', 'as fini', 'a fini'],
    }),
  ],
  nouns: [
    for (final w in ['chat', 'maison', 'travail', 'heure']) noun(w),
  ],
);
final context = GrammarContext(content);

/// The concepts detected in [text], read as using [verbs].
Set<String> grammar(String text, {List<SentenceVerb> verbs = const []}) =>
    detectGrammar(
      ContentSentence(id: 's.a', text: text, verbs: verbs),
      context,
    );

const presentLink = SentenceVerb(
  verbId: 'v.etre',
  tense: Tense.present,
  person: Person.firstSingular,
  answer: 'suis',
);

void main() {
  group('tenses', () {
    test('from the sentence’s links, and the content’s forms in it', () {
      expect(grammar('Je suis là.', verbs: [presentLink]), contains('present'));
      expect(grammar('J’étais là.'), contains('imparfait'));
      expect(grammar('Je serai là.'), contains('futur-simple'));
      expect(grammar('J’ai fini le travail.'), contains('passe-compose'));
    });

    test('aller + infinitive is the futur proche; aller + place isn’t', () {
      expect(grammar('Je vais finir le travail.'), contains('futur-proche'));
      expect(grammar('Tu vas le dire.'), contains('futur-proche'));
      expect(grammar('Je vais à la maison.'), isNot(contains('futur-proche')));
    });

    test('venir de + infinitive and être en train de', () {
      expect(grammar('Je viens de finir.'), contains('passe-recent'));
      expect(
        grammar('Il est en train de finir.'),
        contains('present-progressive'),
      );
    });

    test('the imperative, only as the first word', () {
      expect(grammar('Finis ton travail !'), contains('imperative'));
      expect(
        grammar('Dis-moi.'),
        containsAll(['imperative', 'pronoun-object-me-te']),
      );
      expect(grammar('Vous allez à la maison.'), isNot(contains('imperative')));
      expect(grammar('Dis-tu ça ?'), isNot(contains('imperative')));
    });
  });

  group('determiners', () {
    test('articles, contractions and the partitive', () {
      expect(grammar('Le chat est à la maison.'), contains('articles'));
      expect(grammar('Je vais au travail.'), contains('contractions'));
      expect(grammar('La maison du chat.'), contains('contractions'));
      expect(grammar('J’ai du travail.'), contains('partitive'));
    });

    test('possessives and demonstratives', () {
      expect(grammar('Mon chat est là.'), contains('possessives'));
      expect(grammar('Je dis bonsoir à leur chat.'), contains('possessives'));
      expect(grammar('Ce chat est là.'), contains('demonstratives'));
      expect(grammar('Ce sont des chats.'), {'c-est', 'articles'});
      expect(grammar('C’est mon chat.'), containsAll(['c-est', 'possessives']));
    });

    test('numbers and the time', () {
      expect(grammar('Nous avons deux chats.'), contains('numbers'));
      expect(
        grammar('Je finis à six heures.'),
        containsAll(['numbers', 'telling-time']),
      );
      expect(grammar('Tu finis à quelle heure ?'), contains('telling-time'));
    });
  });

  group('il y a, y and en', () {
    test('il y a is a phrase, not the pronoun y', () {
      expect(grammar('Il y a un chat.'), contains('il-y-a'));
      expect(grammar('Il y a un chat.'), isNot(contains('pronoun-y')));
      expect(grammar('Il n’y a pas de chat.'), contains('il-y-a'));
      expect(grammar('Il y en a deux.'), containsAll(['il-y-a', 'pronoun-en']));
      expect(grammar('Il y en a deux.'), isNot(contains('pronouns-double')));
    });

    test('y and en as pronouns', () {
      expect(grammar('J’y vais.'), contains('pronoun-y'));
      expect(grammar('J’en ai deux.'), contains('pronoun-en'));
      expect(grammar('Qu’est-ce que vous en dites ?'), contains('pronoun-en'));
      expect(grammar('Il est en retard.'), isNot(contains('pronoun-en')));
    });
  });

  group('negation', () {
    test('ne… pas, the other negations, and ne… que', () {
      expect(grammar('Je ne suis pas là.'), contains('negation-ne-pas'));
      expect(grammar('Il n’a plus de maison.'), contains('negation-other'));
      expect(grammar('Je ne dis rien.'), contains('negation-other'));
      expect(grammar('Il n’a qu’un chat.'), contains('restriction-ne-que'));
      expect(grammar('Il n’a qu’un chat.'), isNot(contains('clause-que')));
    });
  });

  group('questions', () {
    test('by intonation, with est-ce que, with a question word', () {
      expect(grammar('Tu as un chat ?'), contains('question-intonation'));
      expect(grammar('Est-ce que tu as un chat ?'), {
        'question-est-ce-que',
        'articles',
      });
      expect(grammar('Où est le chat ?'), contains('question-words'));
      expect(
        grammar('Mais qu’est-ce que tu dis ?'),
        containsAll(['question-est-ce-que', 'question-words']),
      );
      expect(
        grammar('Mais qu’est-ce que tu dis ?'),
        isNot(contains('clause-que')),
      );
    });

    test('outside a question, an inversion reports speech', () {
      expect(grammar('C’est beau, dit-il.'), contains('reported-speech'));
      expect(
        grammar('C’est beau, dit-il.'),
        isNot(contains('question-inversion')),
      );
    });

    test('inversion after a noun subject, and in the negative', () {
      expect(
        grammar('Ta maison a-t-elle un chat ?'),
        containsAll(['inversion-complex', 'inversion-t']),
      );
      expect(
        grammar('Les chats sont-ils à la maison ?'),
        contains('inversion-complex'),
      );
      expect(
        grammar('Quel chat as-tu ?'),
        isNot(contains('inversion-complex')),
      );
      expect(
        grammar('Combien de chats as-tu ?'),
        isNot(contains('inversion-complex')),
      );
      expect(
        grammar('Pourquoi ne dis-tu pas oui ?'),
        contains('inversion-negative'),
      );
      expect(grammar('As-tu un chat ?'), isNot(contains('inversion-negative')));
    });

    test('by inversion, and with -t-', () {
      expect(grammar('As-tu un chat ?'), contains('question-inversion'));
      expect(grammar('As-tu un chat ?'), isNot(contains('inversion-t')));
      expect(
        grammar('A-t-elle un chat ?'),
        containsAll(['question-inversion', 'inversion-t']),
      );
    });
  });

  group('pronouns', () {
    test('object pronouns before the verb', () {
      expect(grammar('Je le dis.'), contains('pronoun-direct-object'));
      expect(grammar('Je le dis.'), isNot(contains('articles')));
      expect(grammar('Je lui dis tout.'), contains('pronoun-indirect-object'));
      expect(grammar('Tu me dis tout.'), contains('pronoun-object-me-te'));
      expect(grammar('Il nous dit tout.'), contains('pronoun-object-me-te'));
    });

    test('a pronoun that is the subject’s own is a pronominal verb', () {
      expect(grammar('Je me dis ça.'), contains('pronominal-verbs'));
      expect(grammar('Nous nous disons tout.'), contains('pronominal-verbs'));
      expect(
        grammar('Nous nous disons tout.'),
        isNot(contains('pronoun-object-me-te')),
      );
      expect(grammar('Il se dit ça.'), contains('pronominal-verbs'));
    });

    test('two pronouns together', () {
      expect(grammar('Je le lui dis.'), contains('pronouns-double'));
    });

    test('stressed pronouns, after a preposition or alone', () {
      expect(grammar('Il est avec moi.'), contains('stressed-pronouns'));
      expect(grammar('C’est pour lui.'), contains('stressed-pronouns'));
      expect(
        grammar('Tu vas chez toi.'),
        containsAll(['stressed-pronouns', 'prepositions-place']),
      );
    });

    test('possessive and demonstrative pronouns', () {
      expect(grammar('C’est le mien.'), contains('possessive-pronouns'));
      expect(
        grammar('Celui-ci est à moi.'),
        contains('demonstrative-pronouns'),
      );
    });
  });

  group('places', () {
    test('à, chez, dans before a place, not before a time', () {
      expect(grammar('Il est à la maison.'), contains('prepositions-place'));
      expect(
        grammar('Je finis à six heures.'),
        isNot(contains('prepositions-place')),
      );
    });
  });

  group('clauses', () {
    test('que: a clause, reported speech, a relative, ce que', () {
      expect(grammar('Je suis sûr qu’il est là.'), contains('clause-que'));
      expect(
        grammar('Il dit qu’il est là.'),
        containsAll(['reported-speech', 'clause-que']),
      );
      expect(grammar('Le chat que j’ai.'), contains('relative-qui-que'));
      expect(grammar('Le chat qui est là.'), contains('relative-qui-que'));
      expect(grammar('Je dis ce que je dis.'), contains('ce-que-ce-qui'));
      expect(grammar('C’est lui qui le dit.'), contains('mise-en-relief'));
    });

    test('où, dont and the composed relatives', () {
      expect(grammar('La maison où il est.'), contains('relative-ou'));
      expect(grammar('Où est le chat ?'), isNot(contains('relative-ou')));
      expect(grammar('La maison dont il dit ça.'), contains('relative-dont'));
      expect(
        grammar('La maison dans laquelle il est.'),
        contains('relatives-composes'),
      );
    });

    test('time, cause and si', () {
      expect(
        grammar('Je suis là quand il est là.'),
        contains('clause-time-cause'),
      );
      expect(
        grammar('Quand est-il là ?'),
        isNot(contains('clause-time-cause')),
      );
      expect(
        grammar('Je suis là parce qu’il est là.'),
        contains('clause-time-cause'),
      );
      expect(
        grammar('Si tu vas à la maison, je vais avec toi.'),
        contains('clause-si'),
      );
      expect(grammar('S’il est là, je suis là.'), contains('clause-si'));
    });

    test('comparisons', () {
      expect(grammar('Il est plus grand que moi.'), contains('comparative'));
      expect(grammar('C’est la plus belle maison.'), contains('superlative'));
    });

    test('the gérondif', () {
      expect(grammar('Il dit ça en finissant.'), contains('gerondif'));
      expect(grammar('Il est en avant.'), isNot(contains('gerondif')));
    });
  });

  group('levels and tags', () {
    final concepts = [
      const GrammarConcept(id: 'present', level: CefrLevel.a1, name: 'P'),
      const GrammarConcept(id: 'pronoun-y', level: CefrLevel.a2, name: 'Y'),
      const GrammarConcept(
        id: 'pronouns-double',
        level: CefrLevel.b1,
        name: 'D',
      ),
    ];
    final byId = {for (final c in concepts) c.id: c};

    test('a sentence’s level is its hardest concept’s', () {
      expect(levelOf(['present'], byId), CefrLevel.a1);
      expect(levelOf(['present', 'pronoun-y'], byId), CefrLevel.a2);
      expect(levelOf(['pronouns-double', 'pronoun-y'], byId), CefrLevel.b1);
      expect(levelOf(const [], byId), CefrLevel.a1);
      expect(CefrLevel.of('B2'), CefrLevel.b2);
      expect(CefrLevel.of('C1'), isNull);
    });

    test('the concepts read from grammar.json', () {
      final read = conceptsFromJson({
        'max_level': 'A1',
        'concepts': [
          {'id': 'present', 'level': 'A1', 'name': 'P', 'example': 'e'},
          {'id': 'pronoun-y', 'level': 'A2', 'name': 'Y', 'note': 'n'},
        ],
      });
      expect(read.map((c) => c.id), ['present', 'pronoun-y']);
      expect(read.last.level, CefrLevel.a2);
      expect(read.first.example, 'e');
      expect(read.last.note, 'n');
    });

    test('untagged: tags in the catalogue’s order, level, keys in order', () {
      final tagged = withGrammar(
        {
          'id': 's.a',
          'text': 't',
          'verbs': <Object?>[],
          'credit': {'tatoeba': 1, 'author': 'a'},
        },
        {'pronoun-y', 'present'},
        concepts,
      );
      expect(tagged.keys, [
        'id',
        'text',
        'credit',
        'level',
        'grammar',
        'verbs',
      ]);
      expect(tagged['grammar'], ['present', 'pronoun-y']);
      expect(tagged['level'], 'A2');
    });

    test('tagged already: kept as it is', () {
      final sentence = {
        'id': 's.a',
        'text': 't',
        'level': 'A1',
        'grammar': ['present'],
      };
      expect(withGrammar(sentence, {'pronoun-y'}, concepts), sentence);
    });
  });

  test('words: elided words split off, hyphens kept or split', () {
    expect(grammarTokens('A-t-elle l’heure ?'), [
      (word: 'a', hyphen: false),
      (word: 't', hyphen: true),
      (word: 'elle', hyphen: true),
      (word: 'l’', hyphen: false),
      (word: 'heure', hyphen: false),
    ]);
    expect(grammarTokens('peut-être'), [(word: 'peut-être', hyphen: false)]);
  });
}
