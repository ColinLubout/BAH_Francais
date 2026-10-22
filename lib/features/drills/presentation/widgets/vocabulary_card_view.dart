import 'dart:math' as math;

import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/feedback_colors.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/presentation/widgets/accent_bar.dart';
import 'package:bah_francais/features/drills/presentation/widgets/blank_sentence.dart';
import 'package:bah_francais/features/drills/presentation/widgets/correction.dart';
import 'package:bah_francais/features/drills/presentation/widgets/live_feedback_controller.dart';
import 'package:flutter/material.dart';

/// A Vocabulaire card, from its question to its correction (decisions 70
/// to 72).
///
/// The question: the prompt, the sentence with the answer box in place of
/// the noun, *Trop facile* when the word is new, *Je ne sais pas* and
/// *Valider* side by side, and the accent bar above the keyboard. The
/// keyboard opens with the card; Enter submits, and an empty answer can't
/// be.
///
/// The correction, after an answer that wasn't Correct: everything stays in
/// place, the box keeping what was typed, with the result and the answer
/// under the sentence, and *Faute de frappe* and *Suivant* in place of the
/// buttons. Keep one per card, so what was typed carries over.
class VocabularyCardView extends StatefulWidget {
  const VocabularyCardView({
    required this.card,
    required this.prompt,
    required this.liveFeedback,
    required this.onSubmit,
    required this.onGiveUp,
    required this.onTooEasy,
    required this.onTypo,
    required this.onNext,
    this.feedback,
    this.notice,
    this.controlsKey,
    super.key,
  });

  /// On the buttons and accent bar, so a snackbar can sit above them.
  final Key? controlsKey;

  final VocabularyCard card;

  /// The correction, once the card is answered.
  final CardFeedback? feedback;

  /// The image or definition, above the sentence.
  final Widget prompt;

  /// Above the card from its question on, so the card doesn't move when
  /// the correction shows: *Tout est à jour*.
  final Widget? notice;

  /// *Correction en direct*.
  final bool liveFeedback;

  /// [capsGrade]: a letter went red or orange while typing.
  final void Function(String typed, {required bool capsGrade}) onSubmit;
  final VoidCallback onGiveUp;

  /// *Trop facile*, on a word seen for the first time (decision 72).
  final VoidCallback onTooEasy;

  /// *Faute de frappe*.
  final VoidCallback onTypo;

  /// *Suivant*.
  final VoidCallback onNext;

  @override
  State<VocabularyCardView> createState() => _VocabularyCardViewState();
}

class _VocabularyCardViewState extends State<VocabularyCardView> {
  late final LiveFeedbackController _controller = LiveFeedbackController(
    typings: widget.card.typings,
    enabled: widget.liveFeedback,
  )..addListener(_changed);

  /// The notice the question had, kept through its correction.
  late final Widget? _notice = widget.notice;

  /// A letter went red or orange at some point: the grade is capped at Hard,
  /// even once it is corrected.
  bool _flagged = false;

  /// The box's padding either side of its text.
  static const _padding = 10.0;

  /// Room kept in the box for the ✗, so it doesn't widen when one appears.
  static const _iconRoom = 26.0;

  /// The box's width for its text, in the sentence's font size: as wide
  /// for every word, so it never hints at the word's length.
  static const _boxEms = 5.0;

  void _changed() {
    if (_controller.feedback.capsGrade) _flagged = true;
    setState(() {});
  }

  bool get _answered => widget.feedback != null;

  bool get _canSubmit => !_answered && _controller.text.trim().isNotEmpty;

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
    final style = Theme.of(context).textTheme.titleLarge!;
    final scaler = MediaQuery.textScalerOf(context);
    final (before, after) = widget.card.sentence?.aroundBlank ?? ('', '');
    final feedback = widget.feedback;
    // Wider only as the typing needs.
    final fieldWidth =
        math.max(
          scaler.scale(style.fontSize!) * _boxEms,
          textWidth(_controller.text, style, scaler),
        ) +
        2 * _padding +
        _iconRoom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?_notice,
        Expanded(
          child: BlankSentence(
            header: widget.prompt,
            before: before,
            after: after,
            style: style,
            fieldWidth: fieldWidth,
            holdLine: _answered,
            footer: feedback == null ? null : Correction(feedback.grade),
            // The hint is for screen readers only (decision 71).
            field: Semantics(
              label: Strings.drillAnswerHint,
              child: TextField(
                controller: _controller,
                autofocus: true,
                readOnly: _answered,
                showCursor: !_answered,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                // Enter keeps the keyboard open until the answer is graded,
                // so the box doesn't move meanwhile.
                onEditingComplete: () {},
                style: style,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _padding,
                    vertical: 10,
                  ),
                  border: const OutlineInputBorder(),
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
        ),
        Column(
          key: widget.controlsKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No answer needed: Easy, and the next word (decision 72).
            if (!_answered && widget.card.offersTooEasy)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Center(
                  child: TextButton(
                    onPressed: widget.onTooEasy,
                    child: const Text(
                      Strings.drillTooEasy,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            _buttons(feedback),
            if (!_answered) AccentBar(controller: _controller),
          ],
        ),
      ],
    );
  }

  /// *Je ne sais pas* and *Valider*, or after the answer *Faute de frappe*
  /// and *Suivant*.
  Widget _buttons(CardFeedback? feedback) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: switch (feedback) {
            null => TextButton(
              onPressed: widget.onGiveUp,
              child: const Text(
                Strings.drillIDontKnow,
                textAlign: TextAlign.center,
              ),
            ),
            CardFeedback(offersTypo: true) => TextButton(
              onPressed: widget.onTypo,
              child: const Text(Strings.drillTypo, textAlign: TextAlign.center),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: feedback == null
              ? FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text(
                    Strings.drillSubmit,
                    textAlign: TextAlign.center,
                  ),
                )
              : FilledButton(
                  onPressed: widget.onNext,
                  autofocus: true,
                  child: const Text(
                    Strings.drillNext,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    ),
  );
}
