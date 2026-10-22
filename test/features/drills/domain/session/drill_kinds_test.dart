// Genre, Conjugaison and mixed sessions (milestone 4). The nouns and verbs
// are the spec's examples with their real gender and forms; the sentences
// are made-up tokens around them, apart from the spec's own *J’habite*.

import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/conjugation_item.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:bah_francais/features/drills/domain/session/session_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_drill_store.dart';
import '../helpers.dart';

final table = NounItem(
  nounId: 'n.table',
  answer: const VocabularyAnswer(word: 'table', gender: Gender.feminine),
  definition: 'def table',
  imageIds: const ['i.table-1', 'i.table-2'],
  endingHint: 'hint',
  examples: [ExampleSentence.of('zz table zz', 'table')],
);

const vais = ConjugationSentence(
  id: 's.1s',
  text: 'zz vais zz.',
  person: Person.firstSingular,
  answer: 'vais',
);
const va = ConjugationSentence(
  id: 's.3s',
  text: 'zz va zz.',
  person: Person.thirdSingular,
  answer: 'va',
);
const vaToo = ConjugationSentence(
  id: 's.3s.2',
  text: 'zz va yy.',
  person: Person.thirdSingular,
  answer: 'va',
);
const aller = ConjugationItem(
  verbId: 'v.aller',
  infinitive: 'aller',
  tense: Tense.present,
  sentences: [vais, va, vaToo],
);

DrillCard genderCard({int id = 1}) =>
    newCard(itemId: 'n.table', drill: DrillType.gender, id: id);
DrillCard conjugationCard({int id = 2, Tense tense = Tense.present}) => newCard(
  itemId: 'v.aller',
  drill: DrillType.conjugation,
  tense: tense,
  id: id,
);

FakeStore storeOf(List<DrillCard> cards) => FakeStore(
  cards: cards,
  items: {'n.table': table},
  verbs: {('v.aller', Tense.present): aller},
);

Future<(DrillSession, FakeClock)> open(
  FakeStore store, {
  DrillType? drill,
  double random = 0,
  bool showsGenderImage = true,
}) async {
  final clock = FakeClock(noon, offset: paris);
  final session = await DrillSession.open(
    drill: drill,
    store: store,
    clock: clock,
    scheduler: DrillScheduler(random: () => 0.5),
    random: () => random,
    showsGenderImage: showsGenderImage,
  );
  return (session, clock);
}

T asked<T extends SessionCard>(DrillView view) =>
    (view as CardQuestion).card as T;

