// The milestone 3 flows, run on a device by drill_session_test.dart and on
// the host by test/integration/drill_session_flows_test.dart: the real app,
// on a real database file, with the bundled pack imported on first launch.

import 'dart:io';

import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/data/drill_tables.drift.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/session_card.dart';
import 'package:bah_francais/features/drills/presentation/drill_controller.dart';
import 'package:bah_francais/features/drills/presentation/drill_name.dart';
import 'package:bah_francais/features/drills/presentation/drill_screen.dart';
import 'package:bah_francais/features/drills/presentation/session_summary_screen.dart';
import 'package:bah_francais/features/home/presentation/home_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A new, empty database file, deleted after the test.
File newDatabaseFile() {
  final dir = Directory.systemTemp.createTempSync('bah_flow_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return File('${dir.path}/bah_francais.sqlite');
}

/// Lets frames and real I/O run for [duration]. Unlike pumpAndSettle, it
/// doesn't wait for the answer field's cursor to stop blinking.
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 1),
]) async {
  for (var waited = Duration.zero; waited < duration; waited += _step) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(_step);
  }
}

const _step = Duration(milliseconds: 50);

/// Launches the app on [db] and waits for the first launch's import.
Future<void> launch(WidgetTester tester, AppDatabase db) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const BahApp(),
    ),
  );
  for (var i = 0; i < 200; i++) {
    await settle(tester, const Duration(milliseconds: 100));
    if (find.text(Strings.homePreparingContent).evaluate().isEmpty &&
        find.text(Strings.homeDrillVocabulary).evaluate().isNotEmpty) {
      break;
    }
  }
  expect(find.text(Strings.homePreparingContent), findsNothing);
}

/// Opens the Vocabulaire drill from its Accueil tile.
Future<void> openVocabulary(WidgetTester tester) =>
    openFromHome(tester, find.text(Strings.homeDrillVocabulary));

/// Opens a session from Accueil: a drill's tile, or *Commencer*.
Future<void> openFromHome(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await settle(tester);
  expect(find.byType(DrillScreen), findsOneWidget);
}

/// The card on screen in the session of [drill] (null: mixed).
SessionCard currentCard(WidgetTester tester, {DrillType? drill}) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DrillScreen)),
  );
  final view = container.read(drillControllerProvider(drill)).value;
  return (view! as CardQuestion).card;
}

/// The answer to the Vocabulaire card on screen.
String currentAnswer(WidgetTester tester) =>
    (currentCard(tester, drill: DrillType.vocabulary) as TypedCard).answer;

/// Answers the card on screen right, whatever its drill.
Future<void> answerRight(WidgetTester tester, {DrillType? drill}) async {
  switch (currentCard(tester, drill: drill)) {
    case GenderCard(:final item):
      await tapTile(tester, item.answer.gender);
    case final TypedCard card:
      await answer(tester, card.answer);
  }
}

/// Answers the card on screen wrong, whatever its drill.
Future<void> answerWrong(WidgetTester tester, {DrillType? drill}) async {
  switch (currentCard(tester, drill: drill)) {
    case GenderCard(:final item):
      await tapTile(
        tester,
        item.answer.gender == Gender.masculine
            ? Gender.feminine
            : Gender.masculine,
      );
    case TypedCard():
      await answer(tester, 'zz');
  }
}

/// Taps the Genre tile of [gender], by its screen-reader label.
Future<void> tapTile(WidgetTester tester, Gender gender) async {
  final label = switch (gender) {
    Gender.feminine => Strings.drillGenderFeminine,
    Gender.masculine => Strings.drillGenderMasculine,
    Gender.both => Strings.drillGenderBoth,
  };
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    ),
  );
  await settle(tester);
}

Future<void> answer(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await settle(tester, const Duration(milliseconds: 200));
  await tester.tap(find.text(Strings.drillSubmit));
  await settle(tester);
}

Future<void> giveUp(WidgetTester tester) async {
  await tester.tap(find.text(Strings.drillIDontKnow));
  await settle(tester);
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text(Strings.drillNext));
  await settle(tester);
}

/// Completes a session: a right answer, which moves straight on, a wrong
/// one and *Je ne sais pas*, each corrected, then × to the summary and
/// *Terminer* to Accueil. Every answer is in the database.
Future<void> completesASession(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase(newDatabaseFile()));
  addTearDown(db.close);
  await launch(tester, db);
  await openVocabulary(tester);

  await answer(tester, currentAnswer(tester));
  expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
  expect(find.text(Strings.drillNext), findsNothing);
  expect(find.byType(SnackBar), findsNothing);

  await answer(tester, 'zz');
  expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
  await next(tester);

  await giveUp(tester);
  expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
  expect(find.text(Strings.drillCardsAnswered(n: 3)), findsOneWidget);

  await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
  await settle(tester);
  expect(find.byType(SessionSummaryScreen), findsOneWidget);
  expect(find.text('3'), findsOneWidget);
  expect(find.text(Strings.sessionSummaryPercent(n: 33)), findsOneWidget);

  await tester.tap(find.text(Strings.sessionSummaryFinish));
  await settle(tester);
  expect(find.byType(HomeScreen), findsOneWidget);

  final logs = await tester.runAsync(() => db.select(db.reviewLogs).get());
  expect(logs, hasLength(3));
  final session = (await tester.runAsync(() => db.select(db.sessions).get()))!
      .single;
  expect(session.drillType, DrillType.vocabulary);
  expect(session.answered, 3);
  expect(session.correct, 1);
}

