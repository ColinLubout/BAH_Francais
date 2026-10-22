// The Genre and Conjugaison cards, and the mixed session (milestone 4). The
// nouns and verbs are the spec's examples; sentences are made-up tokens,
// apart from the spec's own *J’habite*.

import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/app_text_styles.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/session/conjugation_item.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:bah_francais/features/drills/presentation/drill_name.dart';
import 'package:bah_francais/features/drills/presentation/session_summary_screen.dart';
import 'package:bah_francais/features/drills/presentation/widgets/accent_bar.dart';
import 'package:bah_francais/features/drills/presentation/widgets/blank_sentence.dart';
import 'package:bah_francais/features/drills/presentation/widgets/prompt_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_drill_store.dart';
import '../domain/helpers.dart';
import 'drill_screen_test.dart' as screen;

final table = NounItem(
  nounId: 'n.table',
  answer: const VocabularyAnswer(word: 'table', gender: Gender.feminine),
  definition: 'def table',
  gloss: 'gloss table',
  endingHint: 'hint table',
  examples: [ExampleSentence.of('zz table zz', 'table')],
);

const habiter = ConjugationItem(
  verbId: 'v.habiter',
  infinitive: 'habiter',
  tense: Tense.present,
  sentences: [
    ConjugationSentence(
      id: 's.h',
      text: 'J’habite zz.',
      person: Person.firstSingular,
      answer: 'habite',
    ),
  ],
);

FakeStore genderStore({bool seenBefore = false}) => FakeStore(
  cards: [
    if (seenBefore)
      reviewCard(due: noon, itemId: 'n.table', drill: DrillType.gender, id: 1)
    else
      newCard(itemId: 'n.table', drill: DrillType.gender, id: 1),
  ],
  items: {'n.table': table},
);

FakeStore conjugationStore() => FakeStore(
  cards: [
    newCard(itemId: 'v.habiter', drill: DrillType.conjugation, id: 2),
    newCard(
      itemId: 'v.habiter',
      drill: DrillType.conjugation,
      tense: Tense.imparfait,
      id: 3,
    ),
  ],
  verbs: {
    ('v.habiter', Tense.present): habiter,
    ('v.habiter', Tense.imparfait): const ConjugationItem(
      verbId: 'v.habiter',
      infinitive: 'habiter',
      tense: Tense.imparfait,
      sentences: [
        ConjugationSentence(
          id: 's.i',
          text: 'zz habitais zz.',
          person: Person.firstSingular,
          answer: 'habitais',
        ),
      ],
    ),
  },
);

