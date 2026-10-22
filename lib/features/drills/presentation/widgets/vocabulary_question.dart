import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/presentation/widgets/accent_bar.dart';
import 'package:bah_francais/features/drills/presentation/widgets/live_feedback_controller.dart';
import 'package:flutter/material.dart';

/// A Vocabulaire card waiting for its answer: the field, *Je ne sais pas*,
/// *Valider*, and the accent bar above the keyboard. The keyboard opens with
/// the card; Enter submits, and an empty answer can't be.
class VocabularyQuestion extends StatefulWidget {
  const VocabularyQuestion({
    required this.question,
    required this.liveFeedback,
    required this.onSubmit,
    required this.onGiveUp,
    super.key,
  });

  final CardQuestion question;

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
    final card = widget.question.card;
    final wrong = _controller.feedback.isWrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: card.articleMandatory
                  ? Strings.drillAnswerHintWithArticle
                  : Strings.drillAnswerHint,
              suffixIcon: wrong
                  ? Icon(
                      Icons.close,
                      color: FeedbackColors.of(context).wrong,
                      semanticLabel: Strings.accessibilityAnswerIncorrect,
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: widget.onGiveUp,
              child: const Text(Strings.drillIDontKnow),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text(Strings.drillSubmit),
          ),
        ),
        AccentBar(controller: _controller),
      ],
    );
  }
}
