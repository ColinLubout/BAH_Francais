import 'package:bah_francais/core/time/clock.dart';
import 'package:meta/meta.dart';

/// A study day: from 04:00 local time to 04:00 the next day.
///
/// Times are stored in UTC; the local offset in force decides which study day
/// an instant belongs to. When the offset changes (a new time zone, daylight
/// saving), the new local time applies from then on, so a day can be shorter
/// or longer than 24 hours. Reviews store the study day they were given on,
/// so a change never moves them to another day.
@immutable
class StudyDay implements Comparable<StudyDay> {
  const StudyDay(this.year, this.month, this.day);

  /// The study day [instant] falls in, when local time is [utcOffset] ahead
  /// of UTC.
  factory StudyDay.of(DateTime instant, Duration utcOffset) {
    final shifted = instant.toUtc().add(utcOffset).subtract(startsAt);
    return StudyDay(shifted.year, shifted.month, shifted.day);
  }

  /// Today, by [clock].
  factory StudyDay.today(Clock clock) =>
      StudyDay.of(clock.nowUtc(), clock.utcOffset());

  /// The day stored as [key] (see [key]).
  factory StudyDay.fromKey(int key) =>
      StudyDay(key ~/ 10000, key ~/ 100 % 100, key % 100);

  /// Local time at which a study day begins.
  static const startsAt = Duration(hours: 4);

  final int year;
  final int month;
  final int day;

  /// The day as one number, `yyyymmdd`, for storage: 2026-09-24 is 20260924.
  int get key => year * 10000 + month * 100 + day;

  StudyDay get next {
    final date = DateTime.utc(year, month, day + 1);
    return StudyDay(date.year, date.month, date.day);
  }

  /// When this day begins, in UTC, if local time is [utcOffset] ahead of UTC.
  DateTime startUtc(Duration utcOffset) =>
      DateTime.utc(year, month, day).add(startsAt).subtract(utcOffset);

  /// When this day ends (the next one begins), in UTC, if local time is
  /// [utcOffset] ahead of UTC.
  DateTime endUtc(Duration utcOffset) => next.startUtc(utcOffset);

  @override
  int compareTo(StudyDay other) => key.compareTo(other.key);

  bool operator <(StudyDay other) => key < other.key;

  @override
  bool operator ==(Object other) => other is StudyDay && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
