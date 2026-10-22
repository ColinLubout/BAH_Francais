import 'dart:math';

import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/drills/data/drift_drill_store.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/drill_store.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drill_providers.g.dart';

/// Where drill sessions read and save. Tests use a fake.
@Riverpod(keepAlive: true)
DrillStore drillStore(Ref ref) =>
    DriftDrillStore(ref.watch(appDatabaseProvider));

/// FSRS, at the default target retention until the Réglages screen
/// (milestone 6).
@Riverpod(keepAlive: true)
DrillScheduler drillScheduler(Ref ref) => DrillScheduler();

/// The randomness drills use: which new card, which image, which example.
/// Tests make it predictable.
@Riverpod(keepAlive: true)
double Function() drillRandom(Ref ref) => Random().nextDouble;

/// A drill's display settings. At their defaults until the drill settings
/// screens (milestone 6).
@immutable
class DrillDisplaySettings {
  const DrillDisplaySettings({
    this.articleMandatory = false,
    this.liveFeedback = true,
  });

  /// *Article obligatoire* (Vocabulaire), off by default.
  final bool articleMandatory;

  /// *Correction en direct*, on by default.
  final bool liveFeedback;
}

@Riverpod(keepAlive: true)
DrillDisplaySettings drillDisplaySettings(Ref ref, DrillType drill) =>
    const DrillDisplaySettings();

/// How many of [drill]'s cards are due today, as Accueil shows it under the
/// drill's tile. Once the content is ready.
@riverpod
Future<int> dueToday(Ref ref, DrillType drill) async {
  await ref.watch(contentReadyProvider.future);
  final clock = ref.watch(clockProvider);
  final queue = await DrillSession.queueFor(
    drill,
    store: ref.watch(drillStoreProvider),
    clock: clock,
    scheduler: ref.watch(drillSchedulerProvider),
    random: ref.watch(drillRandomProvider),
  );
  return queue.dueToday(clock);
}
