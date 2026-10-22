import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/app/licences.dart';
import 'package:bah_francais/app/phone_layout.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/app_theme.dart';
import 'package:bah_francais/core/theme/brand_colors.dart';
import 'package:bah_francais/features/home/presentation/home_screen.dart';
import 'package:bah_francais/features/settings/presentation/settings_screen.dart';
import 'package:bah_francais/features/stats/presentation/stats_screen.dart';
import 'package:bah_francais/features/verbs/presentation/verbs_screen.dart';
import 'package:bah_francais/features/words/presentation/words_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_overrides.dart';
import '../helpers/fake_clock.dart';
import '../helpers/fake_drill_store.dart';

/// Pumps the app on a small phone screen (360 × 640).
Future<void> pumpApp(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 640),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: drillOverrides(
        store: FakeStore(cards: const []),
        clock: FakeClock(DateTime.utc(2026, 10, 22, 10)),
      ),
      child: const BahApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const Map<String, Type> destinations = {
  Strings.navigationHome: HomeScreen,
  Strings.navigationWords: WordsScreen,
  Strings.navigationVerbs: VerbsScreen,
  Strings.navigationStats: StatsScreen,
  Strings.navigationSettings: SettingsScreen,
};

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('launches to Accueil in the ${brightness.name} theme', (
      tester,
    ) async {
      await pumpApp(tester, brightness: brightness);

      expect(find.byType(HomeScreen), findsOneWidget);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);

      final theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(theme.brightness, brightness);
      expect(
        theme.colorScheme.surface,
        brightness == Brightness.dark ? BrandColors.navy : BrandColors.white,
      );
    });
  }

  testWidgets('the bar shows the five destinations in order', (tester) async {
    await pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations.cast<NavigationDestination>().map(
      (d) => d.label,
    );
    expect(labels, destinations.keys);
  });

  testWidgets('each destination opens its screen', (tester) async {
    await pumpApp(tester);

    for (final MapEntry(key: label, value: screen) in destinations.entries) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: label);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.selectedIndex,
        destinations.keys.toList().indexOf(label),
        reason: label,
      );
    }
  });

  testWidgets('destinations have screen-reader labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);

    for (final label in destinations.keys) {
      expect(
        find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')),
        findsOneWidget,
        reason: label,
      );
    }
    semantics.dispose();
  });

  testWidgets('Material text is in French', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), BahApp.locale);
    expect(
      MaterialLocalizations.of(context),
      isNot(isA<DefaultMaterialLocalizations>()),
    );
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('lays out without overflow at ${scale}x text size', (
      tester,
    ) async {
      await pumpApp(tester, textScale: scale);

      expect(tester.takeException(), isNull);
      expect(find.text(Strings.navigationSettings), findsOneWidget);
    });
  }

  testWidgets('keeps a centred phone-width column on a wide screen', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1000, 800));

    final bar = tester.getRect(find.byType(NavigationBar));
    expect(bar.width, PhoneLayout.maxWidth);
    expect(bar.left, (1000 - PhoneLayout.maxWidth) / 2);
  });

  test('system bars are transparent, with icons that read on the theme', () {
    const clear = Color(0x00000000);
    for (final (brightness, icons) in [
      (Brightness.light, Brightness.dark),
      (Brightness.dark, Brightness.light),
    ]) {
      final style = PhoneLayout.systemBarsStyle(brightness);
      expect(style.statusBarColor, clear);
      expect(style.systemNavigationBarColor, clear);
      expect(style.statusBarIconBrightness, icons);
      expect(style.systemNavigationBarIconBrightness, icons);
      expect(style.statusBarBrightness, brightness);
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    }
  });

  test('Poppins and py-fsrs are on the licence page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerLicences();

    final entries = await LicenseRegistry.licenses.toList();
    for (final package in [AppTheme.fontFamily, 'py-fsrs']) {
      final matching = entries.where((e) => e.packages.contains(package));
      expect(matching, hasLength(1), reason: package);
      expect(matching.single.paragraphs, isNotEmpty, reason: package);
    }
  });
}
