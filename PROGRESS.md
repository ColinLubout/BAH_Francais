# Progress

## Current milestone: 1 — Domain core

**Status:** built on branch `milestone-1`, waiting for the owner's review. The branch
starts from `milestone-0-followups`, so merge that PR first. Milestone 2 doesn't start
until this is merged.

### Done

- **FSRS:** a port of the py-fsrs 6.3.2 scheduler (`lib/features/drills/domain/fsrs/`),
  checked against py-fsrs's own reference tests.
  - This includes its exact interval history and memory-state values, and its seeded
    fuzz cases. Python's random generator is reproduced in the tests so these match
    exactly.
  - Its MIT licence is credited on the licence page.
- **Scheduling** (`scheduling.dart`):
  - one FSRS scheduler per drill, with its own parameter set, and a shared target
    retention (80–97%, default 90%);
  - review outcomes carrying what the review log records;
  - reps, lapses, the Again count and leeches;
  - regrading for the override buttons.
- **Card model** (`card.dart`): the spec's four states, known/unknown, and conversion to
  and from FSRS.
- **Grading** (`grading/`):
  - normalisation, accent folding (œ and æ included) and the highlighted characters;
  - the Gender, Vocabulaire and Conjugaison rules, with articles, synonyms and
    alternatives;
  - the red-or-orange typing cap;
  - *Faute de frappe*, *Trop facile* and *Je ne sais pas*.
- **Queue** (`queue/`):
  - learning steps, then due reviews with the lowest retrievability first, then new
    cards at about 1 per 4 reviews, then free practice;
  - the daily new-card and review limits, and *goal reached*;
  - weighted category draws and the order of new cards;
  - known, retired, Jamais and paused tense or verb group exclusions;
  - Accueil's due count.
- **Mastery levels** (`mastery.dart`).
- **Clock:** an injectable `Clock` (UTC now plus the current UTC offset), a Riverpod
  `clockProvider`, and `StudyDay` for the 04:00 boundary.
- **CI:** a domain coverage gate (`tool/check_domain_coverage.dart`, at least 90%), and
  a domain component in Codecov.
- **Purity test:** `test/domain_purity_test.dart` fails if any domain file imports
  Flutter, `dart:ui`, `dart:io`, networking or the database.
- **Tests:** 322, all passing. Domain coverage is 99.2%.

**The Spaced Repetition acceptance criteria and their tests:**

| Criterion | Tests |
| --- | --- |
| Each rating from each card state | `scheduling_test.dart`: each rating from each state |
| Early and late reviews | `scheduling_test.dart`: early and late reviews |
| The 04:00 day boundary | `study_day_test.dart`; `session_queue_test.dart`: due until 04:00, new-card limit resets at 04:00 |
| Daily new-card limit | `session_queue_test.dart`: new cards |
| Leech flagging | `scheduling_test.dart`: leeches |
| Time-zone change, daylight saving, clock going back | `study_day_test.dart` and `session_queue_test.dart`: clock and time zone |
| Grading: exact, accents, wrong article, alternatives, apostrophes, red-letter cap | `grading_test.dart`, `normalise_test.dart` |
| All scheduling works offline | `domain_purity_test.dart`: the domain can't reach the network |
| Force-closing mid-session loses no answered card | Milestone 3. It needs the database (M2) and the drill screen (M3), and the build plan puts it in M3. |
| All user-facing text in French except Welcome | The strings generator (M0) and each screen's widget tests |

### Left for the owner

- Merge `milestone-0-followups` (the *Stats* label and no Welcome gradient), then push
  `milestone-1` and open its PR.
- Add the Codecov upload token as the GitHub Actions secret `CODECOV_TOKEN`, if not
  done yet.
- Turn on branch protection for `main`, requiring the three CI jobs, if not done yet.
- Supply the real logo and app icon (files and sizes in `assets/branding/README.md`).
- Answer the open questions below before milestone 3.

### Open questions

1. **Wording for the goal-reached message.** When the daily review limit is reached,
   the drill tells the user they've reached today's goal and to take a break until
   tomorrow (decision 27). It needs a new key in `strings_fr.json`, for example
   `drill.dailyGoalReached`, with French you write. It's needed for milestone 3.
2. **The result word for an exact answer capped at Hard.** An exactly right answer
   graded Hard because a letter went red or orange while typing: does the feedback
   panel say *Correct* or *Presque*? Grading gives Hard with no error, and the panel
   (milestone 3) needs the word.
3. **Synonyms with a different gender.** A synonym is taken to share its noun's gender
   and elision: *une voiture* / *une auto*, *l’* for both or neither. If content ever
   needs a synonym of another gender, the content model needs a way to say so. This
   is for milestone 2.

### Spotted for later milestones

- M3: `drill.leaveSession` ("Terminer la session ?") implies a confirmation dialog, but
  the spec says × goes straight to the summary.
- M4: the selected gender tile puts a yellow symbol on teal, which measures 1.28:1,
  under the 3:1 minimum for meaningful graphics.
- M5: form validation errors use Material's red, but the spec keeps red for wrong
  answers only.
- M6: `drillSettings.title` ("Réglages – {drill}") doesn't match the spec's
  *Réglages de l'exercice*.

## Milestone 0 — Project setup (merged, PR #1)

