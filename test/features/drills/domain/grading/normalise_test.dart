import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalise', () {
    test('trims and ignores case', () {
      expect(normalise('  Table \n'), 'table');
      expect(normalise('ÉCOLE'), 'école');
    });

    test("treats ’ and ' as the same", () {
      expect(normalise("j'aime"), normalise('j’aime'));
      expect(normalise("J'AIME"), 'j’aime');
    });

    test('collapses runs of spaces, including non-breaking ones', () {
      expect(normalise('sommes   allés'), 'sommes allés');
      expect(normalise('sommes allés'), 'sommes allés');
      expect(normalise('sommes\tallés'), 'sommes allés');
    });

    test('ignores a space after an apostrophe', () {
      expect(normalise("j' aime"), 'j’aime');
      expect(normalise('l’  école'), 'l’école');
    });
  });

  group('foldAccents', () {
    test('removes French accents', () {
      expect(foldAccents('àâäçéèêëîïôöùûüÿ'), 'aaaceeeeiioouuuy');
    });

    test('writes œ and æ as two letters', () {
      expect(foldAccents('œæ'), 'oeae');
    });

    test('leaves other characters alone', () {
      expect(foldAccents('table’s 1'), 'table’s 1');
    });
  });

  group('accentSpans', () {
    test('marks each letter whose accent differs', () {
      expect(accentSpans('école', 'ecole'), [const Span(0, 1)]);
      expect(accentSpans('sommes allés', 'sommes alles'), [const Span(10, 11)]);
      expect(accentSpans('élève', 'eleve'), [
        const Span(0, 1),
        const Span(2, 3),
      ]);
    });

    test('marks a wrong accent as well as a missing one', () {
      expect(accentSpans('allés', 'allès'), [const Span(3, 4)]);
    });

    test('handles œ typed as oe and oe typed as œ', () {
      // Made-up tokens: no spec example contains œ.
      expect(accentSpans('bœz', 'boez'), [const Span(1, 2)]);
      expect(accentSpans('boez', 'bœz'), [const Span(1, 3)]);
    });

    test('marks the rest if the difference is not only accents', () {
      expect(accentSpans('table', 'tbxle'), [const Span(1, 5)]);
    });

    test('nothing to mark when equal', () {
      expect(accentSpans('table', 'table'), isEmpty);
    });
  });
}
