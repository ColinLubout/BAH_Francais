// The nouns here are the spec's examples (fourchette, école) with their real
// gender and elision; definitions and sentences are made-up tokens.

import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:bah_francais/features/drills/presentation/drill_screen.dart';
import 'package:bah_francais/features/drills/presentation/session_summary_screen.dart';
import 'package:bah_francais/features/drills/presentation/widgets/accent_bar.dart';
import 'package:bah_francais/features/drills/presentation/widgets/blank_sentence.dart';
import 'package:bah_francais/features/drills/presentation/widgets/prompt_image.dart';
import 'package:bah_francais/features/home/presentation/home_screen.dart';
import 'package:bah_francais/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_overrides.dart';
import '../../../helpers/fake_clock.dart';
import '../../../helpers/fake_drill_store.dart';
import '../domain/helpers.dart';

const fourchette = NounItem(
  nounId: 'n.fourchette',
  answer: VocabularyAnswer(word: 'fourchette', gender: Gender.feminine),
  definition: 'def fourchette',
  examples: [ExampleSentence('zz fourchette zz', highlight: Span(3, 13))],
);
const ecole = NounItem(
  nounId: 'n.ecole',
  answer: VocabularyAnswer(
    word: 'école',
    gender: Gender.feminine,
    elides: true,
  ),
  definition: 'def école',
);

FakeStore store({List<NounItem> items = const [fourchette]}) => FakeStore(
  cards: [
    for (final (i, item) in items.indexed)
      newCard(itemId: item.nounId, id: i + 1),
  ],
  items: {for (final item in items) item.nounId: item},
);

/// Opens a drill from Accueil, on a small phone: the Vocabulaire tile,
/// unless [from] says another, or *Commencer*.
Future<FakeClock> openDrill(
  WidgetTester tester,
  FakeStore store, {
  double textScale = 1,
  List<Override> extra = const [],
  String from = Strings.homeDrillVocabulary,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(360, 720);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final clock = FakeClock(noon, offset: paris);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...drillOverrides(store: store, clock: clock),
        ...extra,
      ],
      child: const BahApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(from));
  await tester.pumpAndSettle();
  return clock;
}

Finder get field => find.byType(TextField);
Finder get wrongMark =>
    find.descendant(of: field, matching: find.byIcon(Icons.close));

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> submit(WidgetTester tester, String text) async {
  await type(tester, text);
  await tester.tap(find.text(Strings.drillSubmit));
  await tester.pumpAndSettle();
}

/// The styles of the field's text, one per character.
List<TextStyle?> letterStyles(WidgetTester tester) {
  final editable = tester.widget<EditableText>(find.byType(EditableText));
  final span = editable.controller.buildTextSpan(
    context: tester.element(find.byType(EditableText)),
    withComposing: false,
  );
  return [
    for (final child in span.children!.cast<TextSpan>())
      for (var i = 0; i < child.text!.length; i++) child.style,
  ];
}