/// The Genre tile labelled [label].
Finder tile(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

void main() {
  group('Genre', () {
    testWidgets('the tiles, the word and its gloss; nothing typed', (
      tester,
    ) async {
      await screen.openDrill(
        tester,
        genderStore(),
        from: Strings.homeDrillGender,
      );
      for (final label in [
        Strings.drillGenderFeminine,
        Strings.drillGenderMasculine,
        Strings.drillGenderBoth,
      ]) {
        expect(tile(label), findsOneWidget, reason: label);
      }
      expect(find.text('table'), findsOneWidget);
      expect(find.text('gloss table'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(Strings.drillSubmit), findsNothing);
      expect(find.text(Strings.drillIDontKnow), findsNothing);
      // Tiles sit at the top, above the word.
      expect(
        tester.getRect(tile(Strings.drillGenderMasculine)).bottom,
        lessThan(tester.getRect(find.text('table')).top),
      );
    });

    testWidgets('a new word: Trop facile at the bottom', (tester) async {
      final fake = genderStore();
      await screen.openDrill(tester, fake, from: Strings.homeDrillGender);
      final tooEasy = tester.getRect(find.text(Strings.drillTooEasy));
      expect(
        tooEasy.top,
        greaterThan(tester.getRect(find.text('table')).bottom),
      );
      await tester.tap(find.text(Strings.drillTooEasy));
      await tester.pumpAndSettle();
      expect(fake.answers.single.outcome.rating, Rating.easy);
    });

    testWidgets('a word seen before: no Trop facile', (tester) async {
      await screen.openDrill(
        tester,
        genderStore(seenBefore: true),
        from: Strings.homeDrillGender,
      );
      expect(find.text(Strings.drillTooEasy), findsNothing);
    });

    testWidgets('the right tile moves straight on', (tester) async {
      final fake = genderStore();
      await screen.openDrill(tester, fake, from: Strings.homeDrillGender);
      await tester.tap(tile(Strings.drillGenderFeminine));
      await tester.pumpAndSettle();
      expect(fake.answers.single.outcome.rating, Rating.good);
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);
      expect(find.text(Strings.drillNext), findsNothing);
    });

    testWidgets('a wrong tile: the correction under the card, in place', (
      tester,
    ) async {
      final fake = genderStore();
      await screen.openDrill(tester, fake, from: Strings.homeDrillGender);
      final word = tester.getRect(find.text('table'));
      await tester.tap(tile(Strings.drillGenderMasculine));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.text('table')), word, reason: 'not moved');
      final chosen = tester.widget<Semantics>(
        tile(Strings.drillGenderMasculine),
      );
      expect(chosen.properties.selected, isTrue);
      expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
      final answer = find.text(Strings.drillCorrectAnswer(answer: 'une table'));
      expect(answer, findsOneWidget);
      expect(tester.getRect(answer).top, greaterThan(word.bottom));
      expect(find.text(Strings.drillTip), findsOneWidget);
      expect(find.text('hint table'), findsOneWidget);
      // The example, with the noun in bold.
      final example = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'zz table zz',
        ),
      );
      TextSpan? bold;
      example.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'table') bold = span;
        return true;
      });
      expect(
        bold?.style?.fontWeight,
        AppTextStyles.of(tester.element(find.text('table')))
            .emphasis
            .fontWeight,
      );

      // No second answer; Faute de frappe makes it Presque.
      await tester.tap(tile(Strings.drillGenderFeminine));
      await tester.pumpAndSettle();
      expect(fake.answers, hasLength(1));
      await tester.tap(find.text(Strings.drillTypo));
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillResultAlmost), findsOneWidget);
      expect(fake.replaced.single.$2.outcome.rating, Rating.hard);
      expect(find.text(Strings.drillNext), findsOneWidget);
    });

    testWidgets('one of the noun’s images, unless it has none', (tester) async {
      final withImage = FakeStore(
        cards: [newCard(itemId: 'n.ecole', drill: DrillType.gender, id: 1)],
        items: {
          'n.ecole': const NounItem(
            nounId: 'n.ecole',
            answer: VocabularyAnswer(word: 'école', gender: Gender.feminine),
            imageIds: ['i.ecole-1'],
          ),
        },
      );
      await screen.openDrill(
        tester,
        withImage,
        from: Strings.homeDrillGender,
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
      expect(find.byType(PromptImage), findsOneWidget);
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('no overflow at ${scale}x text, asking or after', (
        tester,
      ) async {
        await screen.openDrill(
          tester,
          genderStore(),
          from: Strings.homeDrillGender,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(tile(Strings.drillGenderBoth));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(Strings.drillNext), findsOneWidget);
      });
    }
  });

  group('Conjugaison', () {
    testWidgets('the sentence with the box, then the verb and tense', (
      tester,
    ) async {
      await screen.openDrill(
        tester,
        conjugationStore(),
        from: Strings.homeDrillConjugation,
      );
      // The elided word written in full: J’habite → Je ___.
      expect(find.text('Je'), findsOneWidget);
      expect(find.text('habiter'), findsOneWidget);
      expect(find.text(Strings.tensesPresent), findsOneWidget);
      final box = tester.getRect(find.byType(TextField));
      expect(tester.getRect(find.text('habiter')).top, greaterThan(box.bottom));
      expect(find.byType(AccentBar), findsOneWidget);
      expect(find.text(Strings.drillTooEasy), findsOneWidget);
    });

    testWidgets('the word before the box elides as a vowel is typed', (
      tester,
    ) async {
      await screen.openDrill(
        tester,
        conjugationStore(),
        from: Strings.homeDrillConjugation,
      );
      await screen.type(tester, 'h');
      expect(find.text('J’'), findsOneWidget);
      expect(find.text('Je'), findsNothing);
      await screen.type(tester, '');
      expect(find.text('Je'), findsOneWidget);
    });

    testWidgets('a right answer moves on; a wrong one stays, corrected', (
      tester,
    ) async {
      final fake = conjugationStore();
      await screen.openDrill(tester, fake, from: Strings.homeDrillConjugation);
      final first = find.text('Je').evaluate().isNotEmpty;
      await screen.submit(tester, first ? 'habite' : 'habitais');
      expect(fake.answers.single.outcome.rating, Rating.good);
      expect(find.text(Strings.drillCardsAnswered(n: 1)), findsOneWidget);

      await screen.submit(tester, 'qq');
      expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
      expect(
        find.text(
          Strings.drillCorrectAnswer(answer: first ? 'habitais' : 'habite'),
        ),
        findsOneWidget,
      );
      // The verb and tense stay, above the correction.
      expect(find.text('habiter'), findsOneWidget);
      expect(find.text(Strings.drillTypo), findsOneWidget);
    });

    testWidgets('Je ne sais pas shows the sentence’s answer', (tester) async {
      await screen.openDrill(
        tester,
        conjugationStore(),
        from: Strings.homeDrillConjugation,
      );
      await tester.tap(find.text(Strings.drillIDontKnow));
      await tester.pumpAndSettle();
      expect(find.text(Strings.drillResultIncorrect), findsOneWidget);
      expect(find.byType(BlankSentence), findsOneWidget);
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('no overflow at ${scale}x text, asking or after', (
        tester,
      ) async {
        await screen.openDrill(
          tester,
          conjugationStore(),
          from: Strings.homeDrillConjugation,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await screen.submit(tester, 'zz');
        expect(tester.takeException(), isNull);
        expect(find.text(Strings.drillNext), findsOneWidget);
      });
    }
  });

  group('a mixed session', () {
    FakeStore mixed() => FakeStore(
      cards: [
        newCard(itemId: 'n.table', drill: DrillType.gender, id: 1),
        newCard(itemId: 'v.habiter', drill: DrillType.conjugation, id: 2),
      ],
      items: {'n.table': table},
      verbs: {('v.habiter', Tense.present): habiter},
    );

    testWidgets('names the drill of the card on screen', (tester) async {
      await screen.openDrill(tester, mixed(), from: Strings.homeStart);
      expect(find.text(drillName(DrillType.gender)), findsOneWidget);
      await tester.tap(tile(Strings.drillGenderFeminine));
      await tester.pumpAndSettle();
      expect(find.text(drillName(DrillType.conjugation)), findsOneWidget);
      expect(find.text(drillName(DrillType.gender)), findsNothing);
    });

    testWidgets('its summary has each drill’s numbers', (tester) async {
      await screen.openDrill(tester, mixed(), from: Strings.homeStart);
      await tester.tap(tile(Strings.drillGenderMasculine));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.drillNext));
      await tester.pumpAndSettle();
      await screen.submit(tester, 'habite');
      await tester.tap(find.byTooltip(Strings.accessibilityCloseSession));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryScreen), findsOneWidget);
      expect(find.text(Strings.sessionSummaryPercent(n: 50)), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(drillName(DrillType.conjugation)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(drillName(DrillType.gender)), findsOneWidget);
      expect(find.text(drillName(DrillType.conjugation)), findsOneWidget);
      expect(find.text(drillName(DrillType.vocabulary)), findsNothing);
      expect(find.text(Strings.sessionSummaryPercent(n: 0)), findsOneWidget);
      expect(find.text(Strings.sessionSummaryPercent(n: 100)), findsOneWidget);
    });
  });
}