void main() {
  group('Genre', () {
    test('the noun, one of its images, and an example for later', () async {
      final (session, _) = await open(
        storeOf([genderCard()]),
        drill: DrillType.gender,
      );
      final card = asked<GenderCard>(await session.next());
      expect(card.item, table);
      expect(card.imageId, 'i.table-1');
      expect(card.example, table.examples.single);
      expect(card.offersTooEasy, isTrue);

      final (last, _) = await open(
        storeOf([genderCard()]),
        drill: DrillType.gender,
        random: 0.99,
      );
      expect(asked<GenderCard>(await last.next()).imageId, 'i.table-2');
    });

    test('no image when Afficher l’image is off', () async {
      final (session, _) = await open(
        storeOf([genderCard()]),
        drill: DrillType.gender,
        showsGenderImage: false,
      );
      expect(asked<GenderCard>(await session.next()).imageId, isNull);
    });

    test('the right tile moves straight on', () async {
      final store = storeOf([genderCard(), genderCard(id: 3)]);
      final (session, _) = await open(store, drill: DrillType.gender);
      final first = asked<GenderCard>(await session.next());
      final view = await session.choose(Gender.feminine);
      expect(asked<GenderCard>(view).card.id, isNot(first.card.id));
      expect(store.answers.single.outcome.rating, Rating.good);
      expect(store.answers.single.typed, isNull);
    });

    test('a wrong tile stays, with Faute de frappe', () async {
      final store = storeOf([genderCard()]);
      final (session, _) = await open(store, drill: DrillType.gender);
      await session.next();
      final view = await session.choose(Gender.masculine) as CardFeedback;
      expect(view.chosen, Gender.masculine);
      expect(view.grade.rating, Rating.again);
      expect(view.offersTypo, isTrue);

      final typo = await session.markTypo() as CardFeedback;
      expect(typo.grade.rating, Rating.hard);
      expect(typo.chosen, Gender.masculine);
      expect(session.summary.correct, 1);
    });

    test('no typing: no Valider, no Je ne sais pas', () async {
      final (session, _) = await open(
        storeOf([genderCard()]),
        drill: DrillType.gender,
      );
      await session.next();
      expect(() => session.submit('table'), throwsStateError);
      expect(session.giveUp, throwsStateError);
    });

    test('Trop facile on a new word', () async {
      final store = storeOf([genderCard()]);
      final (session, _) = await open(store, drill: DrillType.gender);
      await session.next();
      await session.tooEasy();
      expect(store.answers.single.outcome.rating, Rating.easy);
    });
  });

  group('Conjugaison', () {
    test('a person at random, then one of its sentences', () async {
      final (first, _) = await open(
        storeOf([conjugationCard()]),
        drill: DrillType.conjugation,
      );
      final card = asked<ConjugationCard>(await first.next());
      expect(card.sentence, vais);
      expect(card.item, aller);
      expect(card.aroundBlank, ('zz ', ' zz.'));
      expect(card.typings, ['vais']);
      expect(card.answer, 'vais');

      final (last, _) = await open(
        storeOf([conjugationCard()]),
        drill: DrillType.conjugation,
        random: 0.99,
      );
      // 3s, which has two sentences, is no likelier than 1s.
      expect(asked<ConjugationCard>(await last.next()).sentence, vaToo);
    });

    test('graded against the sentence and its alternatives', () async {
      final store = FakeStore(
        cards: [conjugationCard()],
        verbs: {
          ('v.payer', Tense.present): const ConjugationItem(
            verbId: 'v.payer',
            infinitive: 'payer',
            tense: Tense.present,
            sentences: [
              ConjugationSentence(
                id: 's.p',
                text: 'zz paie zz.',
                person: Person.firstSingular,
                answer: 'paie',
                alternatives: ['paye'],
              ),
            ],
          ),
        },
      );
      final cards = [
        newCard(itemId: 'v.payer', drill: DrillType.conjugation, id: 4),
        newCard(itemId: 'v.payer', drill: DrillType.conjugation, id: 5),
      ];
      final (session, _) = await open(
        FakeStore(cards: cards, verbs: store.verbs),
        drill: DrillType.conjugation,
      );
      final card = asked<ConjugationCard>(await session.next());
      expect(card.typings, ['paie', 'paye']);
      final view = await session.submit('paye');
      expect(view, isA<CardQuestion>(), reason: 'Correct moves on');
      final wrong = await session.submit('pays') as CardFeedback;
      expect(wrong.grade.rating, Rating.again);
      expect(wrong.typed, 'pays');
    });

    test('Je ne sais pas shows the sentence’s answer', () async {
      final (session, _) = await open(
        storeOf([conjugationCard()]),
        drill: DrillType.conjugation,
      );
      await session.next();
      final view = await session.giveUp() as CardFeedback;
      expect(view.grade, const Grade.gaveUp('vais'));
    });

    test('Je le connais marks the verb in this tense only', () async {
      final present = conjugationCard();
      final imparfait = conjugationCard(id: 9, tense: Tense.imparfait);
      final store = FakeStore(
        cards: [present, imparfait],
        verbs: {
          ('v.aller', Tense.present): aller,
          ('v.aller', Tense.imparfait): const ConjugationItem(
            verbId: 'v.aller',
            infinitive: 'aller',
            tense: Tense.imparfait,
            sentences: [vais],
          ),
        },
      );
      final (session, _) = await open(store, drill: DrillType.conjugation);
      await session.next();
      await session.markKnown();
      expect(store.knownCalls.single.$1, [present.id]);
    });

    test('a verb with no sentence in the tense is a content error', () async {
      final store = FakeStore(
        cards: [conjugationCard()],
        verbs: {
          ('v.aller', Tense.present): const ConjugationItem(
            verbId: 'v.aller',
            infinitive: 'aller',
            tense: Tense.present,
          ),
        },
      );
      final (session, _) = await open(store, drill: DrillType.conjugation);
      expect(session.next, throwsStateError);
    });
  });

  group('the blank in a Conjugaison sentence', () {
    test('an elided word before it is written in full', () {
      const habite = ConjugationSentence(
        id: 's.h',
        text: 'J’habite zz.',
        person: Person.firstSingular,
        answer: 'habite',
      );
      expect(habite.aroundBlank, ('Je ', ' zz.'));
      const broken = ConjugationSentence(
        id: 's.x',
        text: 'zz',
        person: Person.firstSingular,
        answer: 'vais',
      );
      expect(broken.aroundBlank, isNull);
    });

    test('elides again as the user types a vowel or a silent h', () {
      expect(elideBefore('Je ', 'habite', hAspire: false), 'J’');
      expect(elideBefore('Je ', 'h', hAspire: true), 'Je ');
      expect(elideBefore('Je ', 'aime', hAspire: false), 'J’');
      expect(elideBefore('Je ', 'vais', hAspire: false), 'Je ');
      expect(elideBefore('Je ', '', hAspire: false), 'Je ');
      expect(elideBefore('Tu ne ', 'es', hAspire: false), 'Tu n’');
      expect(elideBefore('zz le ', 'Aime', hAspire: false), 'zz l’');
      expect(elideBefore('Ce ', 'est', hAspire: false), 'C’');
      expect(elideBefore('Nous ', 'allons', hAspire: false), 'Nous ');
      expect(elideBefore('', 'allons', hAspire: false), '');
    });

    test('the card adjusts its words before the box', () {
      final card = ConjugationCard(
        card: conjugationCard(),
        item: aller,
        sentence: const ConjugationSentence(
          id: 's.h',
          text: 'J’habite zz.',
          person: Person.firstSingular,
          answer: 'habite',
        ),
      );
      expect(card.beforeBlank(''), 'Je ');
      expect(card.beforeBlank('h'), 'J’');
      final vocabulary = VocabularyCard(
        card: newCard(),
        item: table,
        prompt: const DefinitionPrompt('def table'),
      );
      expect(vocabulary.beforeBlank('a'), '');
    });
  });

  group('a mixed session', () {
    test('serves all three drills, the noun drills apart', () async {
      final store = storeOf([
        genderCard(),
        newCard(itemId: 'n.table', id: 5),
        conjugationCard(),
      ]);
      final (session, _) = await open(store);
      expect(session.drill, isNull);
      final seen = <DrillType>[];
      var view = await session.next();
      for (var i = 0; i < 3; i++) {
        final card = (view as CardQuestion).card;
        seen.add(card.card.drill);
        view = await session.tooEasy();
      }
      expect(seen, [
        DrillType.gender,
        DrillType.conjugation,
        DrillType.vocabulary,
      ]);
      expect(store.sessionsStarted, hasLength(1));
    });

    test('its summary has each drill’s numbers', () async {
      final store = storeOf([genderCard(), conjugationCard()]);
      final (session, clock) = await open(store);
      expect(session.summary.byDrill, isEmpty);
      await session.next();
      clock.advance(const Duration(seconds: 3));
      await session.choose(Gender.masculine);
      await session.next();
      clock.advance(const Duration(seconds: 5));
      await session.submit('vais');

      final summary = session.summary;
      expect(summary.answered, 2);
      expect(summary.correct, 1);
      expect(summary.duration, const Duration(seconds: 8));
      final gender = summary.byDrill[DrillType.gender]!;
      expect(gender.answered, 1);
      expect(gender.correct, 0);
      expect(gender.duration, const Duration(seconds: 3));
      final conjugation = summary.byDrill[DrillType.conjugation]!;
      expect(conjugation.percentCorrect, 100);
      expect(conjugation.duration, const Duration(seconds: 5));
      expect(summary.byDrill.containsKey(DrillType.vocabulary), isFalse);
    });

    test('Je le connais on a noun takes it out of both its drills', () async {
      final store = storeOf([
        genderCard(),
        newCard(itemId: 'n.table', id: 5),
        conjugationCard(),
      ]);
      final (session, _) = await open(store);
      await session.next();
      final (_, view) = await session.markKnown();
      expect(store.knownCalls.single.$1, [1, 5]);
      expect((view as CardQuestion).card.card.drill, DrillType.conjugation);
      // Only the verb is left, in free practice.
      final after = await session.tooEasy();
      expect((after as CardQuestion).card.card.drill, DrillType.conjugation);
    });

    test('the goal, when every drill has reached it', () async {
      final store = FakeStore(
        cards: [
          reviewCard(due: noon, itemId: 'n.table', drill: DrillType.gender),
        ],
        items: {'n.table': table},
        setup: const DrillQueueSetup(
          settings: QueueSettings(maxReviewsPerDay: 10),
        ),
        counts: const DayCounts(reviews: 10),
      );
      final (session, _) = await open(store);
      expect(await session.next(), isA<GoalReached>());
    });
  });
}
