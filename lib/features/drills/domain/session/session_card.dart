import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/session/conjugation_item.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:meta/meta.dart';

/// A card as the drill screen shows it, in one of the three drills.
@immutable
sealed class SessionCard {
  const SessionCard();

  DrillCard get card;

  /// The word is seen for the first time: *Trop facile* is offered, with no
  /// answer needed (decision 72).
  bool get offersTooEasy => card.state == CardState.newCard;
}

/// A card answered by typing, in a sentence: Vocabulaire or Conjugaison.
sealed class TypedCard extends SessionCard {
  const TypedCard();

  /// Every way of typing a right answer, for live feedback.
  List<String> get typings;

  /// The words before and after the answer box: both empty when there is
  /// no sentence.
  (String, String) get aroundBlank;

  /// The words before the box as they read while [typed] is typed: in
  /// Conjugaison, an elided word follows what is typed (decision 43).
  String beforeBlank(String typed) => aroundBlank.$1;

  /// The answer *Je ne sais pas* shows.
  String get answer;
}

/// A Genre card: the noun, maybe an image, and the tiles.
class GenderCard extends SessionCard {
  const GenderCard({
    required this.card,
    required this.item,
    this.imageId,
    this.example,
  });

  @override
  final DrillCard card;
  final NounItem item;

  /// One of the noun's images, when it has any and *Afficher l’image* is on.
  final String? imageId;

  /// One of the noun's sentences, which the correction shows.
  final ExampleSentence? example;
}

/// A Vocabulaire card.
class VocabularyCard extends TypedCard {
  const VocabularyCard({
    required this.card,
    required this.item,
    required this.prompt,
    this.sentence,
  });

  @override
  final DrillCard card;
  final NounItem item;
  final VocabularyPrompt prompt;

  /// The sentence the answer box sits in, the noun blanked; none when the
  /// noun has no sentence with it as it is typed.
  final ExampleSentence? sentence;

  /// The article is optional: the sentence around the box already has one
  /// (decision 70).
  @override
  List<String> get typings => item.answer.typings();

  @override
  (String, String) get aroundBlank => sentence?.aroundBlank ?? ('', '');

  @override
  String get answer => item.answer.word;
}

/// A Conjugaison card: one verb in one tense, asked in one of its
/// sentences.
class ConjugationCard extends TypedCard {
  const ConjugationCard({
    required this.card,
    required this.item,
    required this.sentence,
  });

  @override
  final DrillCard card;
  final ConjugationItem item;

  /// The sentence asked, for one person, picked at random on each review.
  final ConjugationSentence sentence;

  @override
  List<String> get typings => [sentence.answer, ...sentence.alternatives];

  @override
  (String, String) get aroundBlank => sentence.aroundBlank ?? ('', '');

  @override
  String beforeBlank(String typed) =>
      elideBefore(aroundBlank.$1, typed, hAspire: item.hAspire);

  @override
  String get answer => sentence.answer;
}
