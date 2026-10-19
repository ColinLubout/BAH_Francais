import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/fsrs/fsrs.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// No fuzz, so intervals are exact.
DrillScheduler scheduler({double retention = 0.9}) =>
    DrillScheduler(targetRetention: retention, random: () => 0.5);

ReviewOutcome answer(
  DrillScheduler s,
  DrillCard card,
  Rating rating, [
  DateTime? at,
]) {
  final when = at ?? noon;
  return s.review(card, rating, at: when, day: StudyDay.of(when, paris));
}

/// A card taken through its learning steps into review, then left until due.
DrillCard graduated(DrillScheduler s) {
  var card = answer(s, newCard(), Rating.good).after;
  card = answer(s, card, Rating.good, card.due).after;
  expect(card.state, CardState.review);
  return card;
}

Duration intervalOf(ReviewOutcome o) => o.after.due!.difference(o.reviewedAt);

void main() {
  group('each rating from each state', () {
    final s = scheduler();

    group('new card', () {
      test('Again: learning, back in about a minute', () {
        final o = answer(s, newCard(), Rating.again);
        expect(o.after.state, CardState.learning);
        expect(o.after.step, 0);
        expect(intervalOf(o), const Duration(minutes: 1));
      });

      test('Hard: learning, back in 5.5 minutes', () {
        final o = answer(s, newCard(), Rating.hard);
        expect(o.after.state, CardState.learning);
        expect(o.after.step, 0);
        expect(intervalOf(o), const Duration(minutes: 5, seconds: 30));
      });

      test('Good: learning, next step in 10 minutes', () {
        final o = answer(s, newCard(), Rating.good);
        expect(o.after.state, CardState.learning);
        expect(o.after.step, 1);
        expect(intervalOf(o), const Duration(minutes: 10));
      });

      test('Easy: straight to review, in days', () {
        final o = answer(s, newCard(), Rating.easy);
        expect(o.after.state, CardState.review);
        expect(o.after.step, isNull);
        expect(o.scheduledDays, greaterThanOrEqualTo(1));
      });
    });

    group('learning card at its second step', () {
      DrillCard atStep1() => answer(s, newCard(), Rating.good).after;

      test('Again: back to step 0, in a minute', () {
        final card = atStep1();
        final o = answer(s, card, Rating.again, card.due);
        expect(o.after.state, CardState.learning);
        expect(o.after.step, 0);
        expect(intervalOf(o), const Duration(minutes: 1));
      });

      test('Hard: repeats the step, in 10 minutes', () {
        final card = atStep1();
        final o = answer(s, card, Rating.hard, card.due);
        expect(o.after.state, CardState.learning);
        expect(o.after.step, 1);
        expect(intervalOf(o), const Duration(minutes: 10));
      });

      for (final rating in [Rating.good, Rating.easy]) {
        test('${rating.name}: graduates to review', () {
          final card = atStep1();
          final o = answer(s, card, rating, card.due);
          expect(o.after.state, CardState.review);
          expect(o.scheduledDays, greaterThanOrEqualTo(1));
        });
      }
    });

    group('review card', () {
      test('Again: relearning in 10 minutes, one lapse', () {
        final card = graduated(s);
        final o = answer(s, card, Rating.again, card.due);
        expect(o.after.state, CardState.relearning);
        expect(o.after.step, 0);
        expect(intervalOf(o), const Duration(minutes: 10));
        expect(o.after.lapses, card.lapses + 1);
        expect(o.after.stability, lessThan(card.stability!));
      });

      test('Hard, Good and Easy: longer intervals in that order', () {
        final card = graduated(s);
        final hard = answer(s, card, Rating.hard, card.due);
        final good = answer(s, card, Rating.good, card.due);
        final easy = answer(s, card, Rating.easy, card.due);
        for (final o in [hard, good, easy]) {
          expect(o.after.state, CardState.review);
          expect(o.after.lapses, card.lapses);
        }
        expect(hard.scheduledDays, lessThan(good.scheduledDays));
        expect(good.scheduledDays, lessThan(easy.scheduledDays));
      });
    });

    group('relearning card', () {
      DrillCard relearning() {
        final card = graduated(s);
        return answer(s, card, Rating.again, card.due).after;
      }

      test('Again: stays at step 0, in 10 minutes', () {
        final card = relearning();
        final o = answer(s, card, Rating.again, card.due);
        expect(o.after.state, CardState.relearning);
        expect(o.after.step, 0);
        expect(intervalOf(o), const Duration(minutes: 10));
        // Not a new lapse: it was not in review.
        expect(o.after.lapses, card.lapses);
      });

      test('Hard: repeats the step, in 15 minutes', () {
        final card = relearning();
        final o = answer(s, card, Rating.hard, card.due);
        expect(o.after.state, CardState.relearning);
        expect(intervalOf(o), const Duration(minutes: 15));
      });

      for (final rating in [Rating.good, Rating.easy]) {
        test('${rating.name}: back to review', () {
          final card = relearning();
          final o = answer(s, card, rating, card.due);
          expect(o.after.state, CardState.review);
          expect(o.scheduledDays, greaterThanOrEqualTo(1));
        });
      }
    });
  });

  group('early and late reviews', () {
    final s = scheduler();

    test('an early review raises stability less than one on time', () {
      final card = graduated(s);
      final lastReview = card.lastReview!;
      final early = answer(
        s,
        card,
        Rating.good,
        lastReview.add(const Duration(days: 1)),
      );
      final onTime = answer(s, card, Rating.good, card.due);
      expect(early.after.stability, greaterThan(card.stability!));
      expect(early.after.stability, lessThan(onTime.after.stability!));
      expect(early.after.state, CardState.review);
    });

    test('a late review raises stability more than one on time', () {
      final card = graduated(s);
      final onTime = answer(s, card, Rating.good, card.due);
      final late = answer(
        s,
        card,
        Rating.good,
        card.due!.add(const Duration(days: 30)),
      );
      expect(late.after.stability, greaterThan(onTime.after.stability!));
      expect(late.elapsedDays, greaterThan(onTime.elapsedDays!));
    });

    test('a same-day review of a review card changes little', () {
      final card = graduated(s);
      final lastReview = card.lastReview!;
      final o = answer(
        s,
        card,
        Rating.good,
        lastReview.add(const Duration(hours: 1)),
      );
      expect(o.after.state, CardState.review);
      expect(o.elapsedDays, 0);
    });
  });

  group('counts', () {
    final s = scheduler();

    test('every answer adds a rep', () {
      var card = newCard();
      for (var i = 1; i <= 3; i++) {
        card = answer(s, card, Rating.again).after;
        expect(card.reps, i);
      }
    });

    test('lapses count only failures of review cards', () {
      var card = newCard();
      card = answer(s, card, Rating.again).after; // learning
      expect(card.lapses, 0);
      card = graduated(s);
      card = answer(s, card, Rating.again, card.due).after;
      expect(card.lapses, 1);
    });
  });

  group('leeches', () {
    final s = scheduler();

    test('the eighth Again, in any state, makes a leech', () {
      var card = newCard();
      for (var i = 1; i <= 7; i++) {
        card = answer(s, card, Rating.again).after;
        expect(card.againCount, i);
        expect(card.isLeech, isFalse, reason: 'after $i');
      }
      card = answer(s, card, Rating.again).after;
      expect(card.againCount, 8);
      expect(card.isLeech, isTrue);
    });

    test('Agains in learning, review and relearning all count', () {
      var card = graduated(s);
      var at = card.due!;
      for (var i = 0; i < 8; i++) {
        final o = answer(s, card, Rating.again, at);
        card = o.after;
        at = card.due!;
        if (i.isEven) {
          // Back to review before failing again.
          card = answer(s, card, Rating.good, at).after;
          at = card.due!;
        }
      }
      expect(card.againCount, 8);
      expect(card.isLeech, isTrue);
    });

    test('the flag stays after the card is learned', () {
      var card = newCard();
      for (var i = 0; i < 8; i++) {
        card = answer(s, card, Rating.again).after;
      }
      for (var i = 0; i < 5; i++) {
        card = answer(s, card, Rating.good, card.due).after;
      }
      expect(card.isLeech, isTrue);
    });

    test('an Again overridden by Faute de frappe does not count', () {
      var card = newCard();
      for (var i = 0; i < 7; i++) {
        card = answer(s, card, Rating.again).after;
      }
      final eighth = answer(s, card, Rating.again);
      expect(eighth.after.isLeech, isTrue);
      final overridden = s.regrade(eighth, Rating.hard);
      expect(overridden.after.againCount, 7);
      expect(overridden.after.isLeech, isFalse);
    });
  });

  group('regrade', () {
    final s = scheduler();

    test('reschedules from the state before the answer, same time and day', () {
      final card = graduated(s);
      final first = answer(s, card, Rating.again, card.due);
      final regraded = s.regrade(first, Rating.hard);
      expect(regraded.before, card);
      expect(regraded.reviewedAt, first.reviewedAt);
      expect(regraded.studyDay, first.studyDay);
      expect(regraded.rating, Rating.hard);
      expect(regraded.after.state, CardState.review);
      expect(regraded.after.lapses, card.lapses);
      expect(regraded.after.reps, card.reps + 1);
    });

    test('Trop facile turns Good into Easy', () {
      final first = answer(s, newCard(), Rating.good);
      final easy = s.regrade(first, Rating.easy);
      expect(easy.after.state, CardState.review);
      expect(first.after.state, CardState.learning);
    });
  });

  group('target retention', () {
    test('defaults to 90% and accepts 80–97%', () {
      expect(DrillScheduler().targetRetention, 0.9);
      expect(() => DrillScheduler(targetRetention: 0.8), returnsNormally);
      expect(() => DrillScheduler(targetRetention: 0.97), returnsNormally);
      expect(() => DrillScheduler(targetRetention: 0.79), throwsArgumentError);
      expect(() => DrillScheduler(targetRetention: 0.98), throwsArgumentError);
    });

    test('a higher target means shorter intervals', () {
      final low = scheduler(retention: 0.8);
      final high = scheduler(retention: 0.97);
      final card = graduated(scheduler());
      final lowDays = answer(low, card, Rating.good, card.due).scheduledDays;
      final highDays = answer(high, card, Rating.good, card.due).scheduledDays;
      expect(highDays, lessThan(lowDays));
    });
  });

  test('each drill has its own parameter set', () {
    final tuned = [...defaultParameters]..[2] = 10; // Good's first stability
    final s = DrillScheduler(
      parameters: {DrillType.gender: tuned},
      random: () => 0.5,
    );
    DrillCard easyStart(DrillType drill) {
      final card = answer(s, newCard(drill: drill), Rating.good).after;
      return card;
    }

    expect(easyStart(DrillType.gender).stability, 10);
    expect(easyStart(DrillType.vocabulary).stability, defaultParameters[2]);
  });

  test('fuzz spreads intervals of cards learned together', () {
    var fuzz = 0.0;
    final s = DrillScheduler(random: () => fuzz);
    final card = graduated(scheduler());
    fuzz = 0;
    final low = answer(s, card, Rating.good, card.due).scheduledDays;
    fuzz = 0.999;
    final high = answer(s, card, Rating.good, card.due).scheduledDays;
    expect(high, greaterThan(low));
  });

  group('review log data', () {
    final s = scheduler();

    test('state before, elapsed and scheduled days', () {
      final first = answer(s, newCard(), Rating.easy);
      expect(first.stateBefore, CardState.newCard);
      expect(first.elapsedDays, isNull);
      expect(first.scheduledDays, greaterThanOrEqualTo(1));

      final card = first.after;
      final second = answer(s, card, Rating.good, card.due);
      expect(second.stateBefore, CardState.review);
      expect(second.elapsedDays, first.scheduledDays);

      final step = answer(s, newCard(), Rating.good);
      expect(step.scheduledDays, 0);
    });

    test('elapsed days never go negative when the clock goes backwards', () {
      final card = answer(s, newCard(), Rating.easy).after;
      final o = answer(
        s,
        card,
        Rating.good,
        card.lastReview!.subtract(const Duration(days: 2)),
      );
      expect(o.elapsedDays, 0);
      expect(o.after.state, CardState.review);
    });

    test('the study day comes from the caller', () {
      const day = StudyDay(2026, 9, 23);
      final o = s.review(newCard(), Rating.good, at: noon, day: day);
      expect(o.studyDay, day);
    });
  });

  group('retrievability', () {
    final s = scheduler();

    test('is 0 for a new card and 1 on the day of a review', () {
      expect(s.retrievability(newCard(), noon), 0);
      final card = answer(s, newCard(), Rating.easy).after;
      expect(s.retrievability(card, noon), 1);
    });

    test('falls as days pass', () {
      final card = answer(s, newCard(), Rating.easy).after;
      final later = s.retrievability(card, noon.add(const Duration(days: 5)));
      final muchLater = s.retrievability(
        card,
        noon.add(const Duration(days: 50)),
      );
      expect(later, lessThan(1));
      expect(muchLater, lessThan(later));
    });
  });
}
