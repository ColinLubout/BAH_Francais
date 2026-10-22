# CLAUDE.md — working rules for this repo

BAH Français: a Flutter app for learning and maintaining French through short, self-paced
drills with spaced repetition. Offline, no accounts, no tracking, no streaks.

**`docs/SPEC.md` is the specification and the source of truth.** Read the section that covers
what you are about to build before you build it. If the spec and this file ever disagree,
the spec wins — and say so, so it can be fixed.

**Never edit `docs/SPEC.md`.** It is exported from a document the project owner maintains, and
any edit here is lost on the next export. When the spec is wrong, incomplete, or does not fit
what the code needs, stop and say so. Record what you propose under "Decisions" in
`PROGRESS.md` and wait for the owner to confirm; they fold it into the document and re-export.
Never change the specified behaviour on your own and never rewrite the requirement to match
what you built.

## Before you start a session

1. Read `PROGRESS.md` to see the current milestone and what is left.
2. Read the part of `docs/SPEC.md` that covers the work at hand.
3. Work on that milestone only. The milestones are in the spec, under Build plan.

## Rules

- **One milestone per branch and pull request**, with its tests. Do not start the next
  milestone in the same PR.
- **Ask instead of guessing.** If the spec does not answer something, stop and ask. Write the
  answer into `PROGRESS.md` when you get it. Never invent a behaviour and carry on.
- **Build only what the spec describes.** No extra features, screens, settings, animations or
  engagement mechanics, however small or obviously useful they seem.
- **All user-facing text comes from `strings/`.** `strings/strings_fr.json` holds the app's
  French text and `strings/strings_en_welcome.json` the welcome screen's English. New text
  means a new key there first, then the generated Dart class. Never write a literal string
  in a widget, and never invent French wording.
- **Never invent French content** — words, genders, conjugations or example sentences. Only
  `content/sample/` may contain any, clearly marked as samples. The real content comes from
  the project owner. The one exception, agreed with the owner (decision 57 in `PROGRESS.md`),
  is the everyday categories in `content/`: Claude Code drafts them and the owner checks
  them before they ship. Run `tool/dictionary_check.dart` on a draft before handing it over.
- **Tests ship with the code**, in the same PR, never in a later clean-up pass.
- **Update `PROGRESS.md`** at the end of every session: the milestone, what is done, what is
  left, and any decision taken. Keep a "Decisions" section for anything that changes or adds
  to the spec, each entry dated, with what was agreed and why — that section is what the
  owner folds back into the specification.

## Architecture

Feature-first folders. Inside a feature, three layers:

- `data/` — Drift tables, DAOs, queries.
- `domain/` — FSRS scheduling, grading, answer normalisation, queue building. **Pure Dart:
  no Flutter imports**, fully testable without a widget tree.
- `presentation/` — widgets and Riverpod providers. No business logic here.

Riverpod is also the dependency injection: no service locator. Routing is go_router.
Persistence is Drift over SQLite. Scheduling uses the `fsrs` package, not a hand-written
algorithm.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Riverpod + Drift codegen
dart run tool/gen_strings.dart                             # strings/*.json -> lib/core/strings.g.dart
flutter analyze
dart format --set-exit-if-changed .
flutter test --coverage
flutter test integration_test                               # needs a device or emulator
dart run tool/content_build.dart content/sample             # validate + build a content pack
dart run tool/content_build.dart content --version 1 --out assets/content/content-pack.sqlite  # rebuild the bundled pack
dart run tool/grammar_tag.dart content                      # tag new sentences with their grammar concepts and level
dart run drift_dev make-migrations                          # after a schema change: dump it + migration tests
dart run tool/dictionary_check.dart content                 # check genders, forms and sentence words against Wiktionary (needs data/kaikki/)
```

Run `flutter analyze`, the format check and the full test suite before calling anything done.

## Quality bar

- Domain layer coverage ≥ 90%. Every acceptance criterion in the spec's Spaced Repetition
  section has a test.
- Widget tests for every screen; integration tests for a full drill session and for a
  force-close mid-session that loses no answered card.
- Anything time-dependent uses the injectable clock — never `DateTime.now()` directly.
- Every schema change ships with a migration and a test that opens the previous version.
  Nothing may drop a table holding review history.
- Accessibility is part of "done": OS text scaling, screen-reader labels, and colour never
  the only signal.

## Things that are easy to get wrong

- The day boundary is **04:00 local time**, and times are stored in UTC.
- A card is one item in one drill; a conjugation card is one verb × one tense.
- Marking a card known writes no rating and no review-log row.
- The brand teal is a background colour: text on it is navy, never white.
- Content updates never modify the user's own words, sentences, known marks or settings.
