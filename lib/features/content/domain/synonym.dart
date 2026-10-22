import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:meta/meta.dart';

/// A word the Vocabulary drill accepts in place of its noun.
@immutable
class Synonym {
  const Synonym(this.word, {this.gender, this.elides});

  final String word;

  /// Its gender, when it differs from the noun's; null is the noun's.
  final Gender? gender;

  /// Whether it takes *l’*, when that differs from the noun; null is the
  /// noun's.
  final bool? elides;

  @override
  bool operator ==(Object other) =>
      other is Synonym &&
      other.word == word &&
      other.gender == gender &&
      other.elides == elides;

  @override
  int get hashCode => Object.hash(word, gender, elides);

  @override
  String toString() => 'Synonym($word, ${gender?.id}, $elides)';
}
