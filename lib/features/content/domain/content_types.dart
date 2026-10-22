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

  /// Auxiliary + participle: the participle may agree (*sommes allés*).
  bool get isCompound => this == passeCompose;
}

/// A grammatical person. The third persons cover *il / elle / on* and
/// *ils / elles*: the sentence decides which.
enum Person {
  firstSingular('1s'),
  secondSingular('2s'),
  thirdSingular('3s'),
  firstPlural('1p'),
  secondPlural('2p'),
  thirdPlural('3p');

  Person(this.id);

  final String id;
}

/// The auxiliary of a verb's compound tenses.
enum Auxiliary {
  avoir('avoir'),
  etre('etre');

  Auxiliary(this.id);

  final String id;
}

/// What a category holds.
enum CategoryKind {
  noun('noun'),
  verb('verb');

  CategoryKind(this.id);

  final String id;
}

/// Where a content row comes from: the content packs, or the user.
enum ContentSource {
  official('official'),
  perso('perso');

  ContentSource(this.id);

  final String id;
}

/// The format of a stored image.
enum ImageFormat {
  svg('svg'),
  png('png'),
  jpeg('jpeg');

  ImageFormat(this.id);

  final String id;
}

/// The value of [T] whose id is [id], as stored in content files and the
/// database; null if none has it.
T? byId<T extends Enum>(List<T> values, String id, String Function(T) idOf) {
  for (final value in values) {
    if (idOf(value) == id) return value;
  }
  return null;
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
