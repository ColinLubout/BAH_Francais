import 'dart:async';

import 'package:bah_francais/app/router.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/presentation/drill_name.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Accueil: the home screen, where a session starts: one large *Commencer*
/// button for a mixed session, and under it a tile per drill. Its ⋮ menus
/// and *Liste de révision* link come with their screens in milestone 6
/// (decision 79).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(contentReadyProvider).hasValue;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton(
              onPressed: ready
                  ? () => unawaited(context.push(Routes.drill(null)))
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: const Text(Strings.homeStart),
            ),
            const SizedBox(height: 16),
            for (final drill in DrillType.values) DrillTile(drill: drill),
          ],
        ),
      ),
    );
  }
}

/// A drill's tile: its name, and under it how many cards are due today.
/// Disabled while the content is being prepared on the first launch.
class DrillTile extends ConsumerWidget {
  const DrillTile({required this.drill, super.key});

  final DrillType drill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ready = ref.watch(contentReadyProvider).hasValue;
    final due = ref.watch(dueTodayProvider(drill)).value;
    // Nothing due: no line at all (decision 76).
    final line = !ready
        ? const Row(
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Flexible(child: Text(Strings.homePreparingContent)),
            ],
          )
        : due != null && due > 0
        ? Text(Strings.homeDueCount(n: due))
        : null;
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
              Text(drillName(drill), style: theme.textTheme.titleLarge),
              if (line != null) ...[
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium,
                  child: line,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
