/// How values the tables hold are stored: enums by their ids, times in UTC,
/// lists as JSON.
library;

import 'dart:convert';

import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/card.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/queue/queue_settings.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:drift/drift.dart';

/// Stores an enum by its id: the value content files and the spec use.
class IdConverter<T extends Enum> extends TypeConverter<T, String> {
  const IdConverter(this._values, this._idOf);

  final List<T> _values;
  final String Function(T) _idOf;

  @override
  T fromSql(String fromDb) =>
      byId(_values, fromDb, _idOf) ??
      (throw FormatException('Not a $T id', fromDb));

  @override
  String toSql(T value) => _idOf(value);
}

String _genderId(Gender value) => value.id;
String _levelId(Level value) => value.id;
String _tenseId(Tense value) => value.id;
String _personId(Person value) => value.id;
String _verbGroupId(VerbGroup value) => value.id;
String _auxiliaryId(Auxiliary value) => value.id;
String _categoryKindId(CategoryKind value) => value.id;
String _sourceId(ContentSource value) => value.id;
String _imageFormatId(ImageFormat value) => value.id;
String _drillId(DrillType value) => value.name;
String _cardStateId(CardState value) => value.id;
String _errorTypeId(ErrorType value) => value.id;
String _weightId(CategoryWeight value) => value.id;

const IdConverter<Gender> genderConverter = IdConverter(
  Gender.values,
  _genderId,
);
const IdConverter<Level> levelConverter = IdConverter(Level.values, _levelId);
const IdConverter<Tense> tenseConverter = IdConverter(Tense.values, _tenseId);
const IdConverter<Person> personConverter = IdConverter(
  Person.values,
  _personId,
);
const IdConverter<VerbGroup> verbGroupConverter = IdConverter(
  VerbGroup.values,
  _verbGroupId,
);
const IdConverter<Auxiliary> auxiliaryConverter = IdConverter(
  Auxiliary.values,
  _auxiliaryId,
);
const IdConverter<CategoryKind> categoryKindConverter = IdConverter(
  CategoryKind.values,
  _categoryKindId,
);
const IdConverter<ContentSource> sourceConverter = IdConverter(
  ContentSource.values,
  _sourceId,
);
const IdConverter<ImageFormat> imageFormatConverter = IdConverter(
  ImageFormat.values,
  _imageFormatId,
);
const IdConverter<DrillType> drillConverter = IdConverter(
  DrillType.values,
  _drillId,
);
const IdConverter<CardState> cardStateConverter = IdConverter(
  CardState.values,
  _cardStateId,
);
const IdConverter<ErrorType> errorTypeConverter = IdConverter(
  ErrorType.values,
  _errorTypeId,
);
const IdConverter<CategoryWeight> weightConverter = IdConverter(
  CategoryWeight.values,
  _weightId,
);

/// Stores a rating as its FSRS number, 1 to 4.
class RatingConverter extends TypeConverter<Rating, int> {
  const RatingConverter();

  @override
  Rating fromSql(int fromDb) => Rating.values.firstWhere(
    (r) => r.value == fromDb,
    orElse: () => throw FormatException('Not a rating', fromDb),
  );

  @override
  int toSql(Rating value) => value.value;
}

const ratingConverter = RatingConverter();

/// Stores an instant as microseconds since the epoch, in UTC, so it reads
/// back exactly and always as UTC.
class UtcConverter extends TypeConverter<DateTime, int> {
  const UtcConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMicrosecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().microsecondsSinceEpoch;
}

const utcConverter = UtcConverter();

/// Stores a list of strings as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<Object?>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

const stringListConverter = StringListConverter();

/// Stores synonyms as a JSON array of objects, each with only what differs
/// from its noun.
class SynonymListConverter extends TypeConverter<List<Synonym>, String> {
  const SynonymListConverter();

  @override
  List<Synonym> fromSql(String fromDb) => [
    for (final entry in jsonDecode(fromDb) as List<Object?>)
      _synonym(entry! as Map<String, Object?>),
  ];

  @override
  String toSql(List<Synonym> value) =>
      jsonEncode([for (final s in value) synonymToJson(s)]);

  static Synonym _synonym(Map<String, Object?> json) {
    final gender = json['gender'] as String?;
    return Synonym(
      json['word']! as String,
      gender: gender == null ? null : genderConverter.fromSql(gender),
      elides: json['elides'] as bool?,
    );
  }
}

const synonymListConverter = SynonymListConverter();
