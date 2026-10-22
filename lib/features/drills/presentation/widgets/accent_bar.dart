import 'package:bah_francais/core/strings.g.dart';
import 'package:flutter/material.dart';

/// The keys above the keyboard for letters it may lack. A tap inserts the
/// letter at the cursor, and the field keeps its focus.
class AccentBar extends StatelessWidget {
  const AccentBar({required this.controller, super.key});

  final TextEditingController controller;

  static const letters = [
    'é', 'è', 'ê', 'ë', 'à', 'â', 'ç', 'ù', 'û', 'î', 'ï', 'ô', 'œ', '’', //
  ];

  /// A comfortable tap target.
  static const keySize = 48.0;

  void _insert(String letter) {
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    controller.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, letter),
      selection: TextSelection.collapsed(
        offset: selection.start + letter.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Taps here count as taps in the field, so it keeps the keyboard open.
    return TextFieldTapRegion(
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: keySize,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final letter in letters)
                Semantics(
                  button: true,
                  label: Strings.accessibilityAccentKey(word: letter),
                  excludeSemantics: true,
                  child: InkWell(
                    canRequestFocus: false,
                    onTap: () => _insert(letter),
                    child: SizedBox(
                      width: keySize,
                      child: Center(
                        child: Text(letter, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
