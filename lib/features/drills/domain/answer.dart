import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:meta/meta.dart';

/// An answer as the review log records it.
@immutable
class Answer {
  const Answer({
    required this.outcome,
    required this.sessionId,
    required this.responseTime,
    required this.errorType,
    this.typed,
  });

  final ReviewOutcome outcome;
  final int sessionId;

  /// From the prompt appearing to the answer being submitted.
  final Duration responseTime;
  final ErrorType errorType;

  /// What the user typed, or the gender they chose; null for *Je ne sais
  /// pas*.
  final String? typed;

  /// Counted as correct in the session: anything but Again.
  bool get correct => outcome.rating != Rating.again;
}
