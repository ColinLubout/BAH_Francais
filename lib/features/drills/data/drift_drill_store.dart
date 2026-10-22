import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/study_day.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/data/cards_dao.dart';
import 'package:bah_francais/features/drills/data/category_weights_dao.dart';
import 'package:bah_francais/features/drills/data/sessions_dao.dart';
import 'package:bah_francais/features/drills/domain/answer.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/queue/session_queue.dart';
import 'package:bah_francais/features/drills/domain/session/conjugation_item.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:drift/drift.dart';

/// The drill sessions' store, over the app's database.
class DriftDrillStore implements DrillStore {
  DriftDrillStore(this._db)
    : _cards = CardsDao(_db),
      _sessions = SessionsDao(_db),
      _weights = CategoryWeightsDao(_db),
      _content = ContentStore(_db, _db);

  final AppDatabase _db;
  final CardsDao _cards;
  final SessionsDao _sessions;
  final CategoryWeightsDao _weights;
  final ContentStore _content;

  @override
  Future<List<QueueCard>> queueCards(DrillType drill) =>
      _cards.queueCards(drill);

  /// The drill's category weights; its limits stay at their defaults until
  /// the drill settings screens (milestone 6).
  @override
  Future<DrillQueueSetup> queueSetup(DrillType drill) async => DrillQueueSetup(
    settings: QueueSettings(categoryWeights: await _weights.weights(drill)),
    everydayCategoryIds: await _content.everydayCategoryIds(
      drill == DrillType.conjugation ? CategoryKind.verb : CategoryKind.noun,
    ),
  );

  @override
  Future<DayCounts> dayCounts(DrillType drill, StudyDay day) =>
      _cards.dayCounts(drill, day);

  @override
  Future<int> startSession({required DrillType? drill, required DateTime at}) =>
      _sessions.start(drill: drill, at: at);

  @override
  Future<int> recordAnswer(Answer answer) => _cards.recordAnswer(answer);

  @override
  Future<void> replaceAnswer(int logId, Answer answer) =>
      _cards.replaceAnswer(logId, answer);

  @override
  Future<List<DrillCard>> cardsOfItem(String itemId) =>
      _cards.cardsOfItem(itemId);

  @override
  Future<void> setKnownAt(Iterable<int> cardIds, DateTime? at) =>
      _cards.setKnownAt(cardIds, at);

  /// The verb, with the sentences that are prompts for it in [tense], in
  /// every person, ordered by id.
  @override
  Future<ConjugationItem> conjugationItem(String verbId, Tense tense) async {
    final verb = await (_db.select(
      _db.verbs,
    )..where((v) => v.id.equals(verbId))).getSingle();
    final rows =
        await (_db.select(_db.sentenceVerbs).join([
                innerJoin(
                  _db.sentences,
                  _db.sentences.id.equalsExp(_db.sentenceVerbs.sentenceId),
                ),
              ])
              ..where(
                _db.sentenceVerbs.verbId.equals(verbId) &
                    _db.sentenceVerbs.tense.equalsValue(tense) &
                    _db.sentenceVerbs.retired.not() &
                    _db.sentences.retired.not(),
              )
              ..orderBy([OrderingTerm(expression: _db.sentences.id)]))
            .get();
    return ConjugationItem(
      verbId: verb.id,
      infinitive: verb.infinitive,
      tense: tense,
      hAspire: verb.hAspire,
      sentences: [
        for (final row in rows)
          if (row.readTable(_db.sentenceVerbs) case final link)
            ConjugationSentence(
              id: link.sentenceId,
              text: row.readTable(_db.sentences).sentenceText,
              person: link.person,
              answer: link.answer,
              alternatives: link.alternatives,
              before: link.before,
            ),
      ],
    );
  }

  /// The noun, official or the user's own, with its images in the order they
  /// were added and the sentences that use it.
  @override
  Future<NounItem> nounItem(String nounId) async {
    final noun = await (_db.select(
      _db.nouns,
    )..where((n) => n.id.equals(nounId))).getSingle();
    final images =
        await (_db.selectOnly(_db.images)
              ..addColumns([_db.images.id])
              ..where(_db.images.itemId.equals(nounId))
              ..orderBy([OrderingTerm(expression: _db.images.rowId)]))
            .map((row) => row.read(_db.images.id)!)
            .get();
    final uses =
        await (_db.select(_db.sentenceNouns).join([
                innerJoin(
                  _db.sentences,
                  _db.sentences.id.equalsExp(_db.sentenceNouns.sentenceId),
                ),
              ])
              ..where(
                _db.sentenceNouns.nounId.equals(nounId) &
                    _db.sentenceNouns.retired.not() &
                    _db.sentences.retired.not(),
              )
              ..orderBy([OrderingTerm(expression: _db.sentences.id)]))
            .get();
    return NounItem(
      nounId: noun.id,
      answer: VocabularyAnswer(
        word: noun.word,
        gender: noun.gender,
        synonyms: noun.synonyms,
        elides: noun.elides,
        pluralOnly: noun.pluralOnly,
      ),
      imageIds: images,
      definition: noun.definition,
      gloss: noun.gloss,
      endingHint: noun.endingHint,
      examples: [
        for (final row in uses)
          ExampleSentence.of(
            row.readTable(_db.sentences).sentenceText,
            row.readTable(_db.sentenceNouns).word,
          ),
      ],
    );
  }
}
