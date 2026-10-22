import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/session_card.dart';
import 'package:bah_francais/features/drills/presentation/widgets/correction.dart';
import 'package:bah_francais/features/drills/presentation/widgets/prompt_image.dart';
import 'package:flutter/material.dart';

/// A Genre card, from its question to its correction (decisions 75, 77 and
/// 78).
///
/// The tiles at the top — féminin, masculin, les deux — then the noun, with
/// its gloss, and its image when there is one. Tapping a tile answers. On a
/// new word, *Trop facile* sits at the bottom. After a wrong answer nothing
/// above moves: the chosen tile stays filled, the correction comes under the
/// image, and *Faute de frappe* and *Suivant* sit at the bottom. Keep one per
/// card, so the notice above it carries over.
class GenderCardView extends StatefulWidget {
  const GenderCardView({
    required this.card,
    required this.onChoose,
    required this.onTooEasy,
    required this.onTypo,
    required this.onNext,
    this.feedback,
    this.notice,
    this.controlsKey,
    super.key,
  });

  final GenderCard card;

  /// The correction, once the card is answered.
  final CardFeedback? feedback;

  /// Above the card from its question on: *Tout est à jour*.
  final Widget? notice;

  /// On the buttons at the bottom, so a snackbar can sit above them.
  final Key? controlsKey;

  final void Function(Gender) onChoose;

  /// *Trop facile*, on a word seen for the first time (decision 72).
  final VoidCallback onTooEasy;

  /// *Faute de frappe*.
  final VoidCallback onTypo;

  /// *Suivant*.
  final VoidCallback onNext;

  @override
  State<GenderCardView> createState() => _GenderCardViewState();
}

class _GenderCardViewState extends State<GenderCardView> {
  /// The notice the question had, kept through its correction.
  late final Widget? _notice = widget.notice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = widget.card;
    final item = card.item;
    final feedback = widget.feedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?_notice,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Tiles(
                  chosen: feedback?.chosen,
                  onChoose: feedback == null ? widget.onChoose : null,
                ),
                const SizedBox(height: 24),
                Text(
                  item.answer.word,
                  textAlign: TextAlign.center,
                  style: textTheme.displaySmall,
                ),
                if (item.gloss case final gloss?)
                  Text(
                    gloss,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                if (card.imageId case final imageId?) ...[
                  const SizedBox(height: 16),
                  PromptImage(imageId),
                ],
                if (feedback != null) ...[
                  const SizedBox(height: 24),
                  Correction(
                    feedback.grade,
                    answer: item.answer.withIndefiniteArticle(),
                    below: [
                      if (card.example case final example?)
                        ExampleText(example),
                      if (item.endingHint case final hint?) TipLine(hint),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          key: widget.controlsKey,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: switch (feedback) {
            null when card.offersTooEasy => Center(
              child: TextButton(
                onPressed: widget.onTooEasy,
                child: const Text(
                  Strings.drillTooEasy,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            null => const SizedBox.shrink(),
            final feedback => Row(
              children: [
                Expanded(
                  child: feedback.offersTypo
                      ? TextButton(
                          onPressed: widget.onTypo,
                          child: const Text(
                            Strings.drillTypo,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
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
          },
        ),
      ],
    );
  }
}

/// The three gender tiles, always all shown so the layout never hints at
/// the answer. An unselected symbol is blue on the background; the chosen
/// one sits on a filled teal tile in yellow.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.chosen, required this.onChoose});

  /// The tile tapped, once the card is answered.
  final Gender? chosen;

  /// Null once the card is answered.
  final void Function(Gender)? onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (gender, label, icons) in const [
          (Gender.feminine, Strings.drillGenderFeminine, [Icons.female]),
          (Gender.masculine, Strings.drillGenderMasculine, [Icons.male]),
          (Gender.both, Strings.drillGenderBoth, [Icons.female, Icons.male]),
        ])
          _Tile(
            label: label,
            icons: icons,
            selected: chosen == gender,
            onTap: switch (onChoose) {
              final choose? => () => choose(gender),
              null => null,
            },
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icons,
    required this.selected,
    required this.onTap,
  });

  /// For screen readers: *féminin*, *masculin*, *les deux*.
  final String label;
  final List<IconData> icons;
  final bool selected;
  final VoidCallback? onTap;

  static const size = 96.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconSize = icons.length == 1 ? 64.0 : 44.0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final icon in icons)
                    Icon(
                      icon,
                      size: iconSize,
                      color: selected ? colors.tertiary : colors.secondary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