- The Flutter app for iOS and Android.
- Feature-first folders, Riverpod, go_router and an empty Drift database.
- Lints and CI.
- The theme: brand colours, feedback colours and Poppins.
- The strings generator.
- A placeholder app icon and launch screen.
- An empty Accueil with the bottom navigation bar, in both themes.
- Follow-ups on `milestone-0-followups`: the navigation label *Stats*, and no gradient
  on the Welcome screen.

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

### 2026-09-24 (milestone 1, agreed with the owner)

**Scheduling**

20. **FSRS is a port of py-fsrs 6.3.2, not the `fsrs` package.** The package's latest
    release (2.0.1, June 2025) is out of date in two ways:
    - it has the old default parameters; for example, the first interval after Easy
      is 16.2 days there against 8.3 now;
    - it lacks py-fsrs's fix for a same-day Hard lowering stability, which matters
      here because every accent slip is graded Hard.

    Only the scheduler is ported. It's verified against py-fsrs's own tests, and its
    MIT licence is on the licence page.
    - *Applies* the spec's rule: "if that package is unavailable or out of date, port
      the reference implementation".
21. **A review card is due for its whole study day**, until the next 04:00: it's
    served, and counted on Accueil, from the start of that day. Learning and
    relearning steps come up only once their minute has passed.
22. **Every review stores the study day it was given on** (`study_day`, `yyyymmdd`,
    a new ReviewLog column in M2). Today's new-card count is counted by that stored
    day, so a clock, time-zone or daylight-saving change never moves past reviews to
    another day.
23. **Leeches count every Again that stands**: those from learning steps and *Je ne
    sais pas* count, and answers overridden by *Faute de frappe* don't. That differs
    from FSRS's lapses, which count only failed reviews, so cards get an
    `again_count` column (M2). The leech flag is permanent.
24. **The card's data-model additions for M2:**
    - `step`, the learning or relearning step FSRS needs;
    - `again_count`;
    - the state stored as `new` / `learning` / `review` / `relearning`;
    - in the review log, `elapsed_days` is null for a card's first review, and
      `scheduled_days` is the interval that review set (0 for a step).

**Grading**

25. **Red or orange letters cap the grade at Hard.** The spec says "red" under Grading
    and "red or orange" under Typing behaviour; the second applies.
26. **The override buttons:**
    - *Faute de frappe* follows an *Incorrect* answer, including a mis-tap in the
      Gender drill, but not *Presque* (already Hard) or *Je ne sais pas*.
    - *Trop facile* follows a *Correct* answer only, and never in the Gender drill,
      which moves on after a second.
    - An override replaces the answer already saved, while its feedback panel is
      open: the card is scheduled again from its state before that answer, and the
      review-log row is updated.
27. **The daily review limit** (*Révisions max par jour*):
    - Once it's reached, due reviews wait until tomorrow.
    - Learning steps and new cards (within the new-card limit) carry on.
    - When those run out, the drill tells the user they've reached today's goal and
      to take a break until tomorrow, instead of offering free practice.
    - Only answers to cards in the review state count towards the limit.
    - Accueil's due count shows at most what the limit leaves.
    - The French wording is open question 1.
28. **Articles in the Vocabulaire drill:**
    - Singular nouns take *le/la/un/une* by gender, either gender for a "les deux"
      noun. Plural-only nouns take *les/des*.
    - With Article obligatoire off, *l’* is right for a noun that takes it. With it
      on, only *un/une* is accepted for such a noun, as the spec says.
    - A wrong article together with an accent slip is Hard, logged as `article`.
    - *oe* typed for *œ* counts as an accent slip.
    - Synonyms share the noun's gender and elision (open question 3).
29. **Normalisation also** collapses repeated spaces and ignores a space typed after an
    apostrophe: *j’ aime* counts as *j’aime*.
30. **Gender drill:** answering *masculin* for a "les deux" noun is simply wrong.

**The queue**

31. **Free practice** offers learning cards waiting for their step first, soonest
    first. Then come early reviews, closest to forgetting first.
32. **When the review limit is reached**, learning cards waiting for their step are
    shown early before the goal-reached message.
33. **The same card is never shown twice in a row** while another card could be.
34. **Nouns in several categories:** a category is drawn with probability in
    proportion to its weight, among those that still have new cards, and its next new
    card is taken.
    - A noun can come through any of its categories not set to Jamais.
    - The spec's "a noun's weight is the highest of its categories" only matters for
      Jamais: its cards pause only when every one of its categories is Jamais.
35. **Order of new cards within a category:**
    - Perso words come first, oldest first.
    - Official items then come by level, then frequency rank. Conjugation cards go by
      level, then tense (présent → passé composé → imparfait → futur simple), then
      rank.
    - *Perso* is a category like any other, with its own weight in each drill.
36. **Turning off a tense or a verb group** in Conjugaison's settings pauses those
    cards entirely, reviews included, as Jamais does.
37. **Mastery:** a card reset to New by a content update shows *Nouveau*. A stability
    of exactly 7 or exactly 90 days counts as *Acquis*.

### Notes

- `build_runner` 2.16 no longer has `--delete-conflicting-outputs`. The CLAUDE.md
  command still works (the flag is ignored with a warning), but it could drop the flag.
