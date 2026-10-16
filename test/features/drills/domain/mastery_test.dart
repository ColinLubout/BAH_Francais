import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/mastery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('Nouveau: never reviewed', () {
    expect(MasteryLevel.of(newCard()), MasteryLevel.newCard);
  });

  test('En apprentissage: learning or relearning', () {
    expect(MasteryLevel.of(learningCard(due: noon)), MasteryLevel.learning);
    expect(
      MasteryLevel.of(learningCard(due: noon, state: CardState.relearning)),
      MasteryLevel.learning,
    );
  });

  test('Fragile, Acquis and Maîtrisé by stability, 7 and 90 inclusive', () {
    MasteryLevel at(double stability) =>
        MasteryLevel.of(reviewCard(due: noon, stability: stability));

    expect(at(0.5), MasteryLevel.fragile);
    expect(at(6.99), MasteryLevel.fragile);
    expect(at(7), MasteryLevel.acquired);
    expect(at(90), MasteryLevel.acquired);
    expect(at(90.01), MasteryLevel.mastered);
    expect(at(400), MasteryLevel.mastered);
  });

  test('Connu: marked known, whatever the state', () {
    expect(MasteryLevel.of(newCard().withKnownAt(noon)), MasteryLevel.known);
    expect(
      MasteryLevel.of(reviewCard(due: noon, stability: 200, knownAt: noon)),
      MasteryLevel.known,
    );
  });
}
