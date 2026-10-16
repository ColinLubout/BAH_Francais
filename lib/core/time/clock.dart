/// The source of the current time.
///
/// Everything time-dependent asks a [Clock], never `DateTime.now()`, so tests
/// can control both the time and the local time zone.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();

  /// How far local time is ahead of UTC right now. It changes with the time
  /// zone and daylight saving; from the moment it does, the new local time
  /// applies.
  Duration utcOffset();
}

/// The phone's clock and time zone.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration utcOffset() => DateTime.now().timeZoneOffset;
}
