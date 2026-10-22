import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';

/// Grades a Gender answer: right is Good, wrong is Again. A "les deux" noun
/// needs *les deux*.
Grade gradeGender({required Gender correct, required Gender chosen}) =>
    chosen == correct
    ? const Grade(rating: Rating.good, errorType: ErrorType.none)
    : const Grade(rating: Rating.again, errorType: ErrorType.wrong);

/// Grades a Conjugation answer against the sentence's [answer] and its
/// [alternatives] (*paie* / *paye*).
///
/// Exact is Good; right apart from accents is Hard; anything else is Again.
/// [flaggedWhileTyping] means a letter went red or orange during typing, which
/// caps the grade at Hard even if it was corrected.
Grade gradeConjugation({
  required String typed,
  required String answer,
  List<String> alternatives = const [],
  bool flaggedWhileTyping = false,
}) {
  final grade = _gradeWords(normalise(typed), [answer, ...alternatives]);
  return flaggedWhileTyping ? grade.capAtHard() : grade;
}

/// Grades a Vocabulary answer.
///
/// Any accepted word, exact and with a right article or none, is Good. A
/// right word with only accent slips, or with a wrong article, or both, is
/// Hard. Anything else is Again. [flaggedWhileTyping] caps the grade at
/// Hard.
Grade gradeVocabulary({
  required String typed,
  required VocabularyAnswer noun,
  bool flaggedWhileTyping = false,
}) {
  final (:article, :rest) = splitArticle(normalise(typed));
  final accepted = noun.accepted;
  final match = _matchWord(rest, [for (final w in accepted) w.word]);
  if (match == null) {
    final grade = Grade(
      rating: Rating.again,
      errorType: ErrorType.wrong,
      answer: noun.word,
    );
    return flaggedWhileTyping ? grade.capAtHard() : grade;
  }

  // The articles go by the word typed: a synonym has its own.
  final matched = accepted[match.index];
  final articleOk =
      article == null || matched.validArticles().contains(article);

  final errors = <Span>[];
  String shown;
  if (article != null) {
    final shownArticle = matched.displayArticle(article);
    shown = joinArticle(shownArticle, matched.word);
    final wordStart = shown.length - matched.word.length;
    // Highlight the article itself, not the space after it.
    if (!articleOk) errors.add(Span(0, shownArticle.length));
    errors.addAll([
      for (final span in match.accentErrors)
        Span(span.start + wordStart, span.end + wordStart),
    ]);
  } else {
    shown = matched.word;
    errors.addAll(match.accentErrors);
  }

  final exact = match.accentErrors.isEmpty;
  final grade = Grade(
    rating: exact && articleOk ? Rating.good : Rating.hard,
    errorType: !articleOk
        ? ErrorType.article
        : exact
        ? ErrorType.none
        : ErrorType.accent,
    answer: shown,
    errors: errors,
  );
  return flaggedWhileTyping ? grade.capAtHard() : grade;
}

/// Grades [typed] (normalised) against accepted [forms]: exact is Good,
/// accents only is Hard, anything else is Again.
Grade _gradeWords(String typed, List<String> forms) {
  final match = _matchWord(typed, forms);
  if (match == null) {
    return Grade(
      rating: Rating.again,
      errorType: ErrorType.wrong,
      answer: forms.first,
    );
  }
  final exact = match.accentErrors.isEmpty;
  return Grade(
    rating: exact ? Rating.good : Rating.hard,
    errorType: exact ? ErrorType.none : ErrorType.accent,
    answer: forms[match.index],
    errors: match.accentErrors,
  );
}

/// The index of the accepted form [typed] matches, exactly if possible, else
/// apart from accents; null if none.
({int index, List<Span> accentErrors})? _matchWord(
  String typed,
  List<String> forms,
) {
  for (final (index, form) in forms.indexed) {
    if (normalise(form) == typed) return (index: index, accentErrors: const []);
  }
  final folded = foldAccents(typed);
  for (final (index, form) in forms.indexed) {
    final expected = normalise(form);
    if (foldAccents(expected) == folded) {
      return (index: index, accentErrors: accentSpans(expected, typed));
    }
  }
  return null;
}
