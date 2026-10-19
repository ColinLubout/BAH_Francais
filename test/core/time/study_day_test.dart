import 'package:bah_francais/core/time/clock.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_clock.dart';

const paris = Duration(hours: 2); // summer time
const parisWinter = Duration(hours: 1);

void main() {
  group('the 04:00 boundary', () {
    test('03:59 local belongs to the previous day, 04:00 to the new one', () {
      // 03:59 in Paris (UTC+2) is 01:59 UTC.
      expect(
        StudyDay.of(DateTime.utc(2026, 9, 24, 1, 59), paris),
        const StudyDay(2026, 9, 23),
      );
      expect(
        StudyDay.of(DateTime.utc(2026, 9, 24, 2), paris),
        const StudyDay(2026, 9, 24),
      );
    });

    test('midnight to 04:00 is still the previous day', () {
      expect(
        StudyDay.of(DateTime.utc(2026, 9, 24), Duration.zero),
        const StudyDay(2026, 9, 23),
      );
    });

    test('crosses months and years', () {
      expect(
        StudyDay.of(DateTime.utc(2027, 1, 1, 3), Duration.zero),
        const StudyDay(2026, 12, 31),
      );
      expect(const StudyDay(2026, 12, 31).next, const StudyDay(2027, 1, 1));
      expect(const StudyDay(2028, 2, 28).next, const StudyDay(2028, 2, 29));
    });

    test('a day starts and ends at 04:00 local, given in UTC', () {
      const day = StudyDay(2026, 9, 24);
      expect(day.startUtc(paris), DateTime.utc(2026, 9, 24, 2));
      expect(day.endUtc(paris), DateTime.utc(2026, 9, 25, 2));
      expect(
        day.startUtc(const Duration(hours: -5)),
        DateTime.utc(2026, 9, 24, 9),
      );
    });

    test('an instant before its day ends belongs to it', () {
      const day = StudyDay(2026, 9, 24);
      final lastMoment = day
          .endUtc(paris)
          .subtract(const Duration(microseconds: 1));
      expect(StudyDay.of(lastMoment, paris), day);
      expect(StudyDay.of(day.endUtc(paris), paris), day.next);
    });
  });

  group('clock and time-zone changes', () {
    test('daylight saving ending makes the day 25 hours long', () {
      // Paris leaves summer time on 25 October 2026 at 03:00 local (01:00
      // UTC). The 24 October study day starts at 04:00 summer time.
      const day = StudyDay(2026, 10, 24);
      final start = day.startUtc(paris);

      // 02:30 UTC on the 25th is 03:30 winter time: still the 24th.
      expect(StudyDay.of(DateTime.utc(2026, 10, 25, 2, 30), parisWinter), day);
      // 03:00 UTC is 04:00 winter time: the next day begins.
      final end = DateTime.utc(2026, 10, 25, 3);
      expect(StudyDay.of(end, parisWinter), day.next);
      expect(end.difference(start), const Duration(hours: 25));
    });

    test('daylight saving starting makes the day 23 hours long', () {
      // Summer time starts on 29 March 2026 at 02:00 local (01:00 UTC).
      const day = StudyDay(2026, 3, 28);
      final start = day.startUtc(parisWinter); // 03:00 UTC on the 28th
      final end = DateTime.utc(2026, 3, 29, 2); // 04:00 summer time
      expect(StudyDay.of(end.subtract(const Duration(seconds: 1)), paris), day);
      expect(StudyDay.of(end, paris), day.next);
      expect(end.difference(start), const Duration(hours: 23));
    });

    test('a time-zone change applies from that moment on', () {
      // 05:00 in Paris on the 24th: a new study day has started.
      final clock = FakeClock(DateTime.utc(2026, 9, 24, 3), offset: paris);
      expect(StudyDay.today(clock), const StudyDay(2026, 9, 24));

      // The phone moves to New York (UTC-4): it is now 23:00 on the 23rd
      // there, so the same instant is back in the 23rd's study day.
      clock.offset = const Duration(hours: -4);
      expect(StudyDay.today(clock), const StudyDay(2026, 9, 23));

      // Five hours later it is 04:00 in New York: the 24th begins again.
      clock.advance(const Duration(hours: 5));
      expect(StudyDay.today(clock), const StudyDay(2026, 9, 24));
    });

    test('the clock going backwards can return to the previous day', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 24, 10), offset: paris);
      expect(StudyDay.today(clock), const StudyDay(2026, 9, 24));
      clock.setNow(DateTime.utc(2026, 9, 24, 1));
      expect(StudyDay.today(clock), const StudyDay(2026, 9, 23));
    });
  });

  group('storage and comparison', () {
    test('the key is yyyymmdd and round-trips', () {
      const day = StudyDay(2026, 9, 4);
      expect(day.key, 20260904);
      expect(StudyDay.fromKey(20260904), day);
      expect(day.toString(), '2026-09-04');
    });

    test('days compare in order', () {
      const a = StudyDay(2026, 9, 24);
      const b = StudyDay(2026, 10, 1);
      expect(a < b, isTrue);
      expect(b < a, isFalse);
      expect(a.compareTo(b), lessThan(0));
      expect(a, const StudyDay(2026, 9, 24));
      expect(a.hashCode, const StudyDay(2026, 9, 24).hashCode);
    });
  });

  test('SystemClock gives UTC now and the local offset', () {
    const clock = SystemClock();
    final now = clock.nowUtc();
    expect(now.isUtc, isTrue);
    expect(
      now.difference(DateTime.now().toUtc()).abs(),
      lessThan(const Duration(seconds: 5)),
    );
    expect(clock.utcOffset(), DateTime.now().timeZoneOffset);
  });
}
