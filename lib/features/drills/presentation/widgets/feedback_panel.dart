import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/app_text_styles.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:flutter/material.dart';

/// The panel after an answer: the result with an icon as well as colour,
/// the correct answer with any error highlighted, an example sentence, the
/// override that applies, and *Suivant*.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    required this.feedback,
    required this.onOverride,
    required this.onNext,
    super.key,
  });

  final CardFeedback feedback;
  final VoidCallback onOverride;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final grade = feedback.grade;
    final example = feedback.example;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Result(grade.rating),
          const SizedBox(height: 8),
          if (grade.answer case final answer?) _CorrectAnswer(answer, grade),
          if (example != null) ...[
            const SizedBox(height: 8),
            _Example(example),
          ],
          if (feedback.offersTypo || feedback.offersTooEasy)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onOverride,
                child: Text(
                  feedback.offersTypo
                      ? Strings.drillTypo
                      : Strings.drillTooEasy,
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onNext,
            autofocus: true,
            child: const Text(Strings.drillNext),
          ),
          SizedBox(height: theme.visualDensity.vertical),
        ],
      ),
    );
  }
}

/// *Correct*, *Presque* or *Incorrect*, with an icon as well as colour.
class _Result extends StatelessWidget {
  const _Result(this.rating);

  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final colors = FeedbackColors.of(context);
    final (word, color, icon) = switch (rating) {
      Rating.good || Rating.easy => (
        Strings.drillResultCorrect,
        colors.correct,
        Icons.check_circle_outline,
      ),
      Rating.hard => (
        Strings.drillResultAlmost,
        colors.accentOnly,
        Icons.error_outline,
      ),
      Rating.again => (
        Strings.drillResultIncorrect,
        colors.wrong,
        Icons.cancel_outlined,
      ),
    };
    final style = Theme.of(context).textTheme.titleLarge
        ?.merge(AppTextStyles.of(context).emphasis.copyWith(color: color));
    return Row(
      children: [
        ExcludeSemantics(child: Icon(icon, color: color)),
        const SizedBox(width: 8),
        Flexible(child: Text(word, style: style)),
      ],
    );
  }
}

/// *Réponse : …*, with the parts the user got wrong highlighted.
class _CorrectAnswer extends StatelessWidget {
  const _CorrectAnswer(this.answer, this.grade);

  final String answer;
  final Grade grade;

  static const _marker = '\u0000';

  @override
  Widget build(BuildContext context) {
    final colors = FeedbackColors.of(context);
    final accent = grade.errorType == ErrorType.accent;
    final highlight = TextStyle(
      color: accent ? colors.accentOnly : colors.wrong,
      decoration: TextDecoration.underline,
      decorationStyle: accent
          ? TextDecorationStyle.dotted
          : TextDecorationStyle.solid,
      decorationColor: accent ? colors.accentOnly : colors.wrong,
    );
    // The wording around the answer comes from the strings file.
    final template = Strings.drillCorrectAnswer(answer: _marker);
    final at = template.indexOf(_marker);
    final spans = <TextSpan>[TextSpan(text: template.substring(0, at))];
    var pos = 0;
    for (final error in grade.errors) {
      if (error.start < pos || error.end > answer.length) continue;
      spans
        ..add(TextSpan(text: answer.substring(pos, error.start)))
        ..add(
          TextSpan(
            text: answer.substring(error.start, error.end),
            style: highlight,
          ),
        );
      pos = error.end;
    }
    spans
      ..add(TextSpan(text: answer.substring(pos)))
      ..add(TextSpan(text: template.substring(at + _marker.length)));
    return Text.rich(
      TextSpan(children: spans),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

/// One of the noun's sentences, with the noun in bold.
class _Example extends StatelessWidget {
  const _Example(this.example);

  final ExampleSentence example;

  @override
  Widget build(BuildContext context) {
    final text = example.text;
    final highlight = example.highlight;
    return Text.rich(
      TextSpan(
        children: highlight == null
            ? [TextSpan(text: text)]
            : [
                TextSpan(text: text.substring(0, highlight.start)),
                TextSpan(
                  text: text.substring(highlight.start, highlight.end),
                  style: AppTextStyles.of(context).emphasis,
                ),
                TextSpan(text: text.substring(highlight.end)),
              ],
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
