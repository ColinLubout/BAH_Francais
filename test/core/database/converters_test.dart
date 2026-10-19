import 'package:bah_francais/core/database/converters.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enums are stored by their ids', () {
    expect(tenseConverter.toSql(Tense.passeCompose), 'passe_compose');
    expect(tenseConverter.fromSql('futur_simple'), Tense.futurSimple);
    expect(cardStateConverter.toSql(CardState.newCard), 'new');
    expect(drillConverter.toSql(DrillType.conjugation), 'conjugation');
    expect(sessionDrillConverter.toSql(null), 'mixed');
    expect(sessionDrillConverter.fromSql('mixed'), isNull);
    expect(sessionDrillConverter.toSql(DrillType.gender), 'gender');
    expect(sessionDrillConverter.fromSql('vocabulary'), DrillType.vocabulary);
    expect(genderConverter.fromSql('both'), Gender.both);
  });

  test('an unknown id is a format error', () {
    expect(
      () => levelConverter.fromSql('expert'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a rating is stored as its FSRS number', () {
    expect(ratingConverter.toSql(Rating.hard), 2);
    expect(ratingConverter.fromSql(4), Rating.easy);
    expect(() => ratingConverter.fromSql(5), throwsA(isA<FormatException>()));
  });

  test('a time is stored as its UTC instant and reads back in UTC', () {
    final local = DateTime(2026, 10, 19, 12, 30, 0, 1, 2);
    final stored = utcConverter.toSql(local);
    final read = utcConverter.fromSql(stored);
    expect(read.isUtc, isTrue);
    expect(read, local.toUtc());
    expect(read.microsecond, 2);
  });

  test('lists are stored as JSON', () {
    expect(stringListConverter.toSql(['paye', 'paie']), '["paye","paie"]');
    expect(stringListConverter.fromSql('[]'), isEmpty);
    const synonyms = [
      Synonym('auto', elides: true),
      Synonym('vélo', gender: Gender.masculine),
    ];
    final json = synonymListConverter.toSql(synonyms);
    expect(
      json,
      '[{"word":"auto","elides":true},'
      '{"word":"vélo","gender":"m"}]',
    );
    expect(synonymListConverter.fromSql(json), synonyms);
  });
}
