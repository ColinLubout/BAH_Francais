import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drill_controller.g.dart';

/// The session of [drill] on screen. It lives while its drill screen or
/// summary is open, and a new one starts each time the drill is opened.
@riverpod
class DrillController extends _$DrillController {
  late DrillSession _session;

  /// An action is running: taps arriving meanwhile are ignored, so a double
  /// tap never answers twice.
  bool _busy = false;

  @override
  Future<DrillView> build(DrillType drill) async {
    await ref.watch(contentReadyProvider.future);
    _session = await DrillSession.open(
      drill: drill,
      store: ref.read(drillStoreProvider),
      clock: ref.read(clockProvider),
      scheduler: ref.read(drillSchedulerProvider),
      random: ref.read(drillRandomProvider),
      articleMandatory: ref
          .read(drillDisplaySettingsProvider(drill))
          .articleMandatory,
    );
    return await _session.next();
  }

  /// The numbers the summary shows.
  SessionSummary get summary => _session.summary;

  /// Grades [typed]: [capsGrade] when a letter went red or orange.
  Future<void> submit(String typed, {required bool capsGrade}) =>
      _run(() => _session.submit(typed, capsGrade: capsGrade));

  /// *Je ne sais pas*.
  Future<void> giveUp() => _run(_session.giveUp);

  /// *Faute de frappe* or *Trop facile*.
  Future<void> overrideGrade() => _run(_session.overrideGrade);

  /// *Suivant*.
  Future<void> next() => _run(_session.next);

  /// *Je le connais*: returns the mark for *Annuler*, or null if another
  /// action was running.
  Future<KnownMark?> markKnown() async {
    if (_busy) return null;
    _busy = true;
    try {
      final (mark, view) = await _session.markKnown();
      state = AsyncData(view);
      return mark;
    } finally {
      _busy = false;
    }
  }

  /// *Annuler* after *Je le connais*.
  Future<void> undoKnown(KnownMark mark) => _session.undoKnown(mark);

  Future<void> _run(Future<DrillView> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      state = AsyncData(await action());
    } finally {
      _busy = false;
    }
  }
}
