import 'package:bah_francais/features/content/domain/sentence_prompt.dart';
import 'package:bah_francais/features/drills/domain/grading/answer_forms.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:meta/meta.dart';

/// What a Vocabulaire card needs from its noun.
@immutable
class VocabularyItem {
  const VocabularyItem({
    required this.nounId,
    required this.answer,
    this.imageIds = const [],
    this.definition,
    this.examples = const [],
  });

  final String nounId;

  /// The noun and its synonyms, with their article rules.
  final VocabularyAnswer answer;

  /// The noun's images; the prompt shows one of them.
  final List<String> imageIds;

  /// The prompt when there is no image (*Période de sept jours*).
  final String? definition;

  /// Sentences using the noun; the feedback panel shows one.
  final List<ExampleSentence> examples;

  /// The [examples] the answer box can sit in: those with the noun as it is
  /// typed (*chat*, not *chats*), or one of its synonyms.
  List<ExampleSentence> get sentencesToFill {
    final words = {for (final w in answer.accepted) w.word.toLowerCase()};
    return [
      for (final example in examples)
        if (example.blanked case final blanked?
            when words.contains(blanked.toLowerCase()))
          example,
    ];
  }
}

/// A sentence that uses a noun, with the noun's words to show in bold.
@immutable
class ExampleSentence {
  const ExampleSentence(this.text, {this.highlight});

  /// [text] with [word] in bold, if it is in the text exactly once.
  factory ExampleSentence.of(String text, String word) {
    final at = findOnce(text, word);
    return ExampleSentence(
      text,
      highlight: at == null ? null : Span(at.start, at.end),
    );
  }

  final String text;

  /// The noun in [text], shown in bold.
  final Span? highlight;

  /// The noun as [text] has it, which a question blanks.
  String? get blanked => switch (highlight) {
    final h? => text.substring(h.start, h.end),
    null => null,
  };

  /// [text] up to the noun, and from after it: the words around the answer
  /// box. All of [text] before, when it has no noun to blank.
  (String, String) get aroundBlank => switch (highlight) {
    final h? => (text.substring(0, h.start), text.substring(h.end)),
    null => (text, ''),
  };

  @override
  bool operator ==(Object other) =>
      other is ExampleSentence &&
      other.text == text &&
      other.highlight == highlight;

  @override
  int get hashCode => Object.hash(text, highlight);
}

/// What a Vocabulaire card shows to be named.
@immutable
sealed class VocabularyPrompt {
  const VocabularyPrompt();

  /// One of [item]'s images, chosen with [random] on each review, so the user
  /// learns the word rather than one picture; its definition when it has no
  /// image.
  factory VocabularyPrompt.of(VocabularyItem item, double Function() random) {
    final images = item.imageIds;
    if (images.isNotEmpty) {
      final index = (random() * images.length).floor();
      return ImagePrompt(images[index.clamp(0, images.length - 1)]);
    }
    final definition = item.definition;
    if (definition == null) {
      throw StateError('${item.nounId} has neither an image nor a definition');
    }
    return DefinitionPrompt(definition);
  }
}

class ImagePrompt extends VocabularyPrompt {
  const ImagePrompt(this.imageId);

  final String imageId;

  @override
  bool operator ==(Object other) =>
      other is ImagePrompt && other.imageId == imageId;

  @override
  int get hashCode => imageId.hashCode;
}

class DefinitionPrompt extends VocabularyPrompt {
  const DefinitionPrompt(this.definition);

  final String definition;

  @override
  bool operator ==(Object other) =>
      other is DefinitionPrompt && other.definition == definition;

  @override
  int get hashCode => definition.hashCode;
}
