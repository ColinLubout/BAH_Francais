// The words here are the spec's own examples (fourchette, école, voiture /
// auto, élève, les ciseaux, j’aime), with their real gender and elision.

import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/typing_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

const LetterState c = LetterState.correct;
const LetterState a = LetterState.accentOnly;
const LetterState w = LetterState.wrong;

List<LetterState> letters(String typed, List<String> forms) =>
    typingFeedback(typed, forms).letters;

void main() {
  group('letter by letter', () {
    test('nothing typed, nothing to show', () {
      expect(letters('', ['école']), isEmpty);
      expect(typingFeedback('', ['école']).capsGrade, isFalse);
    });

    test('a matching start is green, whatever the case', () {
      expect(letters('fou', ['fourchette']), [c, c, c]);
      expect(letters('FOU', ['fourchette']), [c, c, c]);
      final feedback = typingFeedback('fourchette', ['fourchette']);
      expect(feedback.isWrong, isFalse);
      expect(feedback.capsGrade, isFalse);
    });

    test('a letter right apart from its accent is orange', () {
      expect(letters('ec', ['école']), [a, c]);
      final feedback = typingFeedback('ecole', ['école']);
      expect(feedback.isWrong, isFalse);
      expect(feedback.capsGrade, isTrue);
    });

    test('once a letter is wrong, every letter is red', () {
      final feedback = typingFeedback('fox', ['fourchette']);
      expect(feedback.letters, [w, w, w]);
      expect(feedback.isWrong, isTrue);
      expect(feedback.capsGrade, isTrue);
    });

    test('deleting back to a right start turns them green again', () {
      expect(typingFeedback('fox', ['fourchette']).isWrong, isTrue);
      expect(letters('fo', ['fourchette']), [c, c]);
    });

    test('typing past the end of every form is wrong', () {
      expect(typingFeedback('écoles', ['école']).isWrong, isTrue);
    });
  });

  group('against every accepted form', () {
    test('a synonym is right too', () {
      expect(letters('aut', ['voiture', 'auto']), [c, c, c]);
    });

    test('an exact form beats one with accent slips', () {
      // Made-up forms: "et" fits "été" with a slip, "ete" exactly.
      expect(letters('et', ['été', 'ete']), [c, c]);
    });

    test('of two forms with slips, the one with fewer wins', () {
      // Made-up forms: "ee" fits both, "éé" with two slips, "ée" with one.
      expect(letters('ee', ['éé', 'ée']), [a, c]);
    });
  });

  group('normalisation', () {
    test("’ and ' are the same", () {
      expect(letters("j'ai", ['j’aime']), [c, c, c, c]);
      expect(letters('j’ai', ['j’aime']), [c, c, c, c]);
    });

    test('spaces normalisation drops count as right', () {
      // Leading, doubled, and after an apostrophe.
      expect(letters(' la', ['la fourchette']), [c, c, c]);
      expect(letters('la  f', ['la fourchette']), [c, c, c, c, c]);
      expect(letters('l’ é', ['l’école']), [c, c, c, c]);
    });
  });

  group('a noun’s typings', () {
    const ecole = VocabularyAnswer(
      word: 'école',
      gender: Gender.feminine,
      elides: true,
    );
    const voiture = VocabularyAnswer(
      word: 'voiture',
      gender: Gender.feminine,
      synonyms: [Synonym('auto', elides: true)],
    );
    const eleve = VocabularyAnswer(
      word: 'élève',
      gender: Gender.both,
      elides: true,
    );
    const ciseaux = VocabularyAnswer(
      word: 'ciseaux',
      gender: Gender.masculine,
      pluralOnly: true,
    );

    test('article optional: the word alone, or with each of its articles', () {
      expect(
        ecole.typings(mandatory: false),
        unorderedEquals(['école', 'une école', 'l’école']),
      );
      expect(
        voiture.typings(mandatory: false),
        unorderedEquals([
          'voiture',
          'une voiture',
          'la voiture',
          'auto',
          'une auto',
          'l’auto',
        ]),
      );
    });

    test('article mandatory: always with one, and never l’', () {
      expect(ecole.typings(mandatory: true), ['une école']);
      expect(
        eleve.typings(mandatory: true),
        unorderedEquals(['un élève', 'une élève']),
      );
      expect(
        ciseaux.typings(mandatory: true),
        unorderedEquals(['les ciseaux', 'des ciseaux']),
      );
    });

    test('a wrong article goes red as it is typed', () {
      final forms = ecole.typings(mandatory: false);
      expect(typingFeedback('la ', forms).isWrong, isTrue);
      expect(typingFeedback('une é', forms).isWrong, isFalse);
    });

    test('with the article mandatory, the word alone goes red', () {
      final forms = ecole.typings(mandatory: true);
      expect(typingFeedback('éc', forms).isWrong, isTrue);
    });
  });
}
