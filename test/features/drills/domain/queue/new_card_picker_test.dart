import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/queue/new_card_picker.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_card.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

QueueCard noun(
  String item, {
  List<String> categories = const ['cat.a'],
  Level? level = Level.debutant,
  int? rank = 1,
  bool perso = false,
  DateTime? added,
}) => QueueCard(
  card: newCard(itemId: item, createdAt: added),
  categoryIds: categories,
  level: level,
  rank: rank,
  isPerso: perso,
);

QueueCard verb(
  String item,
  Tense tense, {
  Level level = Level.debutant,
  int rank = 1,
}) => QueueCard(
  card: newCard(itemId: item, drill: DrillType.conjugation, tense: tense),
  categoryIds: const ['cat.verbes'],
  level: level,
  rank: rank,
  verbGroup: VerbGroup.irr,
);

String label(QueueCard c) {
  final tense = c.card.tense;
  return tense == null ? c.card.itemId : '${c.card.itemId}:${tense.id}';
}

/// The items the picker gives, one after another, taking each out.
List<String> drain(List<QueueCard> cards, {QueueSettings? settings}) {
  final picker = NewCardPicker(() => 0);
  final left = [...cards];
  final order = <String>[];
  while (true) {
    final next = picker.pick(left, settings ?? const QueueSettings());
    if (next == null) return order;
    order.add(label(next));
    left.remove(next);
  }
}

void main() {
  group('choosing a category', () {
    final cards = [
      noun('a1', categories: ['cat.a']),
      noun('b1', categories: ['cat.b']),
    ];

    QueueCard? pickWith(double roll, Map<String, CategoryWeight> weights) =>
        NewCardPicker(() => roll)
            .pick(cards, QueueSettings(categoryWeights: weights));

    test('in proportion to the weights', () {
      // Normal (1) and Plus (2): cat.a takes the first third.
      const weights = {'cat.b': CategoryWeight.plus};
      expect(pickWith(0.2, weights)!.card.itemId, 'a1');
      expect(pickWith(0.34, weights)!.card.itemId, 'b1');
      expect(pickWith(0.99, weights)!.card.itemId, 'b1');
    });

    test('Moins counts half', () {
      // Moins (0.5) and Normal (1): cat.a takes the first third.
      const weights = {'cat.a': CategoryWeight.moins};
      expect(pickWith(0.3, weights)!.card.itemId, 'a1');
      expect(pickWith(0.4, weights)!.card.itemId, 'b1');
    });

    test('never a Jamais category', () {
      const weights = {'cat.a': CategoryWeight.jamais};
      for (final roll in [0.0, 0.5, 0.99]) {
        expect(pickWith(roll, weights)!.card.itemId, 'b1');
      }
    });

    test('nothing when every category is Jamais or there are no cards', () {
      expect(
        pickWith(0.5, const {
          'cat.a': CategoryWeight.jamais,
          'cat.b': CategoryWeight.jamais,
        }),
        isNull,
      );
      expect(
        NewCardPicker(() => 0).pick(const [], const QueueSettings()),
        isNull,
      );
    });

    test(
      'a noun in several categories comes through any not set to Jamais',
      () {
        final shared = noun('shared', categories: ['cat.a', 'cat.b']);
        final picked = NewCardPicker(() => 0.9).pick(
          [shared],
          const QueueSettings(
            categoryWeights: {'cat.a': CategoryWeight.jamais},
          ),
        );
        expect(picked, shared);
      },
    );

    test('items with no category still come up', () {
      expect(drain([noun('x', categories: [])]), ['x']);
    });
  });

  group('order within a category', () {
    test('by level, then frequency rank', () {
      expect(
        drain([
          noun('c', level: Level.avance),
          noun('b', rank: 20),
          noun('a', level: Level.intermediaire),
          noun('d', rank: 3),
        ]),
        ['d', 'b', 'a', 'c'],
      );
    });

    test('Perso words first, oldest first', () {
      expect(
        drain([
          noun('official'),
          noun(
            'p.new',
            perso: true,
            level: null,
            rank: null,
            added: DateTime.utc(2026, 9, 20),
          ),
          noun(
            'p.old',
            perso: true,
            level: null,
            rank: null,
            added: DateTime.utc(2026, 9, 2),
          ),
        ]),
        ['p.old', 'p.new', 'official'],
      );
    });

    test('missing level or rank goes last; ties go by item id', () {
      expect(
        drain([
          noun('z', level: null),
          noun('y', rank: null),
          noun('b'),
          noun('a'),
        ]),
        ['a', 'b', 'y', 'z'],
      );
    });

    test('the order is the same whichever card is compared first', () {
      final ranked = noun('a');
      final unranked = noun('b', rank: null);
      expect(compareNewCards(ranked, unranked), isNegative);
      expect(compareNewCards(unranked, ranked), isPositive);
    });

    test('conjugation: level, then tense, then rank', () {
      expect(
        drain([
          verb('v.aller', Tense.passeCompose, rank: 5),
          verb('v.aller', Tense.present, rank: 5),
          verb('v.etre', Tense.present),
          verb('v.etre', Tense.passeCompose),
          verb('v.rare', Tense.present, level: Level.intermediaire),
        ]),
        [
          'v.etre:present',
          'v.aller:present',
          'v.etre:passe_compose',
          'v.aller:passe_compose',
          'v.rare:present',
        ],
      );
    });
  });
}
