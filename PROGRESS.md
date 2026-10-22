# Progress

## Current milestone: 2 — Data layer

**Status:** built on branch `milestone-2`, waiting for the owner's review. The branch
starts from `milestone-1-followups`, so merge that PR first. Milestone 3 doesn't start
until this is merged.

### Done

- **Tables** (Drift, schema version 1): the content tables of Content → Content
  model, each with `source` and `retired`; Image; Card, ReviewLog and Session;
  CategoryWeight; ContentMeta.
  - Sentences are their own table, linked to the verbs they are prompts for and
    the nouns they are examples of (decision 59).
  - Times are stored in UTC, as microseconds, so they read back exactly. Enums are
    stored by their ids (`passe_compose`, `new`).
  - Foreign keys are on. A card's review-log rows go with it (decision 51).
  - Drift's modular code generation, so the app database and the content pack share
    the same table code.
- **Data access, with streams:**
  - `ContentStore`: content and its version, in the app's database or a pack;
    categories, everyday categories, an item's images.
  - `CardsDao`: cards and queue cards; an answer saved with its review-log row and
    session counts in one transaction; overrides replacing that row; known marks;
    the day's counts from the review log.
  - `SessionsDao` and `CategoryWeightsDao`.
- **Import** of a content pack into an empty database (`ContentImporter`): read-only,
  in one transaction, with New cards for every noun, and for every verb in each tense
  the pack teaches (decision 62). It refuses a missing file, a file that isn't a
  pack, and a pack needing a newer app, and leaves nothing behind when it fails.
- **The tenses taught** (decision 62): `content/tenses.json` lists them; the validator
  asks for sentences in those tenses only, the pack records them, and the importer
  creates Conjugaison cards for them only. The sample teaches all four, so the tests
  keep covering every tense.
- **Migrations:** schema version 1 dumped in `drift_schemas/`, a test that the tables
  match it, and `make-migrations` set up for the next versions.
- **Content tool** (`tool/content_build.dart`): a JSON Schema per kind of file in
  `content/schema/`, the validator (the schema, then every rule beyond it), and the
  pack builder. CI runs it on the content and the sample on every PR.
- **Dictionary check** (`tool/dictionary_check.dart`, decision 60): compares the
  content with Wiktionary through Kaikki.org's French data, kept in `data/kaikki/`
  and out of git. Both the everyday draft and the sample agree with it on every
  gender, plural-only noun, auxiliary and conjugated form. It also checks the words of
  the sentences (decision 64): it flags a noun or verb the content doesn't have, a
  form in a tense it doesn't teach, and an infinitive straight after a conjugated
  verb. The everyday sentences pass.
- **Grammar levels** (`tool/grammar_tag.dart`, decision 65): the grammar concepts and
  their CEFR levels in `content/grammar.json`, a detection that tags each sentence
  with the concepts it uses, and validator rules for the tags and the content's
  highest level.
- **Conjugation prompts** (`sentence_prompt.dart`): a sentence with its verb blanked
  and an elided word before it written in full (*J’habite* → *Je ___*), shared by
  the validator and, later, the Conjugaison drill.
- **Everyday content, a draft to check** (`content/`, decisions 57 and 62): the
  present only; *Les essentiels*, 10 nouns with definitions, and *Les verbes
  essentiels*, 6 verbs with all 24 forms; 69 sentences.
  - The owner checks it on a review page (a private claude.ai artifact) that shows
    each item with its English meaning and saves their marks.
  - 2026-10-21: the owner checked the nouns and verbs. 38 were right; *eau* and
    *nuit* got new definitions (and *nuit* a new example) from their notes.
  - 2026-10-21: the sentences came from Tatoeba (decision 61).
  - 2026-10-22: the owner cut the scope to the present, 6 verbs and 10 nouns
    (decision 62), and found the Tatoeba sentences unnatural: 70% had been
    translated from English. The sentences became Tatoeba's written in French and
    using only the content's nouns and verbs (decision 64). The 7 nouns and 5 verbs
    kept are unchanged, so their marks stand; *chat*, *chien*, *voiture* and
    *finir* are new, and agree with Wiktionary.
  - 2026-10-22: from the owner's review, sentences carry their grammar concepts
    and level, and are A1 only (decision 65). 72 sentences: 45 from Tatoeba, 11 of
    the owner's own wordings, 16 drafted; two or more for each verb and person and
    each noun. The review page has a Grammar tab, and notes on the marked
    sentences say what changed.