/// Force-closing mid-session loses no answered card: after two answers, the
/// app's connection is left open as a killed process leaves it, and a fresh
/// connection to the same file finds both answers saved.
Future<void> forceCloseLosesNothing(WidgetTester tester) async {
  final file = newDatabaseFile();
  final db = AppDatabase(NativeDatabase(file));
  addTearDown(db.close);
  await launch(tester, db);
  await openVocabulary(tester);

  await answer(tester, 'zz');
  await next(tester);
  await giveUp(tester);

  // The process dies here: nothing is closed or flushed on the way out.
  final reopened = AppDatabase(NativeDatabase(file));
  addTearDown(reopened.close);
  final logs = (await tester.runAsync(
    () => reopened.select(reopened.reviewLogs).get(),
  ))!;
  expect(logs, hasLength(2));
  final sessions = (await tester.runAsync(
    () => reopened.select(reopened.sessions).get(),
  ))!;
  expect(sessions.single.answered, 2);
  expect(sessions.single.endTime, logs.last.timestamp);
  final cards = (await tester.runAsync(
    () => reopened.select(reopened.cards).get(),
  ))!;
  for (final log in logs) {
    final card = cards.singleWhere((c) => c.id == log.cardId);
    expect(card.reps, greaterThan(0), reason: 'card ${card.id} was saved');
  }
}

/// × to the summary, which shows [answered] cards and [percent] % correct,
/// then *Terminer* to Accueil.
Future<void> closeAndFinish(
  WidgetTester tester, {
  required int answered,
  required int percent,
}) async {
  await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
  await settle(tester);
  expect(find.byType(SessionSummaryScreen), findsOneWidget);
  expect(find.text('$answered'), findsWidgets);
  expect(find.text(Strings.sessionSummaryPercent(n: percent)), findsWidgets);
  await tester.tap(find.text(Strings.sessionSummaryFinish));
  await settle(tester);
  expect(find.byType(HomeScreen), findsOneWidget);
}

/// The session saved in [db], with its answers.
Future<(SessionRow, List<ReviewLogRow>)> savedSession(
  WidgetTester tester,
  AppDatabase db,
) async {
  final sessions = (await tester.runAsync(() => db.select(db.sessions).get()))!;
  final logs = (await tester.runAsync(() => db.select(db.reviewLogs).get()))!;
  return (sessions.single, logs);
}

/// Completes a Genre session: the right tile, which moves straight on, and
/// a wrong one, corrected in place; then × and *Terminer*.
Future<void> completesAGenderSession(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase(newDatabaseFile()));
  addTearDown(db.close);
  await launch(tester, db);
  await openFromHome(tester, find.text(Strings.homeDrillGender));

  await answerRight(tester, drill: DrillType.gender);
  expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
  expect(find.text(Strings.drillNext), findsNothing);

  await answerWrong(tester, drill: DrillType.gender);
  expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
  expect(find.text(Strings.drillTypo), findsOneWidget);
  await next(tester);

  await closeAndFinish(tester, answered: 2, percent: 50);
  final (session, logs) = await savedSession(tester, db);
  expect(session.drillType, DrillType.gender);
  expect(logs, hasLength(2));
}

/// Completes a Conjugaison session: a right answer, a wrong one and *Je ne
/// sais pas*; then × and *Terminer*.
Future<void> completesAConjugationSession(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase(newDatabaseFile()));
  addTearDown(db.close);
  await launch(tester, db);
  await openFromHome(tester, find.text(Strings.homeDrillConjugation));

  await answerRight(tester, drill: DrillType.conjugation);
  expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);

  await answerWrong(tester, drill: DrillType.conjugation);
  expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
  await next(tester);

  await giveUp(tester);
  expect(find.text(Strings.drillResultIncorrect), findsOneWidget);

  await closeAndFinish(tester, answered: 3, percent: 33);
  final (session, logs) = await savedSession(tester, db);
  expect(session.drillType, DrillType.conjugation);
  expect(logs, hasLength(3));
}

/// Completes a mixed session from *Commencer*: three right answers, each
/// card's drill named under the top bar; the summary has each drill's
/// numbers.
Future<void> completesAMixedSession(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase(newDatabaseFile()));
  addTearDown(db.close);
  await launch(tester, db);
  await openFromHome(
    tester,
    find.widgetWithText(FilledButton, Strings.homeStart),
  );

  final drills = <DrillType>{};
  for (var i = 0; i < 3; i++) {
    final drill = currentCard(tester).card.drill;
    drills.add(drill);
    expect(find.text(drillName(drill)), findsOneWidget);
    await answerRight(tester);
  }
  // The drills took turns.
  expect(drills, hasLength(3));

  await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
  await settle(tester);
  // Each drill's numbers, further down the summary.
  for (final drill in DrillType.values) {
    await tester.scrollUntilVisible(
      find.text(drillName(drill)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(drillName(drill)), findsOneWidget);
  }
  await tester.tap(find.text(Strings.sessionSummaryFinish));
  await settle(tester);

  final (session, logs) = await savedSession(tester, db);
  expect(session.drillType, isNull);
  expect(session.answered, 3);
  expect(logs, hasLength(3));
}
