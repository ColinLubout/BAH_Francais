/// The fixed values content uses. Each has the `id` stored in content files
/// and the database.
library;

/// A noun's grammatical gender.
enum Gender {
  masculine('m'),
  feminine('f'),

  /// The gender follows the person, with no change of meaning:
  /// *un/une élève*.
  both('both');

  Gender(this.id);

  final String id;
}

/// How advanced an item is. The declaration order is the learning order.
enum Level {
  debutant('debutant'),
  intermediaire('intermediaire'),
  avance('avance');

  Level(this.id);

  final String id;
}

/// A tense in the Conjugation drill. The declaration order is the order new
/// conjugation cards come in. Adding a tense later adds a value here, never a
/// column.
enum Tense {
  present('present'),
  passeCompose('passe_compose'),
  imparfait('imparfait'),
  futurSimple('futur_simple');

  Tense(this.id);

  final String id;
}

/// A verb's conjugation group.
enum VerbGroup {
  er('er'),
  ir('ir'),
  re('re'),

  /// Irregular verbs.
  irr('irr');

  VerbGroup(this.id);

  final String id;
}
