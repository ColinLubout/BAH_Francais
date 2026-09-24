import 'package:bah_francais/core/time/clock.dart';

/// A clock tests move by hand, including its time zone.
class FakeClock implements Clock {
  FakeClock(DateTime nowUtc, {this.offset = Duration.zero})
    : assert(nowUtc.isUtc, 'FakeClock takes UTC times'),
      _now = nowUtc;

  DateTime _now;

  /// How far local time is ahead of UTC. Changing it is a new time zone, or a
  /// daylight-saving change.
  Duration offset;

  @override
  DateTime nowUtc() => _now;

  @override
  Duration utcOffset() => offset;

  void advance(Duration by) => _now = _now.add(by);

  /// Sets the time, which may go backwards.
  void setNow(DateTime nowUtc) {
    assert(nowUtc.isUtc, 'FakeClock takes UTC times');
    _now = nowUtc;
  }
}
