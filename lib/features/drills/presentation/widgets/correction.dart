import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/app_text_styles.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/grading/grade.dart';
import 'package:bah_francais/features/drills/domain/rating.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:flutter/material.dart';

/// Under the card after an answer that wasn't Correct: the result with
/// an icon as well as colour, and the correct answer with any error
/// highlighted (decision 71).
class Correction extends StatelessWidget {
  const Correction(this.grade, {this.answer, this.below = const [], super.key});

  final Grade grade;

  /// The answer to show, when the grade has none: in Genre, the word with
  /// *un/une*.
  final String? answer;

  /// Under the answer: in Genre, an example sentence and the *Astuce*.
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Result(grade.rating),
        if (grade.answer ?? answer case final answer?) ...[
          const SizedBox(height: 8),
          _CorrectAnswer(answer, grade),
        ],
        for (final widget in below) ...[const SizedBox(height: 8), widget],
      ],
    );
  }
}

/// One of the noun's sentences, with the noun in bold.
class ExampleText extends StatelessWidget {
  const ExampleText(this.example, {super.key});

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
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

/// *Astuce*, and the content's ending rule (*-tion → féminin*).
class TipLine extends StatelessWidget {
  const TipLine(this.hint, {super.key});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        Text(
          Strings.drillTip,
          style: style?.merge(AppTextStyles.of(context).emphasis),
        ),
        Text(hint, style: style),
      ],
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
      mainAxisSize: MainAxisSize.min,
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
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