- **Sample set** (`content/sample/`): 3 noun categories of 10 nouns, 5 verbs with
  all 24 forms, 151 sentences and 6 placeholder SVGs. Marked as samples; it never
  ships.
- **Tests:** 562, all passing. Domain coverage is 99.4%; the DAOs, the content store,
  the converters and the prompt logic are fully covered.

**The milestone's "done when" and its tests:**

| Check | Tests |
| --- | --- |
| The sample pack builds, imports and reads back unchanged | `sample_pack_test.dart` |
| The validator rejects each rule it enforces, with a test per rule | `content_validator_test.dart` (schema and rules), `svg_rules_test.dart` (SVG rules) |

### Left for the owner

- Review and merge the `milestone-1-followups` PR, then the `milestone-2` PR.
- Check the everyday content in `content/` (decisions 57, 62 and 65): the new nouns
  (*chat*, *chien*, *voiture*) and verb (*finir*), the 72 sentences, and the
  grammar concepts' levels in `grammar.json`.
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

### Spotted for later milestones

- M3: bundle the everyday pack and import it on first launch with
  `ContentImporter` (decision 58).
- M3: `drill.leaveSession` ("Terminer la session ?") implies a confirmation dialog, but
  the spec says × goes straight to the summary.
- M4: the Conjugaison prompt comes from `conjugationPrompt` (decision 59), and the
  word before the blank changes as the user types (decision 43).
- M4: a sentence accepts its own alternatives only. The sample repeats a form's
  alternatives on each of its sentences (*paie* / *paye*); the drill could add them
  by itself.
- M5: *Ajouter une phrase* and the *Phrase d’exemple* of *Ajouter un mot* now store a
  sentence in full with its link (decision 59): the blank the user leaves is
  filled with the answer, eliding the word before it where French does.
- M4: the selected gender tile puts a yellow symbol on teal, which measures 1.28:1,
  under the 3:1 minimum for meaningful graphics.
- M5: compound forms are stored with the masculine singular participle for every
  person, as the spec says (*sommes allé*). The Fiche verbe may need to show them
  differently.
- M5: form validation errors use Material's red, but the spec keeps red for wrong
  answers only.
- M6: the Conjugaison settings' *Temps* lists only the tenses the content teaches
  (decision 62); with the present alone, the setting has nothing to choose.
- M7: a content update that adds a tense creates that tense's Conjugaison cards for
  every verb (decision 62).
- M8 (new, decision 63): when words are added, sentences that already use a new word
  link it. The sentences only use the content's nouns and verbs (decision 64), so
  re-picking them with the new lists does this.
- M6: À propos / Crédits credits Wiktionary (CC BY-SA 4.0) and Kaikki.org /
  wiktextract (decision 60), with French wording from the owner.
- M6: À propos / Crédits credits Tatoeba and its licence, CC BY 2.0 FR (decision 61).
  The licence asks for each author to be credited: the sentences table keeps every
  sentence's Tatoeba number and author, so Crédits can list the authors, or the
  drill can name a sentence's author. Which one is the owner's call.
- M8: picking Tatoeba sentences for the new words and tenses (names allowed outside
  the everyday categories, decision 61). The script that picked the everyday ones
  was a one-off outside the repo; done again, it belongs in `tool/` with its tests.
- M6: `drillSettings.title` ("Réglages – {drill}") doesn't match the spec's
  *Réglages de l'exercice*.
- M6: for the everyday and Perso categories, only Jamais changes anything (decisions
  40 and 41): Moins, Normal and Plus all behave the same. Their weight setting may
  need to be just on or Jamais.

## Milestone 1 follow-ups

On branch `milestone-1-followups`, waiting for the owner's review.

- **Synonyms with their own gender and elision** (decision 42): the Vocabulaire drill
  accepts each synonym with its own articles.
- **The order of new cards** (decisions 40 and 41): the user's own words first, then
  the everyday category, then the topics by their weights.

## Milestone 1 — Domain core (merged, PR #3)

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
- **Tests:** 324, all passing. Domain coverage is 99.5%.

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

