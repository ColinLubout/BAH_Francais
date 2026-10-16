import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:meta/meta.dart';

/// Why an answer was not simply right, as the review log records it.
enum ErrorType {
  none('none'),

  /// Right apart from the accents.
  accent('accent'),

  /// The right word with a wrong or missing article.
  article('article'),

  wrong('wrong'),

  /// The user changed an Incorrect answer to Hard with *Faute de frappe*.
  typoOverride('typo_override'),

  /// *Je ne sais pas*.
  gaveUp('gave_up');

  ErrorType(this.id);

  /// The value stored in the review log.
  final String id;
}

/// A range of characters, from [start] up to but not including [end].
@immutable
class Span {
  const Span(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}

/// The grade of one answer.
@immutable
class Grade {
  const Grade({
    required this.rating,
    required this.errorType,
    this.answer,
    this.errors = const [],
    this.tooEasyOffered = true,
  });

  /// *Je ne sais pas*: Again, and the answer is shown.
  const Grade.gaveUp(String this.answer)
    : rating = Rating.again,
      errorType = ErrorType.gaveUp,
      errors = const [],
      tooEasyOffered = false;

  final Rating rating;
  final ErrorType errorType;

  /// The correct answer as the feedback panel shows it; null in the Gender
  /// drill, whose feedback is built from the noun.
  final String? answer;

  /// The parts of [answer] the user got wrong (accents, article), to
  /// highlight.
  final List<Span> errors;

  /// Whether this drill offers *Trop facile* at all: the Gender drill moves
  /// on after a second, so it does not.
  final bool tooEasyOffered;

  /// *Faute de frappe* follows an Incorrect answer, but not *Je ne sais pas*.
  bool get canMarkTypo =>
      rating == Rating.again && errorType == ErrorType.wrong;

  /// *Trop facile* follows a Correct answer (graded Good).
  bool get canMarkTooEasy => tooEasyOffered && rating == Rating.good;

  /// *Faute de frappe*: the answer becomes Hard.
  Grade markTypo() {
    if (!canMarkTypo) throw StateError('Faute de frappe is not offered');
    return _copy(rating: Rating.hard, errorType: ErrorType.typoOverride);
  }

  /// *Trop facile*: the answer becomes Easy.
  Grade markTooEasy() {
    if (!canMarkTooEasy) throw StateError('Trop facile is not offered');
    return _copy(rating: Rating.easy);
  }

  /// Caps the grade at Hard: a letter went red or orange while typing.
  Grade capAtHard() => rating == Rating.good || rating == Rating.easy
      ? _copy(rating: Rating.hard)
      : this;

  Grade _copy({Rating? rating, ErrorType? errorType}) => Grade(
    rating: rating ?? this.rating,
    errorType: errorType ?? this.errorType,
    answer: answer,
    errors: errors,
    tooEasyOffered: tooEasyOffered,
  );

  @override
  bool operator ==(Object other) =>
      other is Grade &&
      other.rating == rating &&
      other.errorType == errorType &&
      other.answer == answer &&
      _sameSpans(other.errors, errors) &&
      other.tooEasyOffered == tooEasyOffered;

  @override
  int get hashCode =>
      Object.hash(rating, errorType, answer, Object.hashAll(errors));

  @override
  String toString() =>
      'Grade(${rating.name}, ${errorType.id}, $answer, $errors)';
}

bool _sameSpans(List<Span> a, List<Span> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
