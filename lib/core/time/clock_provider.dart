import 'package:bah_francais/core/time/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// The clock everything reads the time from. Tests override it with a fake.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();