void main() {
  group('a card', () {
    testWidgets('asks by its definition, with the keyboard open', (
      tester,
    ) async {
      await openDrill(tester, store());
      expect(find.byType(DrillScreen), findsOneWidget);
      expect(find.text('def fourchette'), findsOneWidget);
      expect(find.text(Strings.drillCardsAnswered(n: 0)), findsOneWidget);
      // In body text, smaller than the sentence (decision 70).
      final definition = find.text('def fourchette');
      expect(
        tester.widget<Text>(definition).style,
        Theme.of(tester.element(definition)).textTheme.bodyLarge,
      );

      final textField = tester.widget<TextField>(field);
      expect(textField.autofocus, isTrue);
      expect(textField.autocorrect, isFalse);
      expect(textField.enableSuggestions, isFalse);
      expect(textField.textCapitalization, TextCapitalization.none);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('asks by an image, whose label never names the word', (
      tester,
    ) async {
      const withImage = NounItem(
        nounId: 'n.ecole',
        answer: VocabularyAnswer(word: 'école', gender: Gender.feminine),
        imageIds: ['i.ecole-1'],
      );
      final semantics = tester.ensureSemantics();
      await openDrill(
        tester,
        store(items: [withImage]),
        extra: [
          drillImageProvider.overrideWith(
            (ref, id) async => const ContentImage(
              id: 'i.ecole-1',
              itemId: 'n.ecole',
              format: ImageFormat.svg,
              svg:
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"> '
                  '<rect width="1" height="1"/></svg>',
            ),
          ),
        ],
      );
      expect(
        find.bySemanticsLabel(Strings.accessibilityPromptImage),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('école')), findsNothing);
      semantics.dispose();
    });

    testWidgets('the answer box takes the noun’s place in a sentence', (
      tester,
    ) async {
      await openDrill(tester, store());
      // "zz fourchette zz": the words around the noun, not the noun.
      expect(find.text('zz'), findsNWidgets(2));
      expect(find.textContaining('fourchette zz'), findsNothing);
      final box = tester.getRect(field);
      final before = tester.getRect(find.text('zz').first);
      final after = tester.getRect(find.text('zz').last);
      expect(before.bottom <= box.top || before.right <= box.left, isTrue);
      expect(after.top >= box.bottom || after.left >= box.right, isTrue);
      // The box's line is centred, in the middle of the space between the
      // top bar and the buttons.
      final space = tester.getRect(find.byType(BlankSentence));
      final line = [before, after]
          .where((r) => (r.center.dy - box.center.dy).abs() < box.height / 2)
          .fold(box, (line, r) => line.expandToInclude(r));
      expect(line.center.dx, moreOrLessEquals(space.center.dx, epsilon: 0.5));
      expect(box.center.dy, moreOrLessEquals(space.center.dy, epsilon: 1));
    });

    testWidgets('the box is empty: its hint is for screen readers only', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openDrill(tester, store());
      expect(find.text(Strings.drillAnswerHint), findsNothing);
      expect(
        tester.getSemantics(field),
        isSemantics(label: Strings.drillAnswerHint, isTextField: true),
      );
      semantics.dispose();
    });

    testWidgets('the box is as wide for every word, wider for long typing', (
      tester,
    ) async {
      await openDrill(tester, store(items: [fourchette, ecole]));
      final width = tester.getSize(field).width;
      await type(tester, 'qq');
      expect(wrongMark, findsOneWidget);
      expect(tester.getSize(field).width, width, reason: 'room for the ✗');
      await tester.tap(find.text(Strings.drillIDontKnow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.drillNext));
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
      expect(tester.getSize(field).width, width);
      await type(tester, 'fourchette fourchette');
      expect(tester.getSize(field).width, greaterThan(width));
    });

    testWidgets('Je ne sais pas and Valider are side by side', (tester) async {
      await openDrill(tester, store());
      final giveUp = tester.getRect(
        find.widgetWithText(TextButton, Strings.drillIDontKnow),
      );
      final valider = tester.getRect(
        find.widgetWithText(FilledButton, Strings.drillSubmit),
      );
      expect(giveUp.center.dy, valider.center.dy);
      expect(giveUp.right, lessThan(valider.left));
    });

    testWidgets('Valider waits for an answer; Enter submits it', (
      tester,
    ) async {
      await openDrill(tester, store());
      FilledButton valider() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, Strings.drillSubmit),
      );
      expect(valider().onPressed, isNull);
      await type(tester, '   ');
      expect(valider().onPressed, isNull);
      await type(tester, 'fourchette');
      expect(valider().onPressed, isNotNull);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
    });
  });

  group('live feedback', () {
    testWidgets('right letters are green and underlined', (tester) async {
      await openDrill(tester, store());
      await type(tester, 'fou');
      final colors = FeedbackColors.of(tester.element(field));
      for (final style in letterStyles(tester)) {
        expect(style?.color, colors.correct);
        expect(style?.decoration, TextDecoration.underline);
        expect(style?.decorationStyle, isNot(TextDecorationStyle.dotted));
      }
      expect(wrongMark, findsNothing);
    });

    testWidgets('an accent slip is orange with a dotted underline', (
      tester,
    ) async {
      await openDrill(tester, store(items: [ecole]));
      await type(tester, 'ec');
      final colors = FeedbackColors.of(tester.element(field));
      final styles = letterStyles(tester);
      expect(styles.first?.color, colors.accentOnly);
      expect(styles.first?.decorationStyle, TextDecorationStyle.dotted);
      expect(styles.last?.color, colors.correct);
    });

    testWidgets('a wrong letter turns them all red, with a ✗', (tester) async {
      await openDrill(tester, store());
      await type(tester, 'fx');
      final colors = FeedbackColors.of(tester.element(field));
      expect(letterStyles(tester).map((s) => s?.color), [
        colors.wrong,
        colors.wrong,
      ]);
      expect(wrongMark, findsOneWidget);

      await type(tester, 'f');
      expect(wrongMark, findsNothing);
    });

    testWidgets('a letter that went red caps the grade: Presque', (
      tester,
    ) async {
      await openDrill(tester, store());
      await type(tester, 'fx');
      await submit(tester, 'fourchette');
      expect(find.text(Strings.drillResultAlmost), findsOneWidget);
    });
  });

  testWidgets('the accent bar inserts at the cursor, keeping the focus', (
    tester,
  ) async {
    await openDrill(tester, store(items: [ecole]));
    await type(tester, 'cole');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await tester.tap(
      find.bySemanticsLabel(Strings.accessibilityAccentKey(word: 'é')),
    );
    await tester.pump();
    expect(editable.controller.text, 'école');
    expect(editable.controller.selection.baseOffset, 1);
    expect(editable.focusNode.hasFocus, isTrue);
  });

  group('after Valider (decision 71)', () {
    /// The word asked first, of fourchette and école.
    String firstWord() => find.text('def fourchette').evaluate().isNotEmpty
        ? 'fourchette'
        : 'école';

    testWidgets('Correct: the next card at once', (tester) async {
      await openDrill(tester, store(items: [fourchette, ecole]));
      final first = firstWord();
      await submit(tester, first);

      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
      expect(
        find.text(first == 'fourchette' ? 'def école' : 'def fourchette'),
        findsOneWidget,
      );
      expect(find.text(Strings.drillNext), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field).readOnly, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a new word: Trop facile above the buttons, no answer', (
      tester,
    ) async {
      final fake = store(items: [fourchette, ecole]);
      await openDrill(tester, fake);
      final first = firstWord();
      final tooEasy = tester.getRect(
        find.widgetWithText(TextButton, Strings.drillTooEasy),
      );
      for (final button in [
        find.widgetWithText(TextButton, Strings.drillIDontKnow),
        find.widgetWithText(FilledButton, Strings.drillSubmit),
      ]) {
        expect(tooEasy.bottom, lessThanOrEqualTo(tester.getRect(button).top));
      }

      await tester.tap(find.text(Strings.drillTooEasy));
      await tester.pumpAndSettle();
      final answer = fake.answers.single;
      expect(answer.outcome.rating, Rating.easy);
      expect(answer.typed, isNull);
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
      expect(
        find.text(first == 'fourchette' ? 'def école' : 'def fourchette'),
        findsOneWidget,
      );
    });

    testWidgets('a new word answered wrong: no more Trop facile', (
      tester,
    ) async {
      await openDrill(tester, store());
      await submit(tester, 'qq');
      expect(find.text(Strings.drillTooEasy), findsNothing);
    });

    testWidgets('a word seen before: no Trop facile', (tester) async {
      await openDrill(
        tester,
        FakeStore(
          cards: [reviewCard(due: noon, itemId: 'n.fourchette', id: 1)],
          items: const {'n.fourchette': fourchette},
        ),
      );
      expect(find.text(Strings.drillTooEasy), findsNothing);
    });

    testWidgets('Incorrect: all stays, the answer under the sentence', (
      tester,
    ) async {
      final fake = store();
      await openDrill(tester, fake);
      await type(tester, 'qq');
      final box = tester.getRect(field);
      final sentence = tester.getRect(find.text('zz').first);
      await tester.tap(find.text(Strings.drillSubmit));
      await tester.pumpAndSettle();

      // The box, what was typed and the sentence haven't moved.
      expect(tester.getRect(field), box);
      expect(tester.getRect(find.text('zz').first), sentence);
      final textField = tester.widget<TextField>(field);
      expect(textField.controller!.text, 'qq');
      expect(textField.readOnly, isTrue);
      expect(wrongMark, findsOneWidget);

      final answer = find.text(
        Strings.drillCorrectAnswer(answer: 'fourchette'),
      );
      final result = find.text(Strings.drillResultIncorrect);
      expect(tester.getRect(result).top, greaterThan(box.bottom));
      expect(
        tester.getRect(answer).top,
        greaterThan(tester.getRect(result).top),
      );
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      // Faute de frappe and Suivant in place of the question's buttons.
      expect(find.text(Strings.drillSubmit), findsNothing);
      expect(find.text(Strings.drillIDontKnow), findsNothing);
      expect(find.byType(AccentBar), findsNothing);
      await tester.tap(find.text(Strings.drillTypo));
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillResultAlmost), findsOneWidget);
      expect(find.text(Strings.drillTypo), findsNothing);
      expect(fake.replaced.single.$2.outcome.rating, Rating.hard);
    });

    testWidgets('Presque stays too, the slip marked in the answer', (
      tester,
    ) async {
      await openDrill(tester, store(items: [ecole]));
      await submit(tester, 'ecole');
      expect(find.text(Strings.drillResultAlmost), findsOneWidget);
      expect(
        find.text(Strings.drillCorrectAnswer(answer: 'école')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'ecole');
      expect(find.text(Strings.drillTypo), findsNothing);
      expect(find.text(Strings.drillNext), findsOneWidget);
    });

    testWidgets('Je ne sais pas: the box as it was, the answer under it', (
      tester,
    ) async {
      final fake = store();
      await openDrill(tester, fake);
      await tester.tap(find.text(Strings.drillIDontKnow));
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
      expect(
        find.text(Strings.drillCorrectAnswer(answer: 'fourchette')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text(Strings.drillTypo), findsNothing);
      expect(fake.answers.single.typed, isNull);
    });

    testWidgets('Suivant brings the next card; the count goes up', (
      tester,
    ) async {
      await openDrill(tester, store(items: [fourchette, ecole]));
      final first = firstWord();
      await submit(tester, 'qq');
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
      await tester.tap(find.text(Strings.drillNext));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        find.text(first == 'fourchette' ? 'def école' : 'def fourchette'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Je le connais: the next card at once, and Annuler', (
    tester,
  ) async {
    final fake = store(items: [fourchette, ecole]);
    await openDrill(tester, fake);
    await tester.tap(find.text(Strings.drillIKnowIt));
    await tester.pumpAndSettle();
    expect(fake.knownCalls.single.$2, isNotNull);
    expect(find.text(Strings.drillMarkedKnown), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // Above the buttons, so the next word can be answered meanwhile.
    final snackBar = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    );
    expect(
      tester.getRect(snackBar.first).bottom,
      lessThanOrEqualTo(
        tester
            .getRect(find.widgetWithText(TextButton, Strings.drillTooEasy))
            .top,
      ),
    );

    await tester.tap(find.text(Strings.commonUndo));
    await tester.pumpAndSettle();
    expect(fake.knownCalls.last.$2, isNull);

    // Annuler is there for 5 seconds.
    await tester.tap(find.text(Strings.drillIKnowIt));
    await tester.pumpAndSettle();
    expect(find.text(Strings.commonUndo), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(Strings.commonUndo), findsNothing);
  });

  group('instead of a card', () {
    testWidgets('Tout est à jour, once, above a free-practice card', (
      tester,
    ) async {
      await openDrill(
        tester,
        FakeStore(
          cards: [
            reviewCard(
              due: noon.add(const Duration(days: 3)),
              itemId: 'n.fourchette',
              id: 1,
            ),
          ],
          items: const {'n.fourchette': fourchette},
        ),
      );
      expect(find.textContaining(Strings.drillAllCaughtUp), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the daily goal: Ça suffit pour aujourd’hui', (tester) async {
      await openDrill(
        tester,
        FakeStore(
          cards: [reviewCard(due: noon, itemId: 'n.fourchette', id: 1)],
          items: const {'n.fourchette': fourchette},
          setup: const DrillQueueSetup(
            settings: QueueSettings(maxReviewsPerDay: 10),
          ),
          counts: const DayCounts(reviews: 10),
        ),
      );
      expect(find.text(Strings.drillDailyGoalReached), findsOneWidget);
      await tester.tap(find.text(Strings.sessionSummaryFinish));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('no card: Aucune carte disponible, and the settings', (
      tester,
    ) async {
      await openDrill(tester, FakeStore(cards: const []));
      expect(find.text(Strings.drillNoCards), findsOneWidget);
      await tester.tap(find.text(Strings.drillOpenSettings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('× with nothing answered goes straight to Accueil', (
      tester,
    ) async {
      final fake = store();
      await openDrill(tester, fake);
      await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fake.sessionsStarted, isEmpty, reason: 'no session row');
    });

    testWidgets('× after an answer: the summary; Continuer, then Terminer', (
      tester,
    ) async {
      final clock = await openDrill(tester, store());
      clock.advance(const Duration(seconds: 42));
      await submit(tester, 'fourchette');
      await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryScreen), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(Strings.sessionSummaryPercent(n: 100)), findsOneWidget);
      expect(find.text(Strings.commonSeconds(n: 42)), findsOneWidget);

      await tester.tap(find.text(Strings.sessionSummaryResume));
      await tester.pumpAndSettle();
      expect(find.byType(DrillScreen), findsOneWidget);
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);

      await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.sessionSummaryFinish));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the back gesture does what × does', (tester) async {
      await openDrill(tester, store());
      await submit(tester, 'fourchette');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SessionSummaryScreen), findsOneWidget);
    });

    for (final (away, closes) in [
      (const Duration(minutes: 29), false),
      (const Duration(minutes: 31), true),
    ]) {
      testWidgets('back after ${away.inMinutes} minutes: '
          '${closes ? 'the session is closed' : 'the same card'}', (
        tester,
      ) async {
        final clock = await openDrill(tester, store());
        // The app goes to the background and back, one state at a time.
        final lifecycle = tester.binding.handleAppLifecycleStateChanged;
        [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
        ].forEach(lifecycle);
        clock.advance(away);
        [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ].forEach(lifecycle);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), closes ? findsOneWidget : findsNothing);
        if (!closes) expect(find.text('def fourchette'), findsOneWidget);
      });
    }
  });

  group('accessibility', () {
    testWidgets('× and the accent keys have screen-reader labels', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openDrill(tester, store());
      expect(find.byTooltip(Strings.accessibilityCloseSession), findsOneWidget);
      expect(
        find.bySemanticsLabel(Strings.accessibilityAccentKey(word: 'ç')),
        findsOneWidget,
      );
      await type(tester, 'fx');
      expect(
        find.bySemanticsLabel(Strings.accessibilityAnswerIncorrect),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('no overflow at ${scale}x text, asking or after', (
        tester,
      ) async {
        await openDrill(tester, store(), textScale: scale);
        expect(tester.takeException(), isNull);
        await submit(tester, 'zz');
        expect(tester.takeException(), isNull);
        expect(find.text(Strings.drillNext), findsOneWidget);
      });
    }
  });
}
