import 'package:bah_francais/app/shell.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/presentation/drill_screen.dart';
import 'package:bah_francais/features/drills/presentation/session_summary_screen.dart';
import 'package:bah_francais/features/home/presentation/home_screen.dart';
import 'package:bah_francais/features/settings/presentation/settings_screen.dart';
import 'package:bah_francais/features/stats/presentation/stats_screen.dart';
import 'package:bah_francais/features/verbs/presentation/verbs_screen.dart';
import 'package:bah_francais/features/words/presentation/words_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// Paths of the screens reached from the bottom navigation bar, in bar order.
abstract final class Routes {
  static const home = '/';
  static const words = '/words';
  static const verbs = '/verbs';
  static const stats = '/stats';
  static const settings = '/settings';

  /// A drill, full screen, outside the navigation bar; a mixed session when
  /// [drill] is null.
  static String drill(DrillType? drill) => '/drill/${drill?.name ?? _mixed}';

  /// The drill's session summary, over the drill.
  static String drillSummary(DrillType? drill) =>
      '${Routes.drill(drill)}/summary';

  static const _mixed = 'mixed';
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.words,
                builder: (context, state) => const WordsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.verbs,
                builder: (context, state) => const VerbsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/drill/:drill',
        builder: (context, state) => DrillScreen(drill: _drillOf(state)),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) =>
                SessionSummaryScreen(drill: _drillOf(state)),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// The drill in the path; null for a mixed session.
DrillType? _drillOf(GoRouterState state) =>
    switch (state.pathParameters['drill']!) {
      Routes._mixed => null,
      final name => DrillType.values.byName(name),
    };
