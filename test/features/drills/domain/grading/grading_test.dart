// The words and forms here are the spec's own examples (fourchette, chien,
// élève, l’école, voiture/auto, les ciseaux, aller, je paie/paye, me lève,
// j’aime), with their real gender and elision. No French is invented; where a
// test needs a letter no example has (œ), it uses a made-up token.

import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/grading.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:flutter_test/flutter_test.dart';

const fourchette = VocabularyAnswer(
  word: 'fourchette',
  gender: Gender.feminine,
);
const chien = VocabularyAnswer(word: 'chien', gender: Gender.masculine);
const eleve = VocabularyAnswer(
  word: 'élève',
  gender: Gender.both,
  elides: true,
);
const ecole = VocabularyAnswer(
  word: 'école',
  gender: Gender.feminine,
  elides: true,
);
const voiture = VocabularyAnswer(
  word: 'voiture',
  gender: Gender.feminine,
  synonyms: ['auto'],
);
const ciseaux = VocabularyAnswer(
  word: 'ciseaux',
  gender: Gender.masculine,
  pluralOnly: true,
);

Grade vocab(
  String typed,
  VocabularyAnswer noun, {
  bool mandatory = false,
  bool flagged = false,
}) => gradeVocabulary(
  typed: typed,
  noun: noun,
  articleMandatory: mandatory,
  flaggedWhileTyping: flagged,
);

Grade conj(
  String typed,
  String answer, {
  List<String> alternatives = const [],
  bool flagged = false,
}) => gradeConjugation(
  typed: typed,
  answer: answer,
  alternatives: alternatives,
  flaggedWhileTyping: flagged,
);

