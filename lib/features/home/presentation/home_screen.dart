import 'dart:async';

import 'package:bah_francais/app/router.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Accueil: the home screen, where a session starts.
///
/// So far it has the Vocabulaire tile; *Commencer*, the other tiles and the
/// rest of the screen come in milestone 4 (decision 69).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [DrillTile(drill: DrillType.vocabulary)],
        ),
      ),
    ),
  );
}

/// A drill's tile: its name, and under it how many cards are due today.
/// Disabled while the content is being prepared on the first launch.
class DrillTile extends ConsumerWidget {
  const DrillTile({required this.drill, super.key});

  final DrillType drill;

  static String nameOf(DrillType drill) => switch (drill) {
    DrillType.gender => Strings.homeDrillGender,
    DrillType.vocabulary => Strings.homeDrillVocabulary,
    DrillType.conjugation => Strings.homeDrillConjugation,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ready = ref.watch(contentReadyProvider).hasValue;
    final due = ref.watch(dueTodayProvider(drill)).value;
    final Widget line;
    if (!ready) {
      line = const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Flexible(child: Text(Strings.homePreparingContent)),
        ],
      );
    } else {
      line = Text(
        due == null
            ? ''
            : due > 0
            ? Strings.homeDueCount(n: due)
            : Strings.homeDueNone,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ready
            ? () => unawaited(context.push(Routes.drill(drill)))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nameOf(drill), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium,
                child: line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
