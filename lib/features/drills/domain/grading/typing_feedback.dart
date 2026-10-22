import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:meta/meta.dart';

/// How a typed letter compares with the answer, as *Correction en direct*
/// shows it.
enum LetterState {
  /// Green, underlined: the letter matches.
  correct,

  /// Orange, dotted underline: right apart from its accent.
  accentOnly,

  /// Red: the answer so far matches no accepted form.
  wrong,
}

/// Live feedback on what has been typed so far: one state per character.
@immutable
class TypingFeedback {
  const TypingFeedback(this.letters);

  /// One per character of the typed text, in order.
  final List<LetterState> letters;

  /// The answer so far matches nothing: every letter is red and a ✗ shows.
  bool get isWrong => letters.contains(LetterState.wrong);

  /// A letter is red or orange, which caps the grade at Hard even if it is
  /// corrected before the answer is submitted.
  bool get capsGrade => letters.any((l) => l != LetterState.correct);

  @override
  bool operator ==(Object other) {
    if (other is! TypingFeedback || other.letters.length != letters.length) {
      return false;
    }
    for (var i = 0; i < letters.length; i++) {
      if (other.letters[i] != letters[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(letters);

  @override
  String toString() => 'TypingFeedback($letters)';
}

/// Checks [typed] letter by letter against the start of each accepted form
/// in [forms], after normalisation: case is ignored, ’ and ' are the same, and
/// spaces that normalisation drops (leading, doubled, after an apostrophe)
/// count as right.
///
/// The letters take the states of the form they fit best: one they match
/// exactly, else the one with the fewest accent slips. If none fits, every
/// letter is wrong.
TypingFeedback typingFeedback(String typed, List<String> forms) {
  if (typed.isEmpty) return const TypingFeedback([]);
  List<LetterState>? best;
  var bestSlips = 0;
  for (final form in forms) {
    final states = _against(typed, normalise(form));
    if (states == null) continue;
    final slips = states.where((s) => s == LetterState.accentOnly).length;
    if (best == null || slips < bestSlips) {
      best = states;
      bestSlips = slips;
    }
    if (slips == 0) break;
  }
  return TypingFeedback(best ?? List.filled(typed.length, LetterState.wrong));
}

/// [typed]'s letters against the start of [form], or null if a letter
/// doesn't fit or [typed] runs past it.
List<LetterState>? _against(String typed, String form) {
  final states = <LetterState>[];
  var j = 0;
  String? previous;
  for (final unit in typed.split('')) {
    final c = _key(unit);
    final ignoredSpace =
        c == ' ' && (j == 0 || previous == ' ' || previous == apostrophe);
    previous = c;
    if (ignoredSpace) {
      states.add(LetterState.correct);
      continue;
    }
    if (j >= form.length) return null;
    final expected = form[j++];
    if (c == expected) {
      states.add(LetterState.correct);
    } else if (foldAccents(c) == foldAccents(expected)) {
      states.add(LetterState.accentOnly);
    } else {
      return null;
    }
  }
  return states;
}

/// A typed character as normalisation leaves it: lower case, ’ for '.
String _key(String unit) {
  if (unit == "'") return apostrophe;
  final lower = unit.toLowerCase();
  return lower.length == 1 ? lower : unit;
}
