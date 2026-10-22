import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:bah_francais/features/drills/domain/grading/normalise.dart';
import 'package:meta/meta.dart';

/// The articles a Vocabulary answer can start with, as [normalise] leaves
/// them. *l’* is joined to its noun; the others are followed by a space.
const _elided = 'l$apostrophe';
const List<String> _spaced = ['le', 'la', 'les', 'un', 'une', 'des'];
const Set<String> _definite = {'le', 'la', 'les', _elided};

/// What a Vocabulary card accepts: the noun and its synonyms, each with the
/// article rules of its own gender and elision.
@immutable
class VocabularyAnswer {
  const VocabularyAnswer({
    required this.word,
    required this.gender,
    this.synonyms = const [],
    this.elides = false,
    this.pluralOnly = false,
  });

  /// The noun, in the singular, or in the plural for [pluralOnly] nouns.
  final String word;

  final Gender gender;
  final List<Synonym> synonyms;

  /// Takes *l’* (*l’arbre*).
  final bool elides;

  /// Only used in the plural (*les ciseaux*), and so are its synonyms.
  final bool pluralOnly;

  /// Every accepted word with its article rules, the noun first.
  List<AcceptedWord> get accepted => [
    AcceptedWord(
      word: word,
      gender: gender,
      elides: elides,
      pluralOnly: pluralOnly,
    ),
    for (final synonym in synonyms)
      AcceptedWord(
        word: synonym.word,
        gender: synonym.gender ?? gender,
        elides: synonym.elides ?? elides,
        pluralOnly: pluralOnly,
      ),
  ];

  /// [word] as shown when no answer was typed (*Je ne sais pas*): with its
  /// indefinite article when the article is mandatory.
  String displayAnswer({required bool mandatory}) =>
      accepted.first.display(mandatory: mandatory);
}

/// A noun or synonym, with the articles that go with its gender and elision.
@immutable
class AcceptedWord {
  const AcceptedWord({
    required this.word,
    required this.gender,
    required this.elides,
    required this.pluralOnly,
  });

  final String word;
  final Gender gender;
  final bool elides;
  final bool pluralOnly;

  /// The articles accepted before the word.
  ///
  /// Singular nouns take *le/la* or *un/une* by gender (either gender for
  /// "les deux" nouns), plural-only nouns *les* or *des*. A noun that takes
  /// *l’* never takes *le/la*; *l’* itself is accepted only when the article
  /// is optional, because it doesn't show the gender.
  Set<String> validArticles({required bool mandatory}) {
    if (pluralOnly) return {'les', 'des'};
    final masculine = gender != Gender.feminine;
    final feminine = gender != Gender.masculine;
    return {
      if (masculine) 'un',
      if (feminine) 'une',
      if (!elides && masculine) 'le',
      if (!elides && feminine) 'la',
      if (elides && !mandatory) _elided,
    };
  }

  /// The article to show with the answer, preferring definite when the user
  /// typed a definite article.
  String displayArticle({required bool mandatory, String? typed}) {
    final valid = validArticles(mandatory: mandatory);
    if (typed != null && valid.contains(typed)) return typed;
    final wantsDefinite = typed != null && _definite.contains(typed);
    if (pluralOnly) return wantsDefinite ? 'les' : 'des';
    final feminine = gender == Gender.feminine;
    if (wantsDefinite && !elides) return feminine ? 'la' : 'le';
    return feminine ? 'une' : 'un';
  }

  /// [word], with its indefinite article when the article is mandatory.
  String display({required bool mandatory}) => mandatory
      ? joinArticle(displayArticle(mandatory: mandatory), word)
      : word;
}

/// Splits a normalised answer into its leading article, if any, and the
/// rest.
///
/// An article is known by what follows it: *le, la, les, un, une* or *des*
/// and a space, or *l’*. Such a start is always the article, since no noun is
/// spelled with one; without the space or apostrophe, it is part of the word.
({String? article, String rest}) splitArticle(String normalised) {
  if (normalised.startsWith(_elided)) {
    return (article: _elided, rest: normalised.substring(_elided.length));
  }
  for (final article in _spaced) {
    if (normalised.startsWith('$article ')) {
      return (article: article, rest: normalised.substring(article.length + 1));
    }
  }
  return (article: null, rest: normalised);
}

/// [article] and [word] as written: *l’arbre*, *la table*.
String joinArticle(String article, String word) =>
    article == _elided ? '$article$word' : '$article $word';
