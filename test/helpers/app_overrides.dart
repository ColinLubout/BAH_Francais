import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/drills/domain/scheduling.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:flutter_riverpod/misc.dart';

import 'fake_clock.dart';
import 'fake_drill_store.dart';

/// The app with its content ready and its drills over [store], at
/// [clock]'s time, with randomness fixed at [random]: no database, no
/// import, nothing left running for a widget test to wait on.
///
/// Pass [content] to control when the content is ready, as an import still
/// running.
List<Override> drillOverrides({
  required FakeStore store,
  required FakeClock clock,
  double random = 0,
  Future<ContentInfo>? content,
}) => [
  contentReadyProvider.overrideWith(
    (ref) =>
        content ??
        Future.value(const ContentInfo(version: 1, releasedAt: '2026-10-22')),
  ),
  drillStoreProvider.overrideWithValue(store),
  clockProvider.overrideWithValue(clock),
  drillRandomProvider.overrideWithValue(() => random),
  drillSchedulerProvider.overrideWithValue(DrillScheduler(random: () => 0.5)),
];
