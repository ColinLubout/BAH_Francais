import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/grading/typing_feedback.dart';
import 'package:flutter/material.dart';

/// The answer field's text, coloured letter by letter as it is typed
/// (*Correction en direct*). Colour is never the only cue: right letters are
/// underlined, accent slips have a dotted underline, and the field shows a ✗
/// once a letter is wrong.
class LiveFeedbackController extends TextEditingController {
  LiveFeedbackController({required this.typings, required this.enabled});

  /// Every way of typing a right answer.
  final List<String> typings;

  /// *Correction en direct* is on.
  final bool enabled;

  /// The feedback on the text as it stands; empty when the setting is off.
  TypingFeedback get feedback =>
      enabled ? typingFeedback(text, typings) : const TypingFeedback([]);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final letters = feedback.letters;
    if (letters.length != text.length || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final colors = FeedbackColors.of(context);
    TextStyle styleOf(LetterState state) => switch (state) {
      LetterState.correct => TextStyle(
        color: colors.correct,
        decoration: TextDecoration.underline,
        decorationColor: colors.correct,
      ),
      LetterState.accentOnly => TextStyle(
        color: colors.accentOnly,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: colors.accentOnly,
      ),
      LetterState.wrong => TextStyle(color: colors.wrong),
    };

    // One span per run of letters in the same state.
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= letters.length; i++) {
      if (i == letters.length || letters[i] != letters[start]) {
        spans.add(
          TextSpan(
            text: text.substring(start, i),
            style: styleOf(letters[start]),
          ),
        );
        start = i;
      }
    }
    return TextSpan(style: style, children: spans);
  }
}
