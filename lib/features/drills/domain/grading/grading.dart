import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';

/// Grades a Gender answer: right is Good, wrong is Again. A "les deux" noun
/// needs *les deux*. The drill moves on by itself after a right answer, so it
/// offers no *Trop facile*.
Grade gradeGender({required Gender correct, required Gender chosen}) =>
    chosen == correct
    ? const Grade(
        rating: Rating.good,
        errorType: ErrorType.none,
        tooEasyOffered: false,
      )
    : const Grade(
        rating: Rating.again,
        errorType: ErrorType.wrong,
        tooEasyOffered: false,
      );

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
/// Any accepted word, exact and with an accepted article (or none, when the
/// article is optional), is Good. A right word with only accent slips, or
/// with a wrong or missing article, or both, is Hard. Anything else is
/// Again. [flaggedWhileTyping] caps the grade at Hard.
Grade gradeVocabulary({
  required String typed,
  required VocabularyAnswer noun,
  required bool articleMandatory,
  bool flaggedWhileTyping = false,
}) {
  final (:article, :rest) = splitArticle(normalise(typed));
  final match = _matchWord(rest, noun.words);
  if (match == null) {
    final grade = Grade(
      rating: Rating.again,
      errorType: ErrorType.wrong,
      answer: noun.displayAnswer(mandatory: articleMandatory),
    );
    return flaggedWhileTyping ? grade.capAtHard() : grade;
  }

  final valid = noun.validArticles(mandatory: articleMandatory);
  final articleOk = article == null
      ? !articleMandatory
      : valid.contains(article);
  final showArticle = article != null || articleMandatory;

  final errors = <Span>[];
  String shown;
  if (showArticle) {
    final shownArticle = noun.displayArticle(
      mandatory: articleMandatory,
      typed: article,
    );
    shown = joinArticle(shownArticle, match.word);
    final wordStart = shown.length - match.word.length;
    // Highlight the article itself, not the space after it.
    if (!articleOk) errors.add(Span(0, shownArticle.length));
    errors.addAll([
      for (final span in match.accentErrors)
        Span(span.start + wordStart, span.end + wordStart),
    ]);
  } else {
    shown = match.word;
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
    answer: match.word,
    errors: match.accentErrors,
  );
}

/// The accepted form [typed] matches, exactly if possible, else apart from
/// accents; null if none.
({String word, List<Span> accentErrors})? _matchWord(
  String typed,
  List<String> forms,
) {
  for (final form in forms) {
    if (normalise(form) == typed) return (word: form, accentErrors: const []);
  }
  final folded = foldAccents(typed);
  for (final form in forms) {
    final expected = normalise(form);
    if (foldAccents(expected) == folded) {
      return (word: form, accentErrors: accentSpans(expected, typed));
    }
  }
  return null;
}
