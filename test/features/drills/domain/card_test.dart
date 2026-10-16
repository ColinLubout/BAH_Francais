import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/fsrs/fsrs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('toFsrs', () {
    test('a new card is at learning step 0, due now, with no memory yet', () {
      final fsrs = newCard().toFsrs(noon);
      expect(fsrs.state, FsrsState.learning);
      expect(fsrs.step, 0);
      expect(fsrs.stability, isNull);
      expect(fsrs.due, noon);
      expect(fsrs.lastReview, isNull);
    });

    test('carries the FSRS state of reviewed cards', () {
      final due = noon.add(const Duration(days: 3));
      final review = reviewCard(due: due, stability: 12).toFsrs(noon);
      expect(review.state, FsrsState.review);
      expect(review.stability, 12);
      expect(review.due, due);

      final relearning = learningCard(
        due: noon,
        state: CardState.relearning,
      ).toFsrs(noon);
      expect(relearning.state, FsrsState.relearning);
      expect(relearning.step, 0);

      final learning = learningCard(due: noon).toFsrs(noon);
      expect(learning.state, FsrsState.learning);
    });
  });

  group('known', () {
    test('marking known keeps the FSRS state; bringing back clears it', () {
      final card = reviewCard(due: noon, stability: 20);
      final known = card.withKnownAt(noon);
      expect(known.isKnown, isTrue);
      expect(known.knownAt, noon);
      expect(known.stability, 20);
      expect(known.due, card.due);

      final back = known.withKnownAt(null);
      expect(back.isKnown, isFalse);
      expect(back, card);
    });

    test('a new card brought back is still new', () {
      final back = newCard().withKnownAt(noon).withKnownAt(null);
      expect(back.state, CardState.newCard);
    });
  });

  test('withFsrs replaces the state, including a null step in review', () {
    final card = learningCard(due: noon);
    final after = card.withFsrs(
      FsrsCard(
        due: noon.add(const Duration(days: 2)),
        state: FsrsState.review,
        step: null,
        stability: 2,
        difficulty: 4,
        lastReview: noon,
      ),
      reps: 2,
      lapses: 0,
      againCount: 0,
      isLeech: false,
    );
    expect(after.state, CardState.review);
    expect(after.step, isNull);
    expect(after.reps, 2);
    expect(after.id, card.id);
  });

  test('conjugation cards need a tense, other cards must not have one', () {
    expect(
      () => DrillCard(
        id: 1,
        itemId: 'v.aller',
        drill: DrillType.conjugation,
        createdAt: noon,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => DrillCard(
        id: 1,
        itemId: 'n.table',
        drill: DrillType.gender,
        tense: Tense.present,
        createdAt: noon,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('equality, hash code and description', () {
    final a = newCard(id: 7, drill: DrillType.conjugation);
    final b = newCard(id: 7, drill: DrillType.conjugation);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.withKnownAt(noon)));
    expect(a.toString(), 'DrillCard(7, n.item, conjugation present, new)');
    expect(newCard(id: 8).toString(), 'DrillCard(8, n.item, vocabulary, new)');
  });

  test('stored ids', () {
    expect(CardState.values.map((s) => s.id), [
      'new',
      'learning',
      'review',
      'relearning',
    ]);
    expect(Tense.values.map((t) => t.id), [
      'present',
      'passe_compose',
      'imparfait',
      'futur_simple',
    ]);
  });
}
