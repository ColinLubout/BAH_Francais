import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';

/// A drill's name, as Accueil, the mixed session and its summary show it.
String drillName(DrillType drill) => switch (drill) {
  DrillType.gender => Strings.homeDrillGender,
  DrillType.vocabulary => Strings.homeDrillVocabulary,
  DrillType.conjugation => Strings.homeDrillConjugation,
};