void main() {
  group('Gender drill', () {
    test('right is Good, wrong is Again', () {
      final right = gradeGender(
        correct: Gender.feminine,
        chosen: Gender.feminine,
      );
      expect(right.rating, Rating.good);
      expect(right.errorType, ErrorType.none);
      final wrong = gradeGender(
        correct: Gender.feminine,
        chosen: Gender.masculine,
      );
      expect(wrong.rating, Rating.again);
      expect(wrong.errorType, ErrorType.wrong);
    });

    test('a "les deux" noun needs les deux', () {
      expect(
        gradeGender(correct: Gender.both, chosen: Gender.masculine).rating,
        Rating.again,
      );
      expect(
        gradeGender(correct: Gender.both, chosen: Gender.both).rating,
        Rating.good,
      );
    });

    test('offers Faute de frappe after a wrong tap, never Trop facile', () {
      final right = gradeGender(correct: Gender.both, chosen: Gender.both);
      expect(right.canMarkTooEasy, isFalse);
      expect(right.canMarkTypo, isFalse);
      final wrong = gradeGender(correct: Gender.both, chosen: Gender.feminine);
      expect(wrong.canMarkTypo, isTrue);
      expect(wrong.markTypo().rating, Rating.hard);
    });
  });

  group('exact match', () {
    test('is Good, with the answer and nothing to highlight', () {
      final g = conj('sommes allés', 'sommes allés');
      expect(g.rating, Rating.good);
      expect(g.errorType, ErrorType.none);
      expect(g.answer, 'sommes allés');
      expect(g.errors, isEmpty);
    });

    test('ignores case and surrounding spaces', () {
      expect(conj('  Sommes Allés ', 'sommes allés').rating, Rating.good);
      expect(vocab(' FOURCHETTE', fourchette).rating, Rating.good);
    });

    test('ignores doubled spaces inside the answer', () {
      expect(conj('sommes   allés', 'sommes allés').rating, Rating.good);
    });
  });

  group('apostrophe normalisation', () {
    test("’ and ' are the same", () {
      expect(conj("j'aime", 'j’aime').rating, Rating.good);
      expect(conj('j’aime', "j'aime").rating, Rating.good);
    });

    test('a space after the apostrophe is ignored', () {
      expect(conj("j' aime", 'j’aime').rating, Rating.good);
    });

    test("l' and l’ are the same article", () {
      expect(vocab("l'école", ecole).rating, Rating.good);
      expect(vocab("l' école", ecole).rating, Rating.good);
    });
  });

  group('accent-only errors', () {
    test('are Hard, with the accents highlighted', () {
      final g = conj('sommes alles', 'sommes allés');
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.accent);
      expect(g.answer, 'sommes allés');
      expect(g.errors, [const Span(10, 11)]);
    });

    test('a wrong accent counts like a missing one', () {
      expect(conj('me léve', 'me lève').rating, Rating.hard);
      expect(conj('me lève', 'me leve').rating, Rating.hard);
    });

    test('in Vocabulary too', () {
      final g = vocab('ecole', ecole);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.accent);
      expect(g.answer, 'école');
      expect(g.errors, [const Span(0, 1)]);
    });

    test('oe for œ is an accent slip', () {
      // A made-up token: no spec example contains œ.
      final g = conj('boez', 'bœz');
      expect(g.rating, Rating.hard);
      expect(g.errors, [const Span(1, 2)]);
    });

    test('a different letter is not an accent slip', () {
      expect(conj('sommes allos', 'sommes allés').rating, Rating.again);
    });
  });

  group('wrong answers', () {
    test('are Again, showing the first accepted answer', () {
      final g = conj('allons', 'sommes allés');
      expect(g.rating, Rating.again);
      expect(g.errorType, ErrorType.wrong);
      expect(g.answer, 'sommes allés');
      expect(g.canMarkTypo, isTrue);
      expect(g.canMarkTooEasy, isFalse);
    });

    test('an empty answer is wrong', () {
      expect(conj('', 'vais').rating, Rating.again);
      expect(vocab('   ', chien).rating, Rating.again);
    });

    test(
      'a Vocabulary answer shows the noun, with an article if mandatory',
      () {
        expect(vocab('chat', chien).answer, 'chien');
        expect(vocab('chat', chien, mandatory: true).answer, 'un chien');
      },
    );
  });

  group('alternative forms', () {
    test('any listed alternative is Good', () {
      expect(conj('paie', 'paie', alternatives: ['paye']).rating, Rating.good);
      final alt = conj('paye', 'paie', alternatives: ['paye']);
      expect(alt.rating, Rating.good);
      expect(alt.answer, 'paye');
    });

    test('any listed synonym is Good', () {
      final g = vocab('auto', voiture);
      expect(g.rating, Rating.good);
      expect(g.answer, 'auto');
    });

    test('a synonym takes the noun’s articles', () {
      expect(vocab('une auto', voiture, mandatory: true).rating, Rating.good);
      expect(vocab('un auto', voiture, mandatory: true).rating, Rating.hard);
    });

    test('an exact match wins over an accent match on another form', () {
      // Two accepted forms differing only by an accent: typing either is
      // exact, not an accent slip on the other.
      expect(
        conj('allés', 'alles', alternatives: ['allés']).rating,
        Rating.good,
      );
    });
  });

  group('articles, when optional (the default)', () {
    test('no article is Good', () {
      expect(vocab('fourchette', fourchette).rating, Rating.good);
    });

    test('a right article is Good and shown', () {
      final definite = vocab('la fourchette', fourchette);
      expect(definite.rating, Rating.good);
      expect(definite.answer, 'la fourchette');
      expect(vocab('une fourchette', fourchette).answer, 'une fourchette');
    });

    test('a wrong article typed anyway is Hard, highlighted', () {
      final g = vocab('le fourchette', fourchette);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.article);
      expect(g.answer, 'la fourchette');
      expect(g.errors, [const Span(0, 2)]);
    });

    test('an indefinite answer is corrected with an indefinite article', () {
      final g = vocab('un fourchette', fourchette);
      expect(g.answer, 'une fourchette');
      expect(g.errors, [const Span(0, 3)]);
    });

    test('l’ is right for a noun that takes it', () {
      final g = vocab('l’école', ecole);
      expect(g.rating, Rating.good);
      expect(g.answer, 'l’école');
    });

    test('la before a noun that takes l’ is wrong', () {
      final g = vocab('la école', ecole);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.article);
      expect(g.answer, 'une école');
    });

    test('l’ before a noun that does not take it is wrong', () {
      expect(vocab('l’chien', chien).rating, Rating.hard);
    });
  });

  group('articles, when mandatory', () {
    test('le/la or un/une matching the gender is Good', () {
      for (final typed in ['la fourchette', 'une fourchette']) {
        expect(vocab(typed, fourchette, mandatory: true).rating, Rating.good);
      }
      for (final typed in ['le chien', 'un chien']) {
        expect(vocab(typed, chien, mandatory: true).rating, Rating.good);
      }
    });

    test('a missing article is Hard, shown with the indefinite article', () {
      final g = vocab('fourchette', fourchette, mandatory: true);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.article);
      expect(g.answer, 'une fourchette');
      expect(g.errors, [const Span(0, 3)]);
    });

    test('the wrong gender is Hard', () {
      expect(vocab('la chien', chien, mandatory: true).rating, Rating.hard);
      expect(
        vocab('un fourchette', fourchette, mandatory: true).rating,
        Rating.hard,
      );
    });

    test('a plural article on a singular noun is Hard', () {
      expect(vocab('les chien', chien, mandatory: true).rating, Rating.hard);
      expect(vocab('des chien', chien, mandatory: true).rating, Rating.hard);
    });

    test('only un/une for a noun that takes l’, since l’ hides the gender', () {
      expect(vocab('une école', ecole, mandatory: true).rating, Rating.good);
      final elided = vocab('l’école', ecole, mandatory: true);
      expect(elided.rating, Rating.hard);
      expect(elided.errorType, ErrorType.article);
      expect(elided.answer, 'une école');
      expect(elided.errors, [const Span(0, 3)]);
    });

    test('either gender for a "les deux" noun', () {
      expect(vocab('un élève', eleve, mandatory: true).rating, Rating.good);
      expect(vocab('une élève', eleve, mandatory: true).rating, Rating.good);
      expect(vocab('l’élève', eleve, mandatory: true).rating, Rating.hard);
      expect(vocab('l’élève', eleve).rating, Rating.good);
    });

    test('les or des for a plural-only noun', () {
      expect(
        vocab('les ciseaux', ciseaux, mandatory: true).rating,
        Rating.good,
      );
      expect(
        vocab('des ciseaux', ciseaux, mandatory: true).rating,
        Rating.good,
      );
      final singular = vocab('le ciseaux', ciseaux, mandatory: true);
      expect(singular.rating, Rating.hard);
      expect(singular.answer, 'les ciseaux');
      final missing = vocab('ciseaux', ciseaux, mandatory: true);
      expect(missing.answer, 'des ciseaux');
    });

    test('wrong article and an accent slip together are Hard', () {
      final g = vocab('la ecole', ecole, mandatory: true);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.article);
      expect(g.answer, 'une école');
      expect(g.errors, [const Span(0, 3), const Span(4, 5)]);
    });

    test('an accent slip with the right article is Hard, accent only', () {
      final g = vocab('une ecole', ecole, mandatory: true);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.accent);
      expect(g.errors, [const Span(4, 5)]);
    });
  });

  group('the red-letter cap', () {
    test('an exact answer flagged while typing is at most Hard', () {
      final g = conj('sommes allés', 'sommes allés', flagged: true);
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.none);
      expect(g.canMarkTooEasy, isFalse);
      expect(g.canMarkTypo, isFalse);
    });

    test('also in Vocabulary', () {
      expect(
        vocab('la fourchette', fourchette, flagged: true).rating,
        Rating.hard,
      );
    });

    test('Hard and Again answers are unchanged', () {
      expect(
        conj('sommes alles', 'sommes allés', flagged: true).rating,
        Rating.hard,
      );
      expect(conj('vont', 'sommes allés', flagged: true).rating, Rating.again);
      expect(vocab('chat', chien, flagged: true).rating, Rating.again);
    });

    test('Easy is capped too', () {
      const easy = Grade(rating: Rating.easy, errorType: ErrorType.none);
      expect(easy.capAtHard().rating, Rating.hard);
    });
  });

  group('overrides', () {
    test('Faute de frappe turns an Incorrect answer into Hard', () {
      final g = conj('vont', 'vais').markTypo();
      expect(g.rating, Rating.hard);
      expect(g.errorType, ErrorType.typoOverride);
      expect(g.answer, 'vais');
    });

    test('Faute de frappe is not offered after Presque or Je ne sais pas', () {
      final almost = conj('me leve', 'me lève');
      expect(almost.canMarkTypo, isFalse);
      expect(almost.markTypo, throwsStateError);
      const gaveUp = Grade.gaveUp('vais');
      expect(gaveUp.canMarkTypo, isFalse);
    });

    test('Trop facile turns a Correct answer into Easy', () {
      final g = conj('vais', 'vais').markTooEasy();
      expect(g.rating, Rating.easy);
      expect(g.errorType, ErrorType.none);
    });

    test('Trop facile is not offered after Presque', () {
      final almost = conj('me leve', 'me lève');
      expect(almost.canMarkTooEasy, isFalse);
      expect(almost.markTooEasy, throwsStateError);
    });
  });

  group('Je ne sais pas', () {
    test('is Again, logged as gave up, showing the answer', () {
      const g = Grade.gaveUp('sommes allés');
      expect(g.rating, Rating.again);
      expect(g.errorType, ErrorType.gaveUp);
      expect(g.answer, 'sommes allés');
      expect(g.canMarkTooEasy, isFalse);
    });

    test('shows a Vocabulary answer with its article when mandatory', () {
      expect(fourchette.displayAnswer(mandatory: true), 'une fourchette');
      expect(fourchette.displayAnswer(mandatory: false), 'fourchette');
      expect(ecole.displayAnswer(mandatory: true), 'une école');
      expect(ciseaux.displayAnswer(mandatory: true), 'des ciseaux');
    });
  });

  group('Grade', () {
    test('equality and description', () {
      final a = conj('sommes alles', 'sommes allés');
      final b = conj('sommes alles', 'sommes allés');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(conj('sommes allés', 'sommes allés')));
      expect(a, isNot(conj('sommes allés', 'sommes alles')));
      expect(a.toString(), contains('accent'));
      expect(const Span(1, 2).toString(), 'Span(1, 2)');
    });

    test('stored error types', () {
      expect(ErrorType.values.map((e) => e.id), [
        'none',
        'accent',
        'article',
        'wrong',
        'typo_override',
        'gave_up',
      ]);
    });
  });

  test('splitArticle', () {
    expect(splitArticle('la table'), (article: 'la', rest: 'table'));
    expect(splitArticle('l’école'), (article: 'l’', rest: 'école'));
    expect(splitArticle('lampe'), (article: null, rest: 'lampe'));
    expect(splitArticle('les'), (article: null, rest: 'les'));
  });
}