## Milestone 0 — Project setup (merged, PR #1)

- The Flutter app for iOS and Android.
- Feature-first folders, Riverpod, go_router and an empty Drift database.
- Lints and CI.
- The theme: brand colours, feedback colours and Poppins.
- The strings generator.
- A placeholder app icon and launch screen.
- An empty Accueil with the bottom navigation bar, in both themes.
- Follow-ups (merged, PR #2): the navigation label *Stats*, and no gradient on the
  Welcome screen.

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

### 2026-10-19 (milestone 1 review, agreed with the owner)

38. **An article is known by the space or apostrophe after it.** In the Vocabulaire
    drill, an answer starting with *le, la, les, un, une* or *des* and a space, or with
    *l’*, always has that article split off before the word is compared. No noun is
    spelled starting with one, so the word is never tried again with the article as
    part of it. Without the space or apostrophe, those letters are part of the word.

### 2026-10-19 (milestone 1 follow-ups, agreed with the owner)

39. **Categories are prioritised with their weights only** (Jamais / Moins / Normal /
    Plus), as the spec says. Users don't reorder categories: a category's
    `sort_order` in the content decides where it is listed.
40. **The everyday category.** The content can mark one noun category and one verb
    category as the everyday set, the universally useful words, with
    `"everyday": true`. The other categories are topics.
    - While a drill's everyday category has new cards, they come before any topic's.
      After that, the topics go by their weights.
    - Setting it to Jamais skips it, and pauses its reviews as Jamais always does.
      Moins and Plus make no difference to it.
    - *Adds to* Category weighting and new-card order.
41. **The user's own words come first** among all new cards, oldest first: before the
    everyday set and the topics, from any of their categories not set to Jamais.
    - *Changes* decision 35, where Perso words came first only within their
      category. The Perso category's weight now only matters for Jamais.
42. **A synonym can have its own gender and elision** (open question 3). The
    Vocabulaire drill accepts each synonym with its own articles: *la voiture*, but
    *l’auto*.
    - In a content file, a synonym is a plain word when it shares the noun's gender
      and elision, and otherwise `{ "word": "auto", "elides": true }`, with
      `"gender"` too when that differs.
    - A plural-only noun's synonyms are plural-only too.
    - *Replaces* decision 28's "synonyms share the noun's gender and elision".

### 2026-10-19 (milestone 2, agreed with the owner)

43. **Conjugation answers and elision:**
    - ~~Sentences write every word before the blank in full: *Je ___ le chocolat*,
      never *J’___*. The validator rejects an apostrophe just before the blank.~~
      *Superseded by decision 59:* sentences are written in plain French, and the
      prompt writes the elided word in full.
    - The answer is only the verb: *aime*, *suis allé*. Typing the subject pronoun
      too (*j’aime*) is wrong. Reflexive verbs keep their pronoun in the answer
      (*me lève*, *m’appelle*), and so do their stored forms.
    - As the user types, the word before the blank adjusts: if what they type starts
      with a vowel or a silent *h*, *je* → *j’*, *me* → *m’*, *te* → *t’*,
      *se* → *s’*, *ne* → *n’*, *le* / *la* → *l’*, *ce* → *c’* (milestone 4).
    - *Replaces* Activities → Conjugation drill → "When je elides, the blank covers
      the subject and the answer includes it (\_\_\_\_ le chocolat → j’aime)".
44. **Words starting with *h*:** a verb with a form starting with *h* states
    `h_aspire` (false for *j’habite*, true for *je hais*), and a noun starting with
    *h* states `elides`. The validator rejects either one missing, so the setting is
    confirmed for each such word, and rejects `h_aspire` on any other verb.
45. **Verb categories** are in `content/verb-categories.json`: id, name, sort order
    and everyday. Noun categories stay in their noun files.
46. **Images in content files:**
    - a noun's SVGs are in `content/images/<noun id without n.>/`;
    - an image's id is `i.` and its file name without `.svg` (`i.fourchette-1`), so
      file names are unique across the content;
    - a noun lists an image by its file name, or as `{ "file": …, "source": … }`
      when it has a credit.
    - *Resolves* the spec's two folder names: `<noun id without n.>` under Content
      files and `<item_id>` under Where content comes from.
47. **Image size:** over 20 KB is a warning, not an error, until the owner sets the
    real limit after drawing some images. "Readable at 160 px" and "legible on light
    and dark" can't be checked by a program, so they are left to whoever reviews the
    artwork.
48. **The Image table** has an `svg` text column and a `bytes` blob column instead
    of one `data` column, since a Drift column has one type. Exactly one is set, to
    match the format. Its `source` column is the credit.
49. ~~**Example sentence ids** are the noun's id and their position:
    `n.fourchette.ex01`. A content update replaces a noun's examples as a set.~~
    *Superseded by decision 59:* examples are sentences, with their own ids.
50. **The sample set** is written by Claude Code, as CLAUDE.md allows for
    `content/sample/` only, and is marked as samples. It has an everyday category of
    each kind.

### 2026-10-19 (milestone 2, proposed by Claude Code, agreed with the owner)

51. **Deleting a word deletes its review-log rows too**, along with its cards. The
    rows go with their card through a foreign key, so every row has its card, and
    the card gives its drill (review logs store no drill of their own).
    - Its answers drop out of Statistiques and of the later FSRS tuning; the totals
      of past sessions still count them.
    - *Replaces* Data model → ReviewLog "(one row per answer, never deleted)" and
      Fiche mot "Deleting a word deletes its cards; its review log rows are kept".
52. **Sessions:** a mixed session's drill type is `mixed`. A session's row is written
    with its first answer, and its end time moves to each answer's time, so a
    session cut short by a force-close still has a duration.
53. **Correct means anything but Again**, for a session's counts and % correct.
    *Presque* (Hard, *Faute de frappe* included) counts as correct, since FSRS counts
    Hard as remembered, which keeps % correct in line with the real retention figures.
54. **Agreement in the validator:** a sentence's answer is its form or one of the
    form's alternatives; in a compound tense, it may also end in an extra *e*, *s* or
    *es* (*allé* → *allées*). Compound forms store the masculine singular participle
    for every person, as the spec says (*sommes allé*).
55. **Ids and names:**
    - ids are lowercase ASCII letters, digits and hyphens after their prefix
      (`n.petit-dejeuner`, `cat.vie-quotidienne`); sentence ids add parts after
      dots (`s.aller.pc.1p.01`); image file names follow the same pattern and end
      in `.svg`. The schemas enforce it, and the image folders depend on it.
    - noun examples and sentences store their text in `example_text` and
      `sentence_text`: a column called `text` breaks Drift's generated migration
      test code.

### 2026-10-19 (milestone 2, agreed with the owner)

56. **A noun is written without its article.** The validator rejects a noun or
    synonym whose word starts with *le, la, les, un, une* or *des* and a space, or
    with *l’* (*"la fourchette"*), since its article comes from its gender. A noun
    is right typed with or without its article, unless Article obligatoire is on.
57. **The everyday categories are part of this milestone, drafted by Claude Code.**
    *Les essentiels* (30 nouns) and *Les verbes essentiels* (10 verbs: être, avoir,
    faire, dire, aller, voir, pouvoir, savoir, vouloir, venir) are in `content/`.
    The owner, or a fluent speaker, checks every word, gender, form and sentence
    before they ship.
    - *Changes* Phase 1 content → "Claude Code does not write the real word list",
      for the everyday categories only; CLAUDE.md says the same.
    - Their `rank` is an estimated order within the set, not a corpus frequency.
    - The nouns have definitions and no images yet.
58. **The app bundles the everyday pack from milestone 3**, and imports it on first
    launch, so the drills have real words early. The rest of the content comes in
    the final milestone.
    - *Adds to* Build plan → milestones 3 and 8.

### 2026-10-20 (milestone 2, agreed with the owner)

59. **Sentences are their own model**, so one sentence can serve several verbs and
    nouns: *Tu pourras partir quand tu voudras* is a prompt for both *pouvoir* and
    *vouloir*; *Les enfants vont à l’école à pied* is a prompt for *aller* and an
    example of *enfant* and *école*.
    - **Content files:** sentences are in `content/sentences/*.json`, written in
      plain French with no blank. Each lists the verbs it is a prompt for (verb,
      tense, person, the answer as the text has it, alternatives) and the nouns it
      is an example of (noun, and the word as the text has it, which feedback shows
      in bold). Noun files lose `examples`; verb files lose `sentences`.
    - **Tables:** `sentences` (id, text), `sentence_verbs` and `sentence_nouns`, each
      with `source` and `retired`. Deleting a word deletes its links, not the
      sentences.
    - **The prompt** blanks the answer and writes an elided word before it in full:
      *j’, m’, t’, s’, n’, c’* by themselves; *l’* can be *le* or *la*, so its link
      says which (`"before": "le"`).
    - **Validator:** every noun has a sentence and every verb one per tense and
      person; each answer and word is in the text exactly once, as whole words;
      answers agree with the forms; an elided word before a verb can be written in
      full; the text has no `___`.
    - *Replaces* Content model → Sentence and NounExample, Content files → the
      sentences in the verb file and the examples in the noun file, and the
      validator rule "every sentence has exactly one ___"; *supersedes* decisions
      43 (first point) and 49.

60. **Content is checked against Wiktionary.** `tool/dictionary_check.dart` compares
    each noun's gender and plural-only, each synonym's gender, and each verb's
    auxiliary and 24 forms with Kaikki.org's machine-readable French dictionary
    (from the English Wiktionary, extracted with wiktextract).
    - Wiktionary is used to check and draft only: no definition or sentence is
      copied from it.
    - It is credited all the same: on À propos / Crédits (milestone 6) and in
      `content/README.md`. Wiktionary's text is CC BY-SA 4.0.
    - The data, about 580 MB, stays out of the repo, in `data/kaikki/`, which git
      ignores. The tool only advises, and CI doesn't run it.
    - It can't check *h aspiré*, which the data doesn't mark. Reflexive verbs
      without their own table are checked from the plain verb's forms.
    - *Adds to* Phase 1 content → what Claude Code builds (the schema, validator
      and pack builder).

### 2026-10-21 (milestone 2, agreed with the owner)

61. **The everyday sentences come from Tatoeba** (tatoeba.org), in place of the
    drafted ones wherever Tatoeba has one that fits.
    - **How many:** two or more sentences for each verb, tense and person, and two
      or more examples for each noun. A sentence links every everyday verb form and
      noun it uses, so one sentence often counts for several.
    - **Which:** sentences by native speakers (French at level 5 on their Tatoeba
      profile), of 3 to 10 words, with an English translation, no tag other than
      *OK* or a tense, and no crude word. The verb form follows its subject pronoun;
      *avoir* and *être* followed by a participle are another verb's compound tense,
      not theirs. Up to 12 words, or no translation, only where nothing else fits.
    - **No names** in the everyday categories: no capital letter after the first.
      The topic categories, added later, may name people.
    - **Drafted sentences** stay only where Tatoeba can't fill a slot: 17, for 12
      verb forms (*nous disions*, *nous avons su*, *vous avez su*, *tu as voulu*,
      *nous voudrons*, and seven with only one from Tatoeba).
    - **Credit:** each Tatoeba sentence keeps its number and author, in the content
      file (`"credit": {"tatoeba": 1234, "author": "…"}`) and in the `sentences`
      table (`tatoeba_id`, `tatoeba_author`); its id is `s.tatoeba.<number>`.
      Tatoeba is CC BY 2.0 FR: it is credited in `content/README.md`, and on
      À propos / Crédits (milestone 6).
    - **Changes to the text:** apostrophes made typographic (’) and a space before
      *? ! : ;*, as the rest of the content is written. Nothing else.
    - Tatoeba's English translations show on the review page only, never in the app.
      Its downloads stay out of the repo, in `data/tatoeba/`.
    - *Adds to* Content model → Sentence (its credit), Content files, and À propos /
      Crédits; *changes* decision 57 (the sentences are no longer drafted).

### 2026-10-22 (milestone 2, agreed with the owner)

62. **The first content pack is small: the present, 6 verbs and 10 nouns**, so every
    drill can be built and tried with real data.
    - *Les verbes essentiels*: être, avoir, aller, faire, dire, finir. *Les
      essentiels*: homme, femme, jour, chat, chien, soir, voiture, travail, heure,
      maison. The other 23 nouns and 4 verbs are removed (git keeps them).
    - **The content says which tenses it teaches**, in `content/tenses.json`
      (`{"tenses": ["present"]}`). Verbs keep their forms for all four tenses, so a
      tense is added by listing it and writing its sentences.
      - The validator asks for a sentence per verb and person in each tense taught
        only, and refuses a sentence that is a prompt for another tense.
      - The pack records the tenses (`content_meta`, key `tenses`); content that
        doesn't say teaches all four.
      - The importer creates Conjugaison cards only for the tenses taught.
      - The Tense values stay the four, as the spec has them.
    - *Changes* Phase 1 → tenses (the present first, the other three in milestone
      8), Content files (`tenses.json`; the validator rule "at least one sentence per
      tense × person" becomes per tense taught), and the Conjugaison drill settings
      (Temps lists only the tenses taught); *changes* decision 57's lists.
63. **A new milestone 8, before the release pass:** add the passé composé, imparfait
    and futur simple, and grow the lists to 30 verbs and 100 nouns. The release pass
    becomes milestone 9.
    - Phase 1 then ships 30 verbs and 100 nouns in four tenses, instead of the spec's
      60 verbs and its topic categories. Which categories hold the 100 nouns is for
      milestone 8.
    - *Changes* Build plan → Milestones and Content → Phase 1 content; decision 58's
      "the final milestone" is now milestone 8, and decision 13's milestone 8 (the
      repo files) is now 9.
64. **A sentence uses only the content's nouns and verbs**, conjugated in a tense it
    teaches; the lists grow as words are added.
    - Other words (adjectives, adverbs, pronouns, prepositions) are free.
    - An infinitive is allowed when it isn't part of a verb construction: after a
      preposition (*J’ai du travail à finir*), never straight after a conjugated verb
      (*je vais finir* is the futur proche; also *faire* + infinitive, *être en
      train de*, *venir de*).
    - **Tatoeba sentences must have been written in French**, not translated:
      Tatoeba records which is which, and 70% of the earlier picks were translations
      from English that no French speaker would say that way. Native speakers only,
      as before.
    - Also: *ne…pas* in full, no idiom whose meaning isn't its words' (*Il a du
      chien*), no names, 3 to 10 words; a sentence with a subordinate clause ranks
      lower. Where none fits, Claude Code drafts one, and the owner supplies any it
      isn't sure of.
    - `tool/dictionary_check.dart` checks the rule from Wiktionary's parts of speech,
      so it advises rather than fails.
    - *Changes* decision 61 (written in French only) and Content → sentences.
65. **Sentences carry their grammar concepts and a CEFR level; the first pack's
    are A1 only.**
    - `content/grammar.json` lists the grammar concepts, each at the level (A1 to
      B2) French courses usually teach it, with an example, drafted by Claude Code
      for the owner to check (as in decision 57). Its `max_level` is the highest
      level the content's sentences may reach: A1 for now.
    - Each sentence lists every concept it uses (`grammar`) and its `level`, that
      of its hardest concept. The validator checks the concepts exist, the level
      matches, and nothing is above `max_level`. Content with no `grammar.json`
      (the sample) has no tags.
    - `tool/grammar_tag.dart` detects the concepts and writes them into sentences
      with none. Tags already there are kept, since they may have been corrected
      by hand; where the detection disagrees, it lists the difference.
    - From the owner's review: no *y* for a place, no *-t-* inversion, no negation
      but *ne… pas*, no object pronouns (*le*, *lui*), no *en*, no complex
      sentences; all are A2 or above. A question by simple inversion (*As-tu un
      chat ?*) is A1, as the owner's marks showed; after a noun subject (*Ta femme
      a-t-elle…*) or in the negative, it is A2.
    - The owner's own wordings from their review notes are sentences in their own
      right, ahead of Tatoeba's; Claude Code's drafts only fill what is left.
    - For content only: the app doesn't store or use the levels, in keeping with
      the spec's "no fixed curriculum, levels, or content unlocking".
    - *Adds to* Content files (`grammar.json`; a sentence's `level` and `grammar`).

### Notes

- `build_runner` 2.16 no longer has `--delete-conflicting-outputs`. The CLAUDE.md
  command still works (the flag is ignored with a warning), but it could drop the flag.
- `sqlite3` stays at 3.6.0 for now: on this Windows machine, Application Control
  blocks the SQLite library that 3.7.1 downloads, which breaks the tests and the
  content tool. CI on Linux would be fine with either.
