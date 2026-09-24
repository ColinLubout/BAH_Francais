# Progress

## Current milestone: 0 — Project setup

**Status:** merged (PR #1). Two follow-ups from the owner's answers are on branch
`milestone-0-followups`: the navigation label *Stats* and no gradient on the Welcome
screen.

### Done

- Flutter project for iOS and Android: `com.bahfrancais.app`, display name
  *BAH Français*, iOS 15+, Android API 26+, portrait only, iPhone-only on iOS.
- Feature-first folders (`lib/app`, `lib/core`, `lib/features/<feature>/presentation`).
- Riverpod with code generation (the router and database providers), go_router with a
  five-branch shell route, and Drift with an empty database.
- Lints: very_good_analysis.
- CI in GitHub Actions:
  - checks: strings up to date, format, analyze, tests with coverage to Codecov;
  - builds: debug Android APK, unsigned iOS.
- Theme:
  - brand colours and exact overrides on `ColorScheme.fromSeed`;
  - feedback colours as a `ThemeExtension`;
  - Poppins Light/Regular/Bold, bundled, with their licence on the licence page;
  - plain white (light) or navy (dark) background.
- Strings generator `tool/gen_strings.dart`: it produces `Strings` and `WelcomeStrings`
  in `lib/core/strings.g.dart`, supports plurals and rejects invalid files.
- App icon and launch screen, from **placeholder** images (see `assets/branding/README.md`).
- The app launches to an empty Accueil with the bottom navigation bar, in light and
  dark. This was checked on the Pixel 8 emulator (Android 14) and in widget tests.
- Tests: 98, all passing. They cover the strings generator (including every rejection
  case), the generated strings, the theme (colours, weights, contrast pairs), the
  database and the app shell (both themes, navigation, screen-reader labels, French
  Material text, 1.5× and 2× text, tablet width).

### Left for the owner

- Add the Codecov upload token as the GitHub Actions secret `CODECOV_TOKEN`, if not
  done yet.
- Turn on branch protection for `main`, requiring the three CI jobs, if not done yet.
- Supply the real logo and app icon (files and sizes in `assets/branding/README.md`).

### Spotted for later milestones

- M3: `drill.leaveSession` ("Terminer la session ?") implies a confirmation dialog, but
  the spec says × goes straight to the summary.
- M4: the selected gender tile puts a yellow symbol on teal, which measures 1.28:1,
  under the 3:1 minimum for meaningful graphics.
- M5: form validation errors use Material's red, but the spec keeps red for wrong
  answers only.
- M6: `drillSettings.title` ("Réglages – {drill}") doesn't match the spec's
  *Réglages de l'exercice*.

## Decisions

These change or add to `docs/SPEC.md`. They are for the owner to fold into the spec
document.

### 2026-09-23 (milestone 0, agreed with the owner)

1. **Light theme background: plain white, no gradient.** It matches the dark theme's
   plain navy.
   - *Replaces* Color scheme → "white background with a soft teal-to-white gradient
     behind the top of the screen".
2. **Launch screen: no gradient.**
   - The logo sits on a plain background: white in light mode, navy #14334C in dark
     mode.
   - On iOS and Android 8–12, it follows the phone's light/dark setting from the first
     launch. That's the platform limit: the OS draws the launch screen before the app
     runs, so only Android 13+ can follow a setting inside the app.
   - On Android 13+, it will also follow an explicit Clair/Sombre choice, built in
     milestone 6 with the Thème setting.
   - On Android 12+, the system crops the launch image to a circle, so it shows the
     character alone.
   - *Replaces* Logo, icon and splash → "the logo centred on the teal-to-blue gradient".
3. ~~**Welcome gradient:** top-left to bottom-right, teal #6EC9C8 to blue #5172A1.~~
   *Superseded on 2026-09-24:* the Welcome screen has no gradient (decision 18).
4. **Placeholders until the real assets arrive:** the app icon and launch logo are a
   plain teal square.
5. **Poppins** comes from Google Fonts' repository (google/fonts), with its SIL OFL
   licence bundled and listed on the licence page.
6. **Accueil in milestone 0** includes the bottom navigation bar, with its other four
   screens blank.
   - Icons (the spec names none): `home`, `menu_book`, `edit_note`, `bar_chart`,
     `settings`, outlined when not selected.
   - No top app bar.
   - The bar's selection indicator is teal with a navy icon: teal is "filled
     indicators" in the spec.
7. **Theme details:**
   - Text is navy on light and white on dark; text on #8FB0DB is navy (5.9:1).
   - Dark-theme bars and cards are slightly lighter shades of navy.
   - Poppins weights by text role:
     - Light 300: display and large headline roles (all ≥ 28 sp), and the main button
       label at 22 sp.
     - Bold 700: `titleMedium` (the result word).
     - Regular 400: everything else.
   - A theme-level emphasis style supplies the bold word inside example sentences, so
     widgets never set a weight.
8. **Drift is set up in milestone 0**, as an empty database with a provider. The spec
   lists Drift under milestone 2. The first real schema, in milestone 2, is still
   version 1, since nothing is released in between.
9. **Material's built-in text is in French.** `flutter_localizations` with the locale
   locked to `fr`, and iOS development region `fr`. This isn't gen-l10n.
10. **Strings generator:**
    - **Plurals** are two keys, `key_one` and `key_other`, chosen by `{n}`. French
      uses `_one` for 0 and 1; English for 1 only. The two forms must use the same
      placeholders apart from `{n}`.
    - **"Placeholders match usage"** is enforced this way: each key becomes a typed
      method, so a wrong or missing argument, or a renamed key, fails at compile time.
      The generator itself rejects unknown placeholders, broken braces, empty text,
      non-text values, badly named keys, Dart reserved words and duplicate names.
    - **Placeholder types:** `n` and `version` are `int`; `date`, `size`, `drill`,
      `answer` and `word` are `String`, pre-formatted by the caller.
    - **Names** join the key path in lowerCamelCase (`home.dueCount` becomes
      `Strings.homeDueCount`). Keys starting with `_` are skipped.
11. **The English strings test** checks that every key in
    `strings_en_welcome.json` is used by the Welcome screen. It ships with that screen
    in milestone 6.
    - *Clarifies* Tech Stack → Strings: "every key in the English file has an
      equivalent screen in the app".
12. **CI runs on every pull request and every push to `main`**, and can be started by
    hand.
    - *Narrows* "every push/PR": a push to a branch with no PR yet doesn't run CI,
      because running on both would build every PR commit twice.
    - Flutter is pinned to 3.47.2.
    - Codecov checks are informational until the domain layer exists (milestone 1),
      when the ≥ 90% domain target starts being enforced.
13. **Repo files:** LICENSE (MIT, Colin Lubout) and README now; CONTRIBUTING, issue
    templates and CHANGELOG in milestone 8.
14. **Tablets:**
    - iOS builds for iPhone only; iPads run it in phone-compatibility mode.
    - On Android tablets the layout stays in a centred column 480 dp wide.
15. **Code conventions:**
    - `build_runner` output is not committed, but `strings.g.dart` is: the spec
      requires CI to diff it.
    - very_good_analysis runs with two rules off: `public_member_api_docs` (this is an
      app, not a library) and `unnecessary_type_name_in_constructor`. The second keeps
      the familiar `const HomeScreen({super.key})` rather than Dart 3.13's
      `const new(...)`.
    - The Dart package is `bah_francais`.
16. **Edge to edge on every Android version:** status and navigation bars are
    transparent, with icons that follow the theme. Android 15+ requires this anyway.
17. **`.gitignore` replaced** with Flutter's app template. The one the repo started
    with was the Flutter framework's own, which ignores `pubspec.lock`.

### 2026-09-24 (milestone 0 follow-ups, agreed with the owner)

18. **No gradients anywhere.** The Welcome screen has the same plain background as
    every other screen: white in light mode, navy in dark mode.
    - *Replaces* Logo, icon and splash → "with the same gradient behind the Welcome
      screen". Together with decisions 1 and 2, the Layouts gradients are no longer
      used.
19. **The navigation bar says *Stats*** (`navigation.stats`), because *Statistiques*
    broke mid-word on narrow phones and at larger text sizes. The screen's own title
    stays *Statistiques* (`stats.title`).

### Notes

- `build_runner` 2.16 no longer has `--delete-conflicting-outputs`. The CLAUDE.md
  command still works (the flag is ignored with a warning), but it could drop the flag.
