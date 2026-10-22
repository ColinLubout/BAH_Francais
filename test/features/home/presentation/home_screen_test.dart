import 'dart:async';

import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/presentation/drill_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_overrides.dart';
import '../../../helpers/fake_clock.dart';
import '../../../helpers/fake_drill_store.dart';
import '../../drills/domain/helpers.dart';

Future<void> pumpHome(
  WidgetTester tester,
  FakeStore store, {
  Future<ContentInfo>? content,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...drillOverrides(
          store: store,
          clock: FakeClock(noon, offset: paris),
          content: content,
        ),
      ],
      child: const BahApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The tile of [name]'s drill.
Finder tileOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(InkWell));

Finder get start => find.widgetWithText(FilledButton, Strings.homeStart);

void main() {
  testWidgets('Commencer, then a tile per drill', (tester) async {
    await pumpHome(tester, FakeStore(cards: const []));
    final startTop = tester.getRect(start).top;
    final names = [
      Strings.homeDrillGender,
      Strings.homeDrillVocabulary,
      Strings.homeDrillConjugation,
    ];
    var above = startTop;
    for (final name in names) {
      final top = tester.getRect(tileOf(name)).top;
      expect(top, greaterThan(above), reason: name);
      above = top;
    }
    // The ⋮ menus and the Liste de révision link come in milestone 6.
    expect(find.text(Strings.homeReviewList), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('each tile shows how many of its cards are due', (tester) async {
    await pumpHome(
      tester,
      FakeStore(
        cards: [
          reviewCard(due: noon, itemId: 'n.a', id: 1),
          reviewCard(due: noon, itemId: 'n.b', id: 2),
          newCard(itemId: 'n.c', id: 3),
          reviewCard(
            due: noon,
            itemId: 'v.a',
            drill: DrillType.conjugation,
            id: 4,
          ),
        ],
      ),
    );
    Finder line(String name, int n) => find.descendant(
      of: tileOf(name),
      matching: find.text(Strings.homeDueCount(n: n)),
    );
    expect(line(Strings.homeDrillVocabulary, 2), findsOneWidget);
    expect(line(Strings.homeDrillConjugation, 1), findsOneWidget);
    // No other number on the screen.
    expect(find.textContaining(Strings.homeDueCount(n: 0)), findsNothing);
  });

  testWidgets('nothing due, new words or not: no line (decision 76)', (
    tester,
  ) async {
    await pumpHome(tester, FakeStore(cards: [newCard(itemId: 'n.a', id: 1)]));
    for (final name in [
      Strings.homeDrillGender,
      Strings.homeDrillVocabulary,
      Strings.homeDrillConjugation,
    ]) {
      expect(
        find.descendant(of: tileOf(name), matching: find.byType(Text)),
        findsOneWidget,
        reason: '$name alone',
      );
    }
  });

  testWidgets('while the content is prepared, nothing starts', (tester) async {
    final importing = Completer<ContentInfo>();
    await pumpHome(
      tester,
      FakeStore(cards: const []),
      content: importing.future,
    );
    expect(find.text(Strings.homePreparingContent), findsNWidgets(3));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(
      tester.widget<InkWell>(tileOf(Strings.homeDrillGender)).onTap,
      isNull,
    );

    importing.complete(const ContentInfo(version: 1, releasedAt: '2026-10-22'));
    await tester.pump();
    await tester.pump();
    expect(find.text(Strings.homePreparingContent), findsNothing);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(
      tester.widget<InkWell>(tileOf(Strings.homeDrillGender)).onTap,
      isNotNull,
    );
  });

  testWidgets('a tile opens its drill', (tester) async {
    await pumpHome(tester, FakeStore(cards: const []));
    await tester.tap(tileOf(Strings.homeDrillConjugation));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DrillScreen>(find.byType(DrillScreen)).drill,
      DrillType.conjugation,
    );
  });

  testWidgets('Commencer opens a mixed session', (tester) async {
    await pumpHome(tester, FakeStore(cards: const []));
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(tester.widget<DrillScreen>(find.byType(DrillScreen)).drill, isNull);
  });
}
