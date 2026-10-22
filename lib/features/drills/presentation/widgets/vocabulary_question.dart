import 'dart:math' as math;

import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/presentation/widgets/accent_bar.dart';
import 'package:bah_francais/features/drills/presentation/widgets/blank_sentence.dart';
import 'package:bah_francais/features/drills/presentation/widgets/live_feedback_controller.dart';
import 'package:flutter/material.dart';

/// A Vocabulaire card waiting for its answer: the prompt, the sentence with
/// the answer box in place of the noun, *Je ne sais pas* and *Valider* side
/// by side, and the accent bar above the keyboard (decision 70). The
/// keyboard opens with the card; Enter submits, and an empty answer can't
/// be.
class VocabularyQuestion extends StatefulWidget {
  const VocabularyQuestion({
    required this.question,
    required this.prompt,
    required this.liveFeedback,
    required this.onSubmit,
    required this.onGiveUp,
    super.key,
  });

  final CardQuestion question;

  /// The image or definition, above the sentence.
  final Widget prompt;

  /// *Correction en direct*.
  final bool liveFeedback;

  /// [capsGrade]: a letter went red or orange while typing.
  final void Function(String typed, {required bool capsGrade}) onSubmit;
  final VoidCallback onGiveUp;

  @override
  State<VocabularyQuestion> createState() => _VocabularyQuestionState();
}

class _VocabularyQuestionState extends State<VocabularyQuestion> {
  late final LiveFeedbackController _controller = LiveFeedbackController(
    typings: widget.question.card.typings,
    enabled: widget.liveFeedback,
  )..addListener(_changed);

  /// A letter went red or orange at some point: the grade is capped at Hard,
  /// even once it is corrected.
  bool _flagged = false;

  /// The box's padding either side of its text.
  static const _padding = 10.0;

  /// Room kept in the box for the ✗, so it doesn't widen when one appears.
  static const _iconRoom = 26.0;

  void _changed() {
    if (_controller.feedback.capsGrade) _flagged = true;
    setState(() {});
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(_controller.text, capsGrade: _flagged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.titleLarge!;
    final hintStyle = textTheme.bodyMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    final (before, after) =
        widget.question.card.sentence?.aroundBlank ?? ('', '');
    // Wide enough for its hint, whatever the answer, so the box never hints
    // at the word's length; wider as the typing needs.
    final fieldWidth =
        math.max(
          textWidth(Strings.drillAnswerHint, hintStyle, scaler),
          textWidth(_controller.text, style, scaler),
        ) +
        2 * _padding +
        _iconRoom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BlankSentence(
            header: widget.prompt,
            before: before,
            after: after,
            style: style,
            fieldWidth: fieldWidth,
            field: TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: style,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: _padding,
                  vertical: 10,
                ),
                border: const OutlineInputBorder(),
                hintText: Strings.drillAnswerHint,
                hintStyle: hintStyle,
                suffixIcon: _controller.feedback.isWrong
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: FeedbackColors.of(context).wrong,
                          semanticLabel: Strings.accessibilityAnswerIncorrect,
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onGiveUp,
                  child: const Text(
                    Strings.drillIDontKnow,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text(
                    Strings.drillSubmit,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        AccentBar(controller: _controller),
      ],
    );
  }
}
