import 'package:bah_francais/app/router.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/presentation/drill_controller.dart';
import 'package:bah_francais/features/drills/presentation/drill_name.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// *Résumé de session*: cards answered, % correct and duration, and in a
/// mixed session the same three numbers for each drill underneath; no
/// praise, animation or comparison. *Continuer* goes back into the same
/// session, as the back gesture does; *Terminer* to Accueil.
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.drill, super.key});

  /// The drill; null for a mixed session.
  final DrillType? drill;

  /// Under a minute in seconds, then in whole minutes.
  static String duration(Duration d) => d.inSeconds < 60
      ? Strings.commonSeconds(n: d.inSeconds)
      : Strings.commonMinutes(n: (d.inSeconds / 60).round());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the session keeps it open while the summary shows.
    ref.watch(drillControllerProvider(drill));
    final summary = ref.read(drillControllerProvider(drill).notifier).summary;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.sessionSummaryTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _Numbers(summary),
                    for (final MapEntry(key: drill, value: numbers)
                        in summary.byDrill.entries) ...[
                      const SizedBox(height: 16),
                      Text(
                        drillName(drill),
                        style: theme.textTheme.titleMedium,
                      ),
                      _Numbers(numbers),
                    ],
                  ],
                ),
              ),
              FilledButton(
                onPressed: context.pop,
                child: const Text(Strings.sessionSummaryResume),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ref.invalidate(dueTodayProvider);
                  context.go(Routes.home);
                },
                child: const Text(Strings.sessionSummaryFinish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cards answered, % correct and duration.
class _Numbers extends StatelessWidget {
  const _Numbers(this.summary);

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
    return Column(
      children: [
        row(Strings.sessionSummaryCardsAnswered, '${summary.answered}'),
        row(
          Strings.sessionSummaryAccuracy,
          Strings.sessionSummaryPercent(n: summary.percentCorrect),
        ),
        row(
          Strings.sessionSummaryDuration,
          SessionSummaryScreen.duration(summary.duration),
        ),
      ],
    );
  }
}
