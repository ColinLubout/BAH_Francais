// The sentences are the spec's and the sample's examples; the made-up words
// in the last tests are not French.

import 'package:bah_francais/features/content/domain/sentence_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findOnce', () {
    test('finds whole words, ignoring case', () {
      expect(findOnce('Hier, nous sommes allés au cinéma.', 'sommes allés'), (
        start: 11,
        end: 23,
      ));
      expect(findOnce('Quel jour sommes-nous ?', 'SOMMES'), (
        start: 10,
        end: 16,
      ));
    });

    test('words after an apostrophe are whole words', () {
      expect(findOnce('J’habite à Marseille.', 'habite'), (start: 2, end: 8));
    });

    test('does not find a part of a word', () {
      expect(findOnce('La maison a un jardin.', 'a'), (start: 10, end: 11));
      expect(findOnce('Il habitait ici.', 'habite'), isNull);
    });

    test('finds nothing unless the words are there exactly once', () {
      expect(findOnce('Je suis là, je suis prêt.', 'suis'), isNull);
      expect(findOnce('Il dort.', 'mange'), isNull);
      expect(findOnce('Il dort.', ''), isNull);
    });
  });

  group('conjugationPrompt', () {
    test('blanks out the answer', () {
      expect(
        conjugationPrompt('Hier, nous sommes allés au cinéma.', 'sommes allés'),
        'Hier, nous ___ au cinéma.',
      );
    });

    test('writes an elided word before the answer in full', () {
      expect(
        conjugationPrompt('J’habite à Marseille.', 'habite'),
        'Je ___ à Marseille.',
      );
      expect(
        conjugationPrompt('Demain, j’irai à la banque.', 'irai'),
        'Demain, je ___ à la banque.',
      );
      expect(
        conjugationPrompt("Je n'ai pas le temps.", 'ai'),
        'Je ne ___ pas le temps.',
      );
      expect(
        conjugationPrompt('Nous savons que c’est difficile.', 'est'),
        'Nous savons que ce ___ difficile.',
      );
    });

    test('an elided l’ is written as the sentence says', () {
      expect(
        conjugationPrompt('Ce livre ? Je l’ai payé.', 'ai payé', before: 'le'),
        'Ce livre ? Je le ___.',
      );
      expect(conjugationPrompt('Je l’ai payé.', 'ai payé'), isNull);
      expect(
        conjugationPrompt('Je l’ai payé.', 'ai payé', before: 'les'),
        isNull,
      );
    });

    test('before only applies after l’', () {
      expect(conjugationPrompt('Je paie.', 'paie', before: 'le'), isNull);
    });

    test('an elided word it can’t write in full is refused', () {
      expect(conjugationPrompt('Lorsqu’arrive l’été.', 'arrive'), isNull);
    });

    test('a capital stays a capital', () {
      expect(
        conjugationPrompt('L’aime-t-il ?', 'aime', before: 'la'),
        'La ___-t-il ?',
      );
    });

    test('the answer must be there exactly once', () {
      expect(conjugationPrompt('Zib zab.', 'zub'), isNull);
    });
  });
}
