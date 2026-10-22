import 'dart:async';

import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/domain/content.dart';
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

Finder get tile => find.ancestor(
  of: find.text(Strings.homeDrillVocabulary),
  matching: find.byType(InkWell),
);

void main() {
  testWidgets('the Vocabulaire tile shows how many cards are due', (
    tester,
  ) async {
    await pumpHome(
      tester,
      FakeStore(
        cards: [
          reviewCard(due: noon, itemId: 'n.a', id: 1),
          reviewCard(due: noon, itemId: 'n.b', id: 2),
          newCard(itemId: 'n.c', id: 3),
        ],
      ),
    );
    expect(find.text(Strings.homeDueCount(n: 2)), findsOneWidget);
  });

  testWidgets('nothing due: Tout est à jour', (tester) async {
    await pumpHome(tester, FakeStore(cards: [newCard(itemId: 'n.a', id: 1)]));
    expect(find.text(Strings.homeDueNone), findsOneWidget);
  });

  testWidgets('while the content is prepared, the tile waits', (tester) async {
    final importing = Completer<ContentInfo>();
    await pumpHome(
      tester,
      FakeStore(cards: const []),
      content: importing.future,
    );
    expect(find.text(Strings.homePreparingContent), findsOneWidget);
    expect(tester.widget<InkWell>(tile).onTap, isNull);

    importing.complete(const ContentInfo(version: 1, releasedAt: '2026-10-22'));
    await tester.pump();
    await tester.pump();
    expect(find.text(Strings.homePreparingContent), findsNothing);
    expect(tester.widget<InkWell>(tile).onTap, isNotNull);
  });

  testWidgets('tapping the tile opens the drill', (tester) async {
    await pumpHome(tester, FakeStore(cards: const []));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(DrillScreen), findsOneWidget);
  });
}
