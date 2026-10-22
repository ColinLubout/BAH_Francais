import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:bah_francais/features/drills/data/category_weights_dao.dart';
import 'package:bah_francais/features/drills/data/drift_drill_store.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/content_fixture.dart';
import '../../../helpers/fake_clock.dart';
import '../domain/helpers.dart';

final created = DateTime.utc(2026, 9);

/// The fixture's content with its cards.
Future<AppDatabase> withCards({
  List<String> nounIds = const ['n.aa', 'n.bb'],
}) async {
  final db = await databaseWith(fixture);
  await CardsDao(db).createCards(
    at: created,
    nounIds: nounIds,
    verbIds: ['v.cc'],
    tenses: fixture.tenses,
  );
  return db;
}

void main() {
  test(
    "the queue's setup: the drill's weights and everyday categories",
    () async {
      final db = await withCards();
      await CategoryWeightsDao(db)
          .setWeight(DrillType.vocabulary, 'cat.topic', CategoryWeight.plus);
      final setup = await DriftDrillStore(db).queueSetup(DrillType.vocabulary);
      expect(setup.settings.weightOf('cat.topic'), CategoryWeight.plus);
      expect(setup.everydayCategoryIds, {'cat.everyday'});
      expect(setup.settings.newPerDay, QueueSettings.defaultNewPerDay);
      expect(setup.settings.maxReviewsPerDay, isNull);
    },
  );

  test("an item's cards in every drill", () async {
    final db = await withCards();
    final cards = await DriftDrillStore(db).cardsOfItem('n.aa');
    expect(cards.map((c) => c.drill), {DrillType.gender, DrillType.vocabulary});
    expect(
      (await DriftDrillStore(db).cardsOfItem('v.cc')).map((c) => c.tense),
      fixture.tenses,
    );
  });

  test(
    'a Vocabulaire item: answer, images in order, definition, examples',
    () async {
      final db = await withCards();
      final item = await DriftDrillStore(db).vocabularyItem('n.aa');
      expect(item.nounId, 'n.aa');
      expect(item.answer.word, 'aa');
      expect(item.answer.gender, Gender.feminine);
      expect(item.answer.elides, isTrue);
      expect(item.answer.synonyms, const [
        Synonym('ab', gender: Gender.masculine),
        Synonym('ac'),
      ]);
      expect(item.imageIds, ['i.aa-1', 'i.aa-2']);
      expect(item.definition, 'aa definition');
      expect(item.examples, const [
        ExampleSentence('one cc present 1s aa', highlight: Span(18, 20)),
        ExampleSentence('three aa bbs', highlight: Span(6, 8)),
      ]);

      final bb = await DriftDrillStore(db).vocabularyItem('n.bb');
      expect(bb.answer.pluralOnly, isTrue);
      expect(bb.imageIds, isEmpty);
      expect(bb.definition, isNull);
    },
  );

  test(
    'a session over the database saves every answer as it is given',
    () async {
      // n.bb has neither an image nor a definition, which real content
      // can't have, so it stays out of the session.
      final db = await withCards(nounIds: ['n.aa']);
      final clock = FakeClock(noon, offset: paris);
      final session = await DrillSession.open(
        drill: DrillType.vocabulary,
        store: DriftDrillStore(db),
        clock: clock,
        scheduler: DrillScheduler(random: () => 0.5),
        random: () => 0,
      );
      final view = await session.next() as CardQuestion;
      clock.advance(const Duration(seconds: 3));
      final (next, offer) = await session.submit(view.card.item.answer.word);
      await session.tooEasy(offer!);

      final logs = await db.select(db.reviewLogs).get();
      expect(logs.single.rating, Rating.easy);
      expect(logs.single.cardId, view.card.card.id);
      final sessions = await db.select(db.sessions).get();
      expect(sessions.single.drillType, DrillType.vocabulary);
      expect(sessions.single.startTime, noon);
      expect(sessions.single.answered, 1);
      expect(sessions.single.correct, 1);

      // A Correct answer moved on: the mark is for the card now shown.
      final shown = (next as CardQuestion).card.item.nounId;
      final (mark, _) = await session.markKnown();
      final known = await DriftDrillStore(db).cardsOfItem(shown);
      expect(known.every((c) => c.isKnown), isTrue);
      await session.undoKnown(mark);
      final back = await DriftDrillStore(db).cardsOfItem(shown);
      expect(back.any((c) => c.isKnown), isFalse);
    },
  );
}
