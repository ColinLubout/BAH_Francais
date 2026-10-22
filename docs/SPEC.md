# BAH Français Specification

*Specification for the BAH Français app. Last updated 22 October 2026, with decisions 1–76 from `PROGRESS.md` folded in.*

This file is the specification and the source of truth. It is kept in the repo and changed only to fold in a decision the project owner has agreed, in the same pull request that records the decision in `PROGRESS.md` (see Build plan → How Claude Code should work).

## Goal

Help people learn and maintain French by giving them a fast, focused alternative to doomscrolling on their phones. A session is short enough to fit into any spare moment, self-paced, and free of forced pacing, streaks, or social pressure.

The app serves the full range of self-directed learners — true beginners building a first vocabulary, false beginners knocking the rust off, and intermediate learners maintaining and expanding what they already know — by letting each person choose the content and categories they focus on, rather than pushing everyone through one fixed curriculum.

Other than the welcome screen, the entire app is in French, to support immersion from the first session.

### Generic principles

No picking drill duration or number of words — the user presses start and does as many as they like, so a session can be stopped at any time.

### What's in scope (Phase 1)

- Written vocabulary, grammatical gender, and verb conjugation, practiced through typed recall and recognition, scheduled with spaced repetition.
- A built-in, curated word/verb list, organized into categories/topics that learners can prioritize based on their interests and level.
- Letting users extend that list with their own words, images and sentences, and weight which categories they see more new cards from.
- Updating the curated list without rebuilding the app, through a content pack the user chooses to download (see Content updates).

### Explicitly out of scope for now (non-goals)

- Listening and speaking practice — Phase 1 is reading + typed recall only. The speaker icon in the layouts belongs to a much later phase, so no card plays audio and no French voice is used in Phase 1.
- An in-app way to suggest new words or corrections — a later phase. In Phase 1, content changes reach the curated list through GitHub pull requests and issues, outside the app.
- Any fixed curriculum, levels, or content unlocking — learners choose their own mix.
- Streaks, badges, leaderboards, or any social/competitive mechanics — pure utility, no engagement engineering.
- Accounts, cloud sync, or any data leaving the device by default.

### What success looks like

- People reach for this instead of a scrolling app in idle moments, because starting a session has near-zero friction.
- Vocabulary and conjugations genuinely stick — measured by FSRS retention and stability, not by streaks or time-on-app.
- The curated word/verb list grows over time without needing an app rebuild, through content packs.

## Spaced Repetition

### Algorithm

The app uses **FSRS** (Free Spaced Repetition Scheduler) for all scheduling. The scheduler is a port of the reference implementation, **py-fsrs 6.3.2**, verified against py-fsrs's own tests: its interval history, memory-state values and seeded fuzz cases. Its MIT licence is credited on the licence page.

The fsrs Dart package was not used because it is out of date: it has the old default parameters (16.2 days after a first Easy, against 8.3 now) and lacks py-fsrs's fix for a same-day Hard lowering stability, which matters here because every accent slip is graded Hard.

Each card stores its own FSRS state: difficulty, stability, due date, last review, reps, lapses, the learning or relearning step, and state (new / learning / review / relearning). Use py-fsrs's default parameters. Keep a separate parameter set per drill type so each drill can be tuned independently in a later phase.

### Cards

A card is one item in one drill. The same word therefore has separate, independently scheduled cards in the Gender drill and the Vocab drill.

| Drill | Card = | Prompt | Answer |
| --- | --- | --- | --- |
| Gender | one noun | word and/or image | masculin / féminin / les deux |
| Vocab | one noun | image or definition, and a sentence with the noun blanked | typed word |
| Conjugation | one verb × one tense | sentence with the verb blanked, infinitive, tense | typed conjugated form |

For conjugation cards, the grammatical person (je, tu, il/elle, nous, vous, ils/elles) is picked at random on each review from the sentences available for that verb and tense. This keeps the number of cards manageable while still covering all forms.

### Grading

Answers are graded automatically into the four FSRS ratings. The user never has to rate themselves.

**Gender drill:** correct = Good, wrong = Again. Answering *masculin* for a "les deux" noun is simply wrong.

**Vocab and Conjugation drills:**

- Exact correct answer = Good.
- Correct except for accents (é/e, è/e, ç/c, *oe* typed for *œ*, etc.), or a correct noun with a wrong article = Hard. A wrong article together with an accent slip is Hard too, logged as `article`. The correct answer is shown with the error highlighted.
- Anything else = Again.
- If live feedback is on and any letter turned red or orange during typing, the maximum possible grade is Hard, even if the user corrected it before submitting. An exact answer capped this way says *Presque*, as any Hard does.

**Answer normalisation before comparison:** trim whitespace, ignore case, treat ’ and ' as identical, collapse repeated spaces, and ignore a space typed after an apostrophe (*j’ aime* counts as *j’aime*). Accept alternative valid forms listed in the content data, for example je paie / je paye.

**Articles** are known by the space or apostrophe after them: an answer starting with *le, la, les, un, une* or *des* and a space, or with *l’*, always has that article split off before the word is compared. No noun is spelled starting with one, so the word is never tried again with the article as part of it. Without the space or apostrophe, those letters are part of the word.

**User overrides:**

- **Faute de frappe** (typo) follows an *Incorrect* answer, including a mis-tap in the Gender drill, but not *Presque* (already Hard) or *Je ne sais pas*. It changes the grade to Hard. It replaces the answer already saved, while the correction is on screen: the card is scheduled again from its state before that answer, and the review-log row is updated.
- **Trop facile** (too easy) is offered on a word seen for the first time (its card is New), before any answer: it needs no answer, rates the card Easy (review-log row with no typed text and no error), and moves on to the next card. It counts as a correct answer. Once the word has been answered, or on any later review, it is not offered. See Activities → Shared drill behaviour.

### Session flow

In keeping with the generic principles, the user presses start and answers as many cards as they like. Every answer is saved immediately, so a session can be stopped at any moment, including by closing the app, without losing progress.

Cards are served in this order:

1. **Learning steps:** new or failed cards being learned in this session. A new card is shown again after about 1 minute, then about 10 minutes, before FSRS takes over. Failed review cards get one 10-minute relearning step. A step comes up only once its minute has passed.
2. **Due reviews,** with the lowest recall probability (retrievability) first. A review card is due for its whole study day, until the next 04:00: it is served, and counted on Accueil, from the start of that day.
3. **New cards,** interleaved with reviews at roughly 1 new card per 4 reviews, up to the daily new-card limit. Which new card comes next is set by Content → Category weighting and new-card order.
4. **Free practice:** when nothing is due and the new-card limit is reached, show a short message (*Tout est à jour !*) once, above the next card, and let the user continue: first with learning cards waiting for their step, soonest first, then with early reviews of the cards closest to forgetting. These early reviews go through FSRS normally, since it handles early reviews correctly.

The same card is never shown twice in a row while another card could be.

**The daily review limit** (*Révisions max par jour*): once it is reached, due reviews wait until tomorrow, while learning steps and new cards (within the new-card limit) carry on. Only answers to cards in the review state count towards the limit. When nothing else is left, learning cards waiting for their step are shown early, and after them the drill says *Ça suffit pour aujourd’hui.* instead of offering free practice. Accueil's due count shows at most what the limit leaves.

The "day" resets at 04:00 local time. Intervals include FSRS fuzz so cards learned together don't all fall due on the same day.

Times are stored in UTC and converted to local time to decide which day a review belongs to. Every review stores the study day it was given on (`study_day`), and the day's new-card and review counts are counted by that stored day, so a clock, timezone or daylight-saving change never moves past reviews to another day. If the phone's clock, timezone or daylight saving changes, the new local time simply applies from then on: a day can therefore be shorter or longer than 24 hours, and the daily new-card count for that day is not recalculated. Reviews already logged are never rewritten. Unit tests cover a timezone change mid-session, a daylight-saving change, and the clock going backwards.

### Settings

Each drill settings screen includes:

| Setting | Default | Range |
| --- | --- | --- |
| Nouvelles cartes par jour (new cards per day) | 15 | 0–100 |
| Révisions max par jour (max reviews per day) | unlimited | unlimited or 10–999 |

A global setting, on the Réglages screen, controls:

| Setting | Default | Range |
| --- | --- | --- |
| Rétention visée (target retention) | 90% | 80–97% |

Include a one-line French explanation: a higher target means more reviews but less forgetting.

### Leeches

A card failed (rated Again) 8 times in total is flagged as a leech ("mot difficile"). Leeches stay in rotation but appear in the Review List. Future phases may offer mnemonics or extra example sentences for them.

Every Again that stands counts: those from learning steps and *Je ne sais pas* count, and answers overridden by *Faute de frappe* don't. This differs from FSRS's lapses, which count only failed reviews, so cards keep their own `again_count`. The leech flag is permanent.

### Mastery levels

A display-only level derived from FSRS stability, shown in the Word List, Verb List and Stats screens:

| Level | Condition |
| --- | --- |
| Nouveau | never reviewed, or reset to New by a content update |
| En apprentissage | learning or relearning state |
| Fragile | stability < 7 days |
| Acquis | stability 7–90 days, both included |
| Maîtrisé | stability > 90 days |
| Connu | marked known by the user (see Activities → Je le connais) |

These levels never affect scheduling.

### Review List

Due, at-risk (retrievability below 80%) and leech cards are listed on the Liste de révision screen; see Screens.

### Data model

All data is stored locally in SQLite (Drift). Nothing ever leaves the device, in line with the offline and no-tracking principles.

**Card:** id, item\_id, drill\_type, tense (Conjugation cards only), the FSRS state (state stored as `new` / `learning` / `review` / `relearning`, step, stability, difficulty, due, last\_review, reps, lapses), again\_count (see Leeches), is\_leech, known\_at (set when the user marks the card known; null otherwise; cards with known\_at set are never scheduled), created\_at.

**ReviewLog** (one row per answer): card\_id, session\_id, timestamp, study\_day (`yyyymmdd`), rating, the state before the review, elapsed\_days (null for a card's first review), scheduled\_days (the interval that review set; 0 for a step), response\_time\_ms, the typed answer, and error\_type (none / accent / article / wrong / typo\_override / gave\_up). An override replaces its answer's row. A card's rows go with it when the user deletes their word (a foreign key), so every row has its card, and the card gives its drill. Those answers then drop out of Statistiques and of later FSRS tuning; the totals of past sessions still count them.

**Session:** id, drill\_type (`mixed` for a mixed session), start\_time, end\_time, and counts of cards answered, correct and incorrect. The row is written with the session's first answer, so a session with none leaves nothing behind, and its end time moves to each answer's time, so a session cut short by a force-close still has a duration. *Correct* means anything but Again: *Presque* (Hard, *Faute de frappe* included) counts as correct, as FSRS counts Hard as remembered, which keeps % correct in line with the real retention figures.

**Image:** id, item\_id, format (svg / png / jpeg), svg (the markup, for an SVG) or bytes (the encoded file, for PNG and JPEG) — exactly one is set, to match the format, since a Drift column has one type — source (the credit), created\_at. An item can have any number of images. See Activities → Images.

Times are stored in UTC, as microseconds, so they read back exactly. Enums are stored by their ids (`passe_compose`, `new`). Foreign keys are on.

The review log feeds the Stats screen and enables per-user parameter optimisation later.

**Migrations:** the database has a schema version, and every schema change ships with a Drift migration and a test that opens a database from the previous version and checks the data survives. A user's review history cannot be recreated, so no change may drop or rebuild a table holding it.

**If the app is deleted,** its data goes with it. Phone backups (iCloud, Android backup) include the database, so a new phone restores progress; export and import to a file come in a later phase. The Welcome screen says this in one line, so nobody is surprised.

### Later phase

- **Per-user optimisation:** once a drill has at least 1,000 reviews, re-fit that drill's FSRS parameters on-device from the review log (for example with fsrs-rs via flutter\_rust\_bridge). Until then, use the default parameters.
- **Export and import** of cards and review logs to a file, for backup and device transfer.

### Acceptance criteria

- Scheduling logic has unit tests using an injectable clock. These cover each rating from each card state, early and late reviews, the 04:00 day boundary, the daily new-card limit, and leech flagging.
- Grading has unit tests covering exact match, accent-only errors, wrong article, alternative forms, apostrophe normalisation, and the red-or-orange-letter cap.
- Force-closing the app mid-session loses no answered cards.
- All scheduling works with no network connection.
- All user-facing text is in French, except the welcome screen.

## Content

All words, verbs, sentences and images live in the app's SQLite database, in the tables below, alongside the Card, ReviewLog, Session and Image tables from Spaced Repetition → Data model. Official content arrives through content packs (see Content updates); the user's own content uses the same tables with source = perso.

### Content model

Every official row has a stable string id that is never changed or reused (e.g. `n.table`, `v.aller`, `s.aller.pc.1p.01`). Ids are lowercase ASCII letters, digits and hyphens after their prefix (`n.petit-dejeuner`, `cat.vie-quotidienne`); sentence ids add parts after dots (`s.aller.pc.1p.01`), and a sentence from Tatoeba is `s.tatoeba.<number>`. Perso rows get a generated id prefixed `p.`. Every content table also has `source` (official / perso) and `retired` (bool) unless noted.

| Table | Columns | Notes |
| --- | --- | --- |
| Category | id, name, kind (noun / verb), sort\_order, everyday (bool) | e.g. *La cuisine*; sort\_order decides where it is listed; everyday: see Category weighting |
| Noun | id, word, gender (m / f / both), elides (bool), plural\_only (bool), definition, gloss, synonyms (JSON array), ending\_hint, level, rank | the word is written without its article; elides = takes *l’*; level = débutant / intermédiaire / avancé; rank = frequency, 1 = most common |
| NounCategory | noun\_id, category\_id | a noun can be in several categories |
| Verb | id, infinitive, group (er / ir / re / irr), auxiliary (avoir / être), pronominal (bool), h\_aspire (bool), level, rank | h\_aspire: a form starts with an *h* that doesn't elide (*je hais*) |
| VerbCategory | verb\_id, category\_id |  |
| VerbForm | verb\_id, tense, person, form, alternatives (JSON array) | person = 1s 2s 3s 1p 2p 3p; compound tenses store the masculine singular participle for every person (*sommes allé*) |
| Sentence | id, sentence\_text, tatoeba\_id, tatoeba\_author | plain French, with no blank; the Tatoeba number and author for a sentence from Tatoeba |
| SentenceVerb | sentence\_id, verb\_id, tense, person, answer, alternatives (JSON array), before | the sentence is a Conjugaison prompt for that verb, tense and person; answer = the words as the text has them, agreement included (*sommes allés*); before = *le* or *la* when an *l’* comes just before the answer |
| SentenceNoun | sentence\_id, noun\_id, word | the sentence is an example of the noun; word = as the text has it (*haricots*), shown in bold |
| CategoryWeight | drill\_type, category\_id, weight (jamais / moins / normal / plus) | no row = normal; not content, never touched by updates |
| ContentMeta | key, value | content\_version, released\_at, schema\_version, tenses (the tenses the content teaches); no source/retired |

- **Sentences are their own model**, so one sentence can serve several verbs and nouns: *Tu pourras partir quand tu voudras* is a prompt for both *pouvoir* and *vouloir*; *Les enfants vont à l’école à pied* is a prompt for *aller* and an example of *enfant* and *école*. Deleting a word deletes its links, not the sentences.
- **Synonyms** are each a word sharing the noun's gender and elision, or a word with its own (`{ "word": "auto", "elides": true }`, with `"gender"` too when it differs): *la voiture*, but *l’auto*. A plural-only noun's synonyms are plural-only too.
- **Tense** values: `present`, `passe_compose`, `imparfait`, `futur_simple`. Adding a tense later adds values only, never columns.
- **Card** has a nullable `tense` column: set for Conjugation cards (one verb × one tense), null otherwise. item\_id points to a Noun for Gender and Vocab cards and to a Verb for Conjugation cards.
- The 3s and 3p persons cover *il / elle / on* and *ils / elles*; the sentence decides which.
- Text columns are `sentence_text` and the like, never `text`, which breaks Drift's generated migration test code.

### Content files

The source files in `content/` (see Content updates) are JSON in UTF-8, with fields matching the tables above. The build tool, `tool/content_build.dart`, turns them into the content pack. A JSON Schema for each kind of file lives in `content/schema/`, and the validator checks the files against them first, then the rules below.

| File | Holds |
| --- | --- |
| `tenses.json` | the tenses the content teaches: `{"tenses": ["present"]}`. Content that doesn't say teaches all four |
| `grammar.json` | the grammar concepts sentences are tagged with, each at its CEFR level, and `max_level` (see Phase 1 content) |
| `verb-categories.json` | every verb category: id, name, sort order and everyday |
| `nouns/<category>.json` | one noun category and its nouns |
| `verbs/<infinitive>.json` | one verb and its 24 forms |
| `sentences/<name>.json` | sentences, each listing the verbs it is a prompt for and the nouns it is an example of; which file a sentence is in doesn't matter |
| `images/<noun id without n.>/` | a noun's SVGs |

**Noun category** — `content/nouns/cuisine.json`:

```json
{
  "category": { "id": "cat.cuisine", "name": "La cuisine et les repas", "kind": "noun", "sort_order": 2 },
  "nouns": [
    {
      "id": "n.fourchette",
      "word": "fourchette",
      "gender": "f",
      "elides": false,
      "level": "debutant",
      "rank": 412,
      "definition": "Couvert à dents pour piquer les aliments.",
      "synonyms": [],
      "images": ["fourchette-1.svg", "fourchette-2.svg"],
      "also_in": ["cat.objets"]
    }
  ]
}
```

**Verb** — `content/verbs/aller.json` (forms abbreviated):

```json
{
  "id": "v.aller",
  "infinitive": "aller",
  "group": "irr",
  "auxiliary": "etre",
  "pronominal": false,
  "level": "debutant",
  "rank": 5,
  "categories": ["cat.verbes-essentiels"],
  "forms": {
    "present": { "1s": "vais", "2s": "vas", "3s": "va", "1p": "allons", "2p": "allez", "3p": "vont" },
    "passe_compose": { "1s": "suis allé", "...": "..." }
  }
}
```

**Sentences** — `content/sentences/aller.json`:

```json
{
  "sentences": [
    {
      "id": "s.tatoeba.7101804",
      "text": "Je vais un peu mieux.",
      "credit": { "tatoeba": 7101804, "author": "felix63" },
      "level": "A1",
      "grammar": ["present", "articles"],
      "verbs": [{ "verb": "v.aller", "tense": "present", "person": "1s", "answer": "vais" }],
      "nouns": []
    }
  ]
}
```

- A sentence is written in plain French, with no blank. Its `verbs` give the answer as the text has it, with `alternatives` and, after an *l’*, `"before": "le"` or `"la"`; its `nouns` give the word as the text has it.
- A category is the everyday one with `"everyday": true` (see Category weighting).
- A noun lists an image by its file name, or as `{ "file": …, "source": … }` when it has a credit. An image's id is `i.` and its file name without `.svg` (`i.fourchette-1`), so file names are unique across the content.
- Alternatives are written as `"alt": {"1s": ["paye"]}` beside a tense's forms, and as `"alternatives"` on a sentence's verb.
- A synonym is a plain word, or `{ "word": "auto", "elides": true }` (see Content model).
- A noun starting with *h* states `elides`, and a verb with a form starting with *h* states `h_aspire` (false for *j’habite*, true for *je hais*), so the setting is confirmed for each such word.

**Validator rules** beyond the schema:

- every id is unique, and so is every image file name;
- every noun has an image or a definition;
- a noun or synonym is written without its article: one starting with *le, la, les, un, une* or *des* and a space, or with *l’*, is refused, since its article comes from its gender;
- the categories a noun or verb is in exist, and are of the right kind; at most one everyday category of each kind;
- a noun starting with *h* states `elides`, and a verb with a form starting with *h* states `h_aspire` (and no other verb does);
- every verb has a form for all four tenses × six persons;
- every noun has a sentence, and one with the noun as it is typed (not in the plural, unless plural-only), or a synonym, for the Vocabulaire drill to blank; every verb has a sentence per person in each tense taught; no sentence is a prompt for a tense the content doesn't teach;
- a sentence is written in full, with no `___`;
- the verbs and nouns a sentence uses exist, and their words are in it exactly once, as whole words;
- a verb's answer and alternatives are the stored form or one of its alternatives, plus *e*, *s* or *es* in a compound tense for agreement (*allé* → *allées*);
- an elided word just before a verb can be written in full in the prompt: *j’, m’, t’, s’, n’, c’* always, *l’* when the sentence says `le` or `la`;
- with a `grammar.json`, every sentence lists the grammar concepts it uses, which exist, and its level, that of its hardest concept, no higher than `max_level`;
- every image exists and follows the SVG rules from Activities → Images; one over 20 KB is a warning, not an error.

### Category weighting and new-card order

Each drill's settings let the user set every category to one of four weights. Weights change which **new** cards come up; reviews of cards already learned always continue, except for Jamais. Categories are prioritised with their weights only: users don't reorder them, and a category's sort\_order decides where it is listed.

| Weight | Share of new cards | Reviews |
| --- | --- | --- |
| Jamais | none | paused: the category's cards are not scheduled |
| Moins | 0.5× | continue |
| Normal (default) | 1× | continue |
| Plus | 2× | continue |

New cards come in this order:

1. **The user's own words**, oldest first, from any of their categories not set to Jamais.
2. **The everyday category.** The content can mark one noun category and one verb category as the everyday set, the universally useful words, with `"everyday": true`; the other categories are topics. While a drill's everyday category has new cards, they come before any topic's. Setting it to Jamais skips it, and pauses its reviews as Jamais always does; Moins and Plus make no difference to it.
3. **The topics, by their weights:** a category is drawn at random, with probability in proportion to its weight, among those that still have new cards for that drill, and its next new card is taken.

- **Within a category,** official nouns come by level (débutant → intermédiaire → avancé), then by rank (most common first); Conjugation cards by level, then tense (présent → passé composé → imparfait → futur simple), then rank. With no starting-level question, this is what gives beginners the basic words first; anyone who knows them taps *Je le connais*.
- ***Perso*** is a category like any other, with its own weight in each drill; since the user's own words come first, its weight only matters for Jamais.
- **Nouns in several categories:** a noun can come through any of its categories not set to Jamais, and its cards pause only when every one of its categories is Jamais.
- **Turning off a tense or a verb group** in Conjugaison's settings pauses those cards entirely, reviews included, as Jamais does.
- **Setting a category back from Jamais** resumes its cards with their FSRS state; overdue cards simply come back as due.
- The daily new-card limit applies across all categories of a drill, not per category.

### Phase 1 content

Phase 1 ships **30 verbs and 100 nouns, in the four tenses**, built up in two steps so every drill can be built and tried with real data early:

- **The first pack** (milestones 3 to 7): the présent only, with the everyday categories — *Les essentiels*, 10 nouns (homme, femme, jour, chat, chien, soir, voiture, travail, heure, maison), and *Les verbes essentiels*, 6 verbs (être, avoir, aller, faire, dire, finir) with all 24 forms. The app bundles this pack from milestone 3 and imports it on first launch.
- **Milestone 8** adds the passé composé, imparfait and futur simple, and grows the lists to 30 verbs and 100 nouns. Which categories hold the 100 nouns is decided then; the topic categories first proposed for Phase 1 are below, to choose from.

| Category (id) | Nouns (first proposed) |
| --- | --- |
| La maison (cat.maison) | 30 |
| La cuisine et les repas (cat.cuisine) | 30 |
| La nourriture et les boissons (cat.nourriture) | 40 |
| Les vêtements (cat.vetements) | 25 |
| Le corps et la santé (cat.corps) | 30 |
| La famille et les gens (cat.gens) | 30 |
| La ville et les magasins (cat.ville) | 30 |
| Les transports et les voyages (cat.transports) | 30 |
| La nature et le temps qu’il fait (cat.nature) | 30 |
| Les animaux (cat.animaux) | 30 |
| Le temps et le calendrier (cat.calendrier) | 25 |
| L’école et le travail (cat.travail) | 30 |
| Les loisirs et le sport (cat.loisirs) | 30 |
| Les objets du quotidien (cat.objets) | 30 |
| Les idées et les sentiments (cat.idees) | 30 |

- **Who writes it:** the project owner supplies the content and the SVG images. The one exception is the everyday categories: Claude Code drafts them, and the owner, or a fluent speaker, checks every word, gender, form and sentence before they ship. Their `rank` is an estimated order within the set, not a corpus frequency.
- **Checked against Wiktionary:** `tool/dictionary_check.dart` compares each noun's gender and plural-only, each synonym's gender, each verb's auxiliary and 24 forms, and the words of the sentences with Kaikki.org's machine-readable French dictionary (from the English Wiktionary, extracted with wiktextract). Wiktionary is used to check and draft only: no definition or sentence is copied from it. The data, about 580 MB, stays out of the repo, in `data/kaikki/`. The tool only advises, and CI doesn't run it; it can't check *h aspiré*, which the data doesn't mark.
- **Images:** concrete nouns get at least one SVG; abstract nouns (mostly *Le temps et le calendrier* and *Les idées et les sentiments*) use their definition.
- **Quality:** every word, gender, form and sentence is checked by a fluent French speaker before it ships, since a wrong gender or form teaches a mistake.

**Sentences.** There are two or more for each verb, tense taught and person, and two or more examples for each noun, including one with the noun as it is typed. A sentence links every content verb form and noun it uses, so one sentence often counts for several.

- **Where they come from:** Tatoeba (tatoeba.org) first, wherever it has one that fits, then the owner's own wordings; Claude Code drafts only what is left, and the owner supplies any it isn't sure of.
- **From Tatoeba:** sentences written in French, not translated (Tatoeba records which is which), by native speakers (French at level 5 on their profile), with no tag other than *OK* or a tense, and no crude word. Their text changes only to make apostrophes typographic (’) and put a space before *? ! : ;*. Each keeps its Tatoeba number and author, as Tatoeba's licence (CC BY 2.0 FR) asks; Tatoeba's English translations appear only on the owner's review page, never in the app. Tatoeba's downloads stay out of the repo, in `data/tatoeba/`.
- **Words:** a sentence uses only the content's nouns and verbs, conjugated in a tense the content teaches; the lists grow as words are added. Other words (adjectives, adverbs, pronouns, prepositions) are free. An infinitive is allowed when it isn't part of a verb construction: after a preposition (*J’ai du travail à finir*), never straight after a conjugated verb (*je vais finir* is the futur proche; also *faire* + infinitive, *être en train de*, *venir de*). `tool/dictionary_check.dart` checks this from Wiktionary's parts of speech, so it advises rather than fails.
- **Style:** 3 to 10 words, *ne…pas* in full, no idiom whose meaning isn't its words' (*Il a du chien*), no names in the everyday categories (the topic categories may name people); a sentence with a subordinate clause ranks lower.
- **Level:** `content/grammar.json` lists the grammar concepts, each at the CEFR level (A1 to B2) French courses usually teach it, with an example; its `max_level` is the highest level the sentences may reach, A1 for now. Each sentence lists every concept it uses and its level, that of its hardest concept. `tool/grammar_tag.dart` detects the concepts and writes them into sentences with none, keeps tags already there (they may have been corrected by hand), and lists where it disagrees. From the owner's review, these are above A1: *y* for a place, *-t-* inversion (*a-t-elle*), any negation but *ne… pas*, object pronouns (*le*, *lui*), *en*, and complex sentences. A question by simple inversion (*As-tu un chat ?*) is A1; after a noun subject or in the negative, it is A2. The levels are for choosing content only: the app doesn't store or use them, in keeping with "no fixed curriculum, levels, or content unlocking".

**What Claude Code builds:** the content schema, validator and pack builder, the dictionary check and grammar tagger, the everyday drafts above, and a small **sample set** in `content/sample/` (3 noun categories of 10 nouns, with an everyday category of each kind, and 5 verbs with all forms and sentences in all four tenses) used for development and tests. The sample set is written by Claude Code, marked as samples, and must never ship.

## Content updates

The official word and verb lists are updated by downloading a new content pack, only when the user taps **Mettre à jour le contenu** in Réglages. The app never checks for updates on its own, and the download sends no identifiers or user data.

### Where content comes from

- **Source files** live in the app's GitHub repo under `content/`: one JSON file per noun category (`content/nouns/<category>.json`), one per verb (`content/verbs/<infinitive>.json`), the sentences in `content/sentences/`, a few files for the whole content (`tenses.json`, `grammar.json`, `verb-categories.json`), and SVGs in `content/images/<noun id without n.>/` (see Content → Content files). Contributors add or fix content by pull request, which is where all content contributions land.
- **Build:** a Dart command-line tool in `tool/` validates every file (required fields from Activities → Content each item needs, SVG rules from Activities → Images, unique ids) and builds a **content pack**: one SQLite file with the same content tables as the app, images included. CI runs the validator on every PR.
- **Publishing:** pushing a tag `content-vN` makes CI build the pack and upload it, with a manifest, to a GitHub release named `content-latest`, replacing the previous assets. The app reads from that one fixed URL, set in a single constant.
- **Bundled copy:** every app build ships with the content pack that was current at build time, so a fresh install works fully offline. It is committed as `assets/content/content-pack.sqlite`, built from `content/`, and a test fails if the two drift apart.

### Manifest

`content-manifest.json`, fetched first so the user sees what's new before downloading the pack.

| Field | Example | Purpose |
| --- | --- | --- |
| content\_version | 14 | increases by 1 with each publish |
| min\_app\_schema | 2 | lowest app content-schema version that can read this pack |
| pack\_url | …/content-pack-v14.sqlite | the file to download |
| size\_bytes | 2 400 000 | shown to the user before downloading |
| sha256 | … | checked after download |
| released\_at | 2026-10-01 | shown in Réglages and À propos |
| summary | +120 mots, +40 phrases, 15 corrections | French summary shown before downloading |

### Update flow

1. The user taps **Mettre à jour le contenu**. The app fetches the manifest.
2. Depending on the result, it shows one of:
   - *Le contenu est à jour* — content\_version is not higher than the installed one.
   - *Version 14 disponible : +120 mots, +40 phrases, 15 corrections (2,4 Mo)* with **Télécharger** and **Plus tard**.
   - *Mettez à jour l’application pour recevoir ce contenu* — the pack needs a newer app.
   - *Pas de connexion* — the request failed; nothing changes.
3. On **Télécharger**: download the pack with a progress bar, check its sha256, validate it, then merge it into the app database (rules below) in a background isolate.
4. Show a result line (*Contenu mis à jour : version 14*) and return to Réglages. Drills can't be started during the merge, which should take a few seconds at most.

Any failure (download interrupted, checksum mismatch, invalid pack, app closed mid-merge) leaves the installed content exactly as it was, and a later tap starts over. The downloaded file is deleted once merged or rejected.

When the app itself is updated, its bundled pack goes through the same merge on first launch if its content\_version is higher than the installed one.

### First launch

A fresh install starts with an empty database and the bundled content pack, which has to be imported before any drill can run.

- On the very first launch, the app imports the bundled pack in a background isolate while the Welcome screen is on screen, which is usually enough time to finish it.
- If the user reaches Accueil before the import is done, the drill tiles are disabled and show *Préparation du contenu…* with a progress indicator. Nothing else is blocked.
- An import interrupted by the app closing leaves nothing behind and starts again on the next launch, since it runs in one transaction.
- The import creates New cards for every noun in both noun drills, and Conjugaison cards for every verb in each tense the pack teaches.
- Importing the Phase 1 content (100 nouns, 30 verbs and their images) should take a few seconds. It is measured in a test with the full content pack, and treated as a defect above 10 seconds on a mid-range phone.

### Merge rules

The app always receives the full pack and works out the differences itself, by stable id. Every official item, sentence and image has an id that is never changed or reused.

| Change in the pack | What the app does |
| --- | --- |
| New item | adds it and creates its cards as New; a new category starts at Normal in every drill |
| Changed text only (definition, synonyms, category) | updates the content; cards keep their FSRS state |
| A tense newly taught | creates that tense's Conjugaison cards, as New, for every verb |
| Changed answer (gender, spelling, conjugated form) | updates the content and resets the affected cards to New, because the user may have learned the wrong answer |
| Item removed | marks it retired: hidden from lists and never scheduled, but kept so review logs stay valid |
| Image added, changed or removed | applied by image id |
| Sentence added, changed or removed | applied by sentence id; a conjugation card with no sentences left for a tense and person uses the others |

The merge never touches the user's own words and sentences, *Je le connais* marks, leech flags, category weighting, settings or review logs. A Perso word may end up duplicating a new official one; both are kept. The whole merge runs in one database transaction.

### Versions shown to the user

Réglages shows the installed content version and date under the button (*Contenu : version 14 · 1 oct. 2026*). À propos shows the same.

### Tests

Unit tests cover each merge rule, user data left untouched, the transaction rolling back on a failure mid-merge, a checksum mismatch, a pack needing a newer app, and the bundled pack being applied after an app update. The content validator has its own tests and runs in CI.

## Screens

Five are reached from a bottom navigation bar; drills and their summaries open full-screen with no navigation bar. This section says what each screen shows and where it leads. Behaviour already defined in Spaced Repetition and Activities is referenced, not repeated.

### Navigation

```mermaid
flowchart LR
    W[Welcome<br/>first launch only] --> A
    subgraph Bar[Bottom navigation bar]
        A[Accueil]
        M[Mots]
        V[Verbes]
        S[Statistiques]
        R[Réglages]
    end
    subgraph Drills[Drill screens]
        DG[Genre]
        DV[Vocabulaire]
        DC[Conjugaison]
    end
    A --> Drills
    A --> L[Liste de révision]
    S --> L
    L --> Drills
    Drills --> X[Résumé de session]
    X -- Terminer --> A
    X -- Continuer --> Drills
    A -- tile menu --> DS[Réglages de l’exercice<br/>one per drill]
    R --> DS
    M --> FM[Fiche mot]
    M --> AM[Ajouter un mot]
    L --> FM
    V --> FV[Fiche verbe]
    L --> FV
    R --> AP[À propos / Crédits]
```

The back gesture always returns to the previous screen. Leaving a drill by back gesture behaves exactly like tapping ×.

- **The navigation bar** has five entries: *Accueil*, *Mots*, *Verbes*, *Stats* and *Réglages*, with the icons `home`, `menu_book`, `edit_note`, `bar_chart` and `settings`, outlined when not selected. The bar says *Stats*, because *Statistiques* broke mid-word on narrow phones and at larger text sizes; the screen's own title stays *Statistiques*. Its selection indicator is teal with a navy icon (teal is "filled indicators").
- Screens reached from the bar have no top app bar.

### Screen index

| Screen | Reached from | Purpose |
| --- | --- | --- |
| Welcome | first launch | explain the app, crash-report opt-in |
| Accueil | nav bar | start a session |
| Genre / Vocabulaire / Conjugaison drill | Accueil, Liste de révision | answer cards |
| Résumé de session | ending a drill | cards answered, % correct, duration |
| Réglages de l’exercice (×3) | Réglages, Accueil tile menu | per-drill settings |
| Liste de révision | Accueil, Statistiques | due, at-risk and difficult cards |
| Mots | nav bar | browse, search and add nouns |
| Fiche mot | Mots, Liste de révision | one noun: content and card status |
| Verbes | nav bar | browse and search verbs |
| Fiche verbe | Verbes, Liste de révision | one verb: conjugation tables and card status |
| Statistiques | nav bar | progress from the review log |
| Réglages | nav bar | app-wide settings |
| À propos / Crédits | Réglages | version, licence, image credits |
| Ajouter un mot | Mots | add your own noun |

### Welcome

Shown once, on first launch, and the only screen in English. It takes under 30 seconds and ends on Accueil.

- **Three short lines** on what the app is: short self-paced sessions, spaced repetition, no streaks or tracking, works offline, and everything after this screen is in French.
- **One line on skipping known words:** there is no placement test; any word you already know can be removed from practice with one tap on *Je le connais*.
- **One line on your data:** everything stays on this phone and is included in its backups; deleting the app deletes your progress.
- **Crash reports** toggle, off by default, with one line saying reports are anonymous stack traces only. This is the one-time opt-in prompt from the Tech Stack section.
- **Commencer** button → Accueil. Every category starts at Normal.
- While this screen is open, the bundled content pack is imported in the background (see Content updates → First launch).
- Its background is plain, like every other screen's: white in light mode, navy in dark mode, with no gradient.

### Accueil

The home screen. Layout and session types are defined in Activities → Starting a session. In addition:

- Each drill tile has a ⋮ menu with one item, **Réglages de l’exercice**.
- Below the tiles, a text link **Liste de révision** opens the Review List.
- When nothing is due, a tile shows no due line at all, even when new words are left to learn, and Commencer still works (free practice, per Session flow).
- While the first launch's import runs, the tiles are disabled and show *Préparation du contenu…* (see Content updates → First launch).
- If every category is set to Jamais for a drill, its tile is disabled with the line *Aucune catégorie choisie*, and tapping it opens that drill's settings.

### Drill screens (Genre, Vocabulaire, Conjugaison)

One screen layout, with the prompt and answer area specific to each drill (see Activities). Each drill screen has these states:

| State | What the user sees |
| --- | --- |
| Question | top bar (×, cards answered), prompt, answer area |
| Correction | after an answer that wasn't Correct: the card stays in place, with the correction from Activities → Shared drill behaviour |
| Tout est à jour | a one-line message shown once, above the next card, when the session moves into free practice |
| Ça suffit pour aujourd’hui | the review limit is reached and nothing else is left (Spaced Repetition → Session flow) |
| Nothing to show | *Aucune carte disponible* and a button to the drill's settings, if every category is off or no content exists |

- In a **mixed session**, a small label under the top bar names the current drill (Genre / Vocabulaire / Conjugaison).
- A session started from the **Liste de révision** ends by itself when that group's cards are done, then shows the summary.
- **Leaving the app:** returning within 30 minutes resumes the same card. After 30 minutes the session is closed (end\_time = time of the last answer) and the next start opens a new one.

### Résumé de session

Shown when the user taps × or a Review List session runs out.

- Cards answered, % correct, duration. In a mixed session, the same three numbers per drill underneath. % correct counts every answer but Again as correct (see Data model → Session).
- **Terminer** → Accueil. **Continuer** → back into the same session.
- If no card was answered, there is no summary and no Session row is saved; × goes straight to Accueil.

### Réglages de l’exercice

One screen per drill, reached from Réglages or the tile menu on Accueil. A mixed session uses each drill's own settings.

| Setting | Genre | Vocabulaire | Conjugaison | Default |
| --- | --- | --- | --- | --- |
| Nouvelles cartes par jour | ✓ | ✓ | ✓ | 15 (0–100) |
| Révisions max par jour | ✓ | ✓ | ✓ | unlimited |
| Catégories (Jamais / Moins / Normal / Plus) | ✓ | ✓ | ✓ | Normal |
| Afficher l’image | ✓ |  |  | on |
| Correction en direct |  | ✓ | ✓ | on |
| Temps (présent, passé composé, imparfait, futur simple) |  |  | ✓ | all on |
| Groupes de verbes (-er, -ir, -re, irréguliers) |  |  | ✓ | all on |

Changes apply from the next card; cards already scheduled keep their due dates.

- **Temps** lists only the tenses the content teaches; with the présent alone, it has nothing to choose.
- **Turning off a tense or a verb group** pauses those cards entirely, reviews included, as Jamais does.
- There is no *Article obligatoire*: the Vocabulaire answer box sits in a sentence that already shows the article, and the Genre drill tests the gender.

### Liste de révision (Review List)

Three groups, each with a count and the first few items:

- **À réviser aujourd’hui** — cards due today, split by drill.
- **À risque** — cards with retrievability below 80%.
- **Mots difficiles** — leeches (see Spaced Repetition → Leeches).

Tapping a group starts a drill session limited to those cards; for a group spanning drills, it is a mixed session. Tapping an item opens its Fiche mot or Fiche verbe. An empty group shows *Rien ici pour l’instant*.

### Mots (Word List)

Every noun, official and the user's own.

- **Search** field at the top. Matching ignores case and accents (*ecole* finds *école*).
- **Filters:** category, mastery level (including *Connu*), source (Officiel / Perso), and *Mots difficiles* only.
- **Row:** the word with *un/une*, its category, and two mastery chips, one for Genre and one for Vocabulaire. Leeches carry a small marker; known words show *Connu*.
- **Sort:** alphabetical (default) or by mastery level, weakest first.
- A **+** button opens Ajouter un mot.

### Fiche mot (word detail)

- All the word's images (swipe between them) or its definition, the word with *un/une*, gender, synonyms, example sentences, category and level.
- **Card status** for Genre and Vocabulaire: mastery level, next due date, number of reviews and lapses, and whether it is a mot difficile.
- **Je le connais / Remettre en révision:** marks the word known (same effect as the drill button), or brings a known word back into practice.
- **Actions on the user's own words:** *Modifier*, *Supprimer*, and *Ajouter une image* / *Retirer l’image* (see Activities → Images). Deleting a word deletes its cards and their review-log rows, and its links to sentences, not the sentences (see Data model → ReviewLog).
- Official words have no edit actions in Phase 1; corrections to them go through GitHub.

### Ajouter un mot (add a word)

A form that creates a Perso noun and its Genre and Vocabulaire cards as new cards.

| Field | Required | Notes |
| --- | --- | --- |
| Mot | yes | if it already exists, show a warning with a link to its Fiche mot |
| Genre | yes | masculin / féminin / les deux |
| Image | no | one or more, chosen from the phone (see Activities → Images) |
| Définition | unless an image was added | used as the Vocabulaire prompt when there is no image |
| Phrase d’exemple | yes | with the word as it is typed, since the Vocabulaire drill puts its answer box there; stored in full with its link, like every sentence |
| Synonymes | no | comma-separated |
| Catégorie | yes | an existing category, or *Perso* (default) |

### Verbes (Verb List)

- Search, filters (category, verb group, mastery level, *Mots difficiles* only) and sort work as in Mots.
- **Row:** infinitive, group, and one mastery chip per enabled tense.
- There is no + button: new verbs arrive only through content updates in Phase 1, because each one needs a full conjugation table.

### Fiche verbe (verb detail)

- Infinitive, group and auxiliary.
- One section per tense: the six persons with their forms (alternatives shown, e.g. *je paie / je paye*), the card status (mastery level, next due date, reviews, lapses), and that tense's sentences.
- Each tense section has **Je le connais** or **Remettre en révision**, acting on that verb × tense only.
- **Ajouter une phrase:** the user picks a tense and person and writes a sentence with *\_\_\_* where the verb goes. The expected answer is filled in from the conjugation table and can be edited for agreement (*allées*). The sentence joins the pool used for that card. Like every sentence (Content → Content model), it is stored in full with its link: the blank is filled with the answer, eliding the word before it where French does.
- Users can add sentences but not new verbs, since a verb needs all 24 forms; new verbs arrive through content updates.

### Statistiques

Read-only, built entirely from the review log and sessions. A selector at the top filters to all drills or one drill.

| Block | What it shows |
| --- | --- |
| Aujourd’hui | cards reviewed, new cards learned, % correct, time spent |
| Rétention réelle | % of review-state cards answered correctly over the last 7 and 30 days, next to the target retention |
| Niveaux | number of cards at each mastery level (Nouveau → Maîtrisé) |
| Prévisions | cards due on each of the next 7 days |
| Temps | total time spent in the last 7 and 30 days |
| Sessions | past sessions, newest first: date, drill, duration, cards answered, % correct |
| Mots difficiles | number of leeches; tapping it opens the Liste de révision |

There is no calendar heatmap or “days in a row” count, since those work like streaks.

### Réglages

App-wide settings, in this order:

- **Rétention visée** — 80–97%, default 90%, with the one-line explanation from Spaced Repetition → Settings.
- **Réglages des exercices** — three entries: Genre, Vocabulaire, Conjugaison.
- **Mettre à jour le contenu** — checks for and installs a new content pack, with the installed content version and date underneath (see Content updates).
- **Thème** — Système / Clair / Sombre, default Système.
- **Rapport de plantage** — off by default, with a short French explanation (anonymous stack traces via Sentry, no personal data, no analytics). Can be switched at any time.
- **À propos** — opens À propos / Crédits.

### À propos / Crédits

App version, the MIT licence, a link to the GitHub repo, open-source licences of the packages used (Flutter's built-in licence page, which also lists Poppins's SIL Open Font License and py-fsrs's MIT licence), and the credits:

- **Images:** built from each image's source field.
- **Wiktionary** (CC BY-SA 4.0), through Kaikki.org and wiktextract, which the content is checked against.
- **Tatoeba** (CC BY 2.0 FR), where many sentences come from. Its licence asks for each author to be credited: the sentences table keeps every sentence's Tatoeba number and author, so this screen can list the authors, or the drill can name a sentence's author. Which one is the owner's call, in milestone 6.

The French wording comes from the owner.

## Activities

Phase 1 has three drills: Gender, Vocabulary and Conjugation. They share one card layout, one way of following an answer and one set of typing rules. Scheduling and grading are defined in Spaced Repetition; this section defines what the user sees and does.

### Starting a session

The home screen (Accueil) has one large **Commencer** button and, below it, three smaller tiles: **Genre**, **Vocabulaire**, **Conjugaison**.

- **Commencer** starts a mixed session. It builds one queue from all three drills, using the order in Spaced Repetition → Session flow, and interleaves drill types so the same word never appears in two drills back to back.
- A **drill tile** starts a session with that drill only.
- Under each tile, one line shows how many cards are due today (e.g. *12 à réviser*); when none are, there is no line. No other numbers are on the home screen.

### Shared drill behaviour

The three drills follow the same rules after an answer.

- **Layout:** prompt at the top, answer area below, one primary button in the thumb zone. The top bar shows only a close button (×), the number of cards answered this session (*1 carte*, *2 cartes*) and *Je le connais*. There is no progress bar, because a session has no target.
- **Trop facile:** on a word seen for the first time (its card is New), a *Trop facile* button sits above the answer buttons. It needs no answer: the card is rated Easy and the next card comes at once (see Spaced Repetition → Grading). It is not offered once the word has been answered, or on later reviews.
- **A Correct answer** moves straight on to the next card, with no feedback panel and no message.
- **Any other answer** — *Presque*, *Incorrect*, or *Je ne sais pas* — keeps the card in place, with what was answered, so nothing moves. Under it come the result, as a word with its icon as well as colour (*Presque*, *Incorrect*), and the correct answer with any error highlighted (*Réponse : …*). *Faute de frappe* (after *Incorrect* only) and **Suivant** take the places of the answer buttons. In the typed drills, there is no separate example sentence, since the card's own sentence is already on screen, and the keyboard closes while the answer box keeps its place.
- **Response time:** measured from the prompt appearing to the answer being submitted, and stored in the review log.
- **Snackbars** (*Je le connais*'s *Annuler*) float just above the answer buttons and accent bar, so the next answer can be given meanwhile, and go after 5 seconds.
- **Ending a session:** tapping × shows a one-screen summary (cards answered, % correct, duration) with a **Terminer** button. No praise, animation or comparison with earlier sessions.
- **Drill settings (all drills):** new cards per day, max reviews per day (see Spaced Repetition), and category weighting (Jamais / Moins / Normal / Plus; see Content → Category weighting).

### Je le connais (mark as known)

Every drill has a **Je le connais** button so a learner can drop words they already know in one tap. There is no placement test, so nothing is skipped on assumption: a word leaves practice only when the user says so.

- **Where:** a small text button at the top right of the card, shown in both the Question and Correction states. It is secondary to the main answer action.
- **Nouns:** marks the word known in every drill, so its Genre and Vocabulaire cards are both removed.
- **Verbs:** marks only the current verb × tense known (e.g. *être* at présent), because knowing one tense doesn't mean knowing the others. Other tenses of the verb stay in practice.
- **Effect:** the affected cards are never served again, in any session type, and don't count towards due counts, new-card limits or the Liste de révision. Their FSRS state is kept but frozen.
- **No grade:** marking a card known doesn't count as an answer, isn't in % correct, and writes no rating to the review log, so it never distorts FSRS or later optimisation.
- **Undo:** the next card appears at once, with a snackbar *Marqué comme connu · Annuler* for 5 seconds. There is no confirmation dialog, to keep it fast.
- **Bringing it back:** the Fiche mot or Fiche verbe has *Remettre en révision*. The card resumes with its previous FSRS state, or as a new card if it was never reviewed.

### Typing behaviour (Vocabulary and Conjugation)

- **The answer box sits in a sentence**, in place of the word to find, under the prompt. The box's line holds as many of the sentence's words as fit across the screen, and is centred; when they don't all fit, the words are taken from whichever side of the box is shorter, so the box stays as near the middle as it can, and the rest wrap onto lines above and below, centred. The box's line is in the middle of the space under the prompt when there is room, lower when the prompt and the lines above need it, and the card scrolls when it is all too tall. *? ! : ;* stay on the line of the word before them.
- **The box** is empty, with *Votre réponse* as its screen-reader label only. It is as wide for every word, so it never hints at the answer's length: about five letters of the sentence's font, and room for the ✗. It widens as the typing needs. The sentence and the typed text share one font size; a definition prompt is smaller, in body text.
- The box is focused and the keyboard open as soon as the card appears. Autocorrect, suggestions and auto-capitalisation are off. Enter submits, and keeps the keyboard open until the answer is graded; an empty answer cannot be submitted.
- **Buttons:** *Je ne sais pas* and **Valider** side by side under the sentence, *Valider* on the right; *Trop facile* above them on a new word.
- **Accent bar** above the keyboard: é è ê ë à â ç ù û î ï ô œ ’. Tapping a key inserts it at the cursor, keeping the keyboard open.
- **Live feedback** (setting "Correction en direct", default on): each letter is checked as it is typed against every accepted form of the answer, after normalisation.
  - A letter that matches is green and underlined.
  - A letter that is right apart from its accent is orange with a dotted underline.
  - Once any letter is wrong, all letters turn red and a ✗ icon appears inside the box, at its end. Deleting back to a correct prefix turns them green again.
  - Any red or orange letter during typing caps the grade at Hard, even if corrected before submitting.
- **Je ne sais pas** grades the card Again, logs error\_type gave\_up, and shows the answer, the box left as it was.

### Gender drill

- **Prompt:** the noun without an article (e.g. *table*), always shown. If the item has images and "Afficher l'image" is on (default on), one of its images is also shown, chosen at random on each review. There is no image-only mode: the drill tests gender, not recall of the word.
- **Answer:** large symbol tiles at the top of the card, as in the layouts: ♀ féminin, ♂ masculin, and ♀♂ les deux. All three are always shown, so the layout never hints at the answer. An unselected symbol is blue on the background; the chosen one sits on a filled teal tile with the symbol in yellow. Each tile has a screen-reader label (*féminin*, *masculin*, *les deux*).
- **"Les deux"** is only for nouns whose gender follows the person with no change of meaning (un/une élève, un/une enfant). Nouns whose meaning changes with gender (le livre / la livre) are two separate items. Each shows a short French gloss so the prompt is unambiguous.
- **After an answer:** the Shared drill behaviour applies — a correct answer moves straight on, and *Trop facile* is offered on a new word. A wrong answer's correction shows the word with *un/une* (never *l’*, which hides the gender), an example sentence with the noun in bold, and an optional "Astuce" line if the content has an ending rule (e.g. *-tion → féminin*). How the correction sits on the Gender card is settled with the drill, in milestone 4.

### Vocabulary drill

- **Prompt:** one of the item's images, chosen at random on each review. Seeing different pictures of the same word stops the user memorising one picture instead of the word. Its screen-reader label is *Image à nommer*, never the word. If the item has no image, the prompt is its short French definition (e.g. *Période de sept jours* → *semaine*), in body text.
- **The sentence:** under the prompt, one of the noun's sentences, chosen at random on each review, with the answer box in place of the noun (see Typing behaviour). Only sentences with the noun as it is typed count (*chat*, not *chats*; a synonym counts too), and every noun has one. It stays on screen for the correction.
- Every noun has a Vocabulary card, because every noun has an image or a definition.
- **Answer:** the noun typed in the singular, or in the plural for plural-only nouns (*les ciseaux*). The box takes the noun alone, since the sentence has its article.
- **Articles:** typing one anyway is optional. A right one is accepted: *le/la* or *un/une* by gender (either for a "les deux" noun), *l’* for a noun that takes it (never *le/la*), *les/des* for a plural-only noun. A wrong one with the right noun is graded Hard.
- **Synonyms:** the content data lists every accepted word for an item (e.g. *voiture / auto*). Any listed word is graded Good, each with the articles of its own gender and elision (*la voiture*, *l’auto*).

### Conjugation drill

- **Tenses in Phase 1:** présent, passé composé, imparfait, futur simple, the présent first (see Content → Phase 1 content). Conditionnel and subjonctif présent come in a later phase; the data model and settings must allow adding tenses without a schema change.
- **Prompt:** a sentence with the verb blanked out, with the answer box in its place (see Typing behaviour), and underneath it the infinitive and the tense, e.g. *Hier, nous \_\_\_\_ au cinéma.* · **aller** · passé composé. The subject is always in the sentence.
- **Elision:** the sentence is stored in plain French, and the prompt writes an elided word before the blank in full: *J’habite* → *Je \_\_\_\_*; *j’, m’, t’, s’, n’, c’* by themselves, and *l’* as the *le* or *la* the content says. As the user types, the word before the blank adjusts: if what they type starts with a vowel or a silent *h*, *je* → *j’*, *me* → *m’*, *te* → *t’*, *se* → *s’*, *ne* → *n’*, *le* / *la* → *l’*, *ce* → *c’*.
- **Answer:** only the verb, the words that fill the blank. Typing the subject pronoun too (*j’aime*) is wrong.
  - Compound tenses: auxiliary + participle, with agreement required by the sentence (*sommes allés*).
  - Reflexive verbs: include the reflexive pronoun (*me lève*, *m’appelle*), as their stored forms do.
  - Sentences for compound tenses are affirmative, so *ne…pas* never splits the answer.
- **After an answer:** the Shared drill behaviour applies, as in Vocabulaire.
- **Drill settings:** which of the tenses taught are on (all on by default), and which verb categories are included (-er, -ir, -re, irréguliers, plus the content's frequency categories).

### Content each item needs

| Item | Required fields | Optional fields |
| --- | --- | --- |
| Noun | word, gender (m / f / both), categories, level, one example sentence with the noun as it is typed, and at least one image **or** a short French definition | more images, accepted synonyms, gloss, ending-rule hint |
| Verb | infinitive, group, auxiliary, conjugated form per tense and person, at least one sentence per tense taught and person, categories, level | alternative forms (*je paie / je paye*) |

### Images

Official images are SVGs supplied by the project owner and stored in the database, not as asset files. This allows several images per word, and lets content updates add images without an app rebuild. Users can add their own pictures to their own words.

- **Storage:** an Image table (see Data model) holds the SVG markup or the file bytes and its format, linked to the item. An item can have zero, one or many images. In the content files, a noun's SVGs are in `content/images/<noun id without n.>/`.
- **Rendering:** flutter\_svg for SVGs, from the stored string; `Image.memory` for PNG and JPEG. Each image is decoded once per session and cached, so showing a card stays instant.
- **Artwork rules** for official images: square (1:1) viewBox, readable at 160 px, no embedded raster images, fonts or scripts, no text in the image, and legible on both light and dark backgrounds. Target under 20 KB each: over that is a warning, not an error, until the owner sets the real limit after drawing some images. "Readable at 160 px" and "legible on light and dark" can't be checked by a program, so they are left to whoever reviews the artwork.
- **Validation:** content import rejects any SVG that fails to parse or breaks these rules, and reports which item it belongs to.
- **User images:** on a Perso word, the user picks a picture through the system photo picker, which needs no permission prompt on iOS or modern Android. SVG, PNG and JPEG are accepted. The app re-encodes a raster image to at most 512 × 512 px and 200 KB before storing it, rejects anything it can't decode, and lets the user remove or replace it. User images are never sent anywhere and are skipped by the content merge.
- **Credit:** each official image has an optional source field, listed on the À propos / Crédits screen.

## Tech Stack

**Framework:** Flutter (stable channel), Dart.

**Target platforms:** iOS, Android. Web is a later phase.

**Minimum OS versions:** iOS 15+, Android 8.0 / API 26+.

**State management:** Riverpod (flutter\_riverpod, with riverpod\_generator for code-generated providers). Providers are also the app's dependency-injection mechanism — no separate service locator.

**Architecture:** Feature-first folder structure. Within each feature, a thin separation between data (Drift tables/DAOs), domain (FSRS scheduling, grading, normalisation — pure Dart, no Flutter imports, independently unit-testable), and presentation (widgets + Riverpod providers). The domain layer must be usable and testable with zero UI dependencies.

**Local persistence:** Drift, built on SQLite. Drift's reactive streams feed Riverpod providers directly, so UI updates automatically as cards, sessions, and review logs change.

**Spaced repetition:** a port of py-fsrs 6.3.2, per the Spaced Repetition section.

**Routing:** go\_router.

**Strings:** every word the app shows comes from two JSON files kept at the repo root: `strings/strings_fr.json` (the whole app) and `strings/strings_en_welcome.json` (the welcome screen, the one screen in English). The project owner edits these files; they are the source of truth for the app's wording.

In French, a drill is called an **exercice** everywhere the user can see it (*Réglages de l’exercice*, *Tous les exercices*). "Drill" is used only in this spec and in code identifiers.

- A small generator, `tool/gen_strings.dart`, turns them into a typed Dart class (`lib/core/strings.g.dart`) with a constant per key and a method per key that has placeholders. Widgets use that class and never contain literal text. Names join the key path in lowerCamelCase (`home.dueCount` becomes `Strings.homeDueCount`); keys starting with `_` are skipped.
- Placeholders are written `{n}`, `{version}`, `{date}`, `{size}`, `{drill}`, `{answer}`, `{word}`; `n` and `version` are `int`, the others `String`, pre-formatted by the caller. Each key becomes a typed method, so a wrong or missing argument, or a renamed key, fails at compile time; the generator itself rejects unknown placeholders, broken braces, empty text, non-text values, badly named keys, Dart reserved words and duplicate names.
- **Plurals** are two keys, `key_one` and `key_other`, chosen by `{n}` (*1 carte*, *2 cartes*). French uses `_one` for 0 and 1; English for 1 only. The two forms use the same placeholders apart from `{n}`.
- **Any new text means a new key first:** add it to `strings_fr.json` (in the section for that screen, following the existing naming), regenerate, then use it. Never hardcode a string, and never invent French wording in a widget.
- CI regenerates the file and fails if the result differs from what is committed, and a test checks that every key in the English file is used by the Welcome screen (it ships with that screen).
- Full Flutter intl/gen-l10n is deliberately not used: there is no second interface language planned, so it would be overhead without benefit. Material's own built-in text is still in French: `flutter_localizations` with the locale locked to `fr`, and iOS's development region `fr`.

**Testing:** flutter\_test for unit/widget tests, mocktail for mocking, integration\_test for end-to-end flows.

**Linting/formatting:** very\_good\_analysis, enforced via dart format --set-exit-if-changed in CI, with two rules off: `public_member_api_docs` (this is an app, not a library) and `unnecessary_type_name_in_constructor` (to keep the familiar `const HomeScreen({super.key})`). The Dart package is `bah_francais`. `build_runner` output is not committed, except `strings.g.dart`, which CI diffs.

**CI/CD:** GitHub Actions, on every pull request and every push to `main`, and by hand. A push to a branch with no pull request yet doesn't run CI, since running on both would build every PR commit twice. Flutter is pinned to one version (3.47.2). Four jobs:

- **Analyze, format, test:** the strings class is up to date, the content and the sample build packs, the format check, flutter analyze, and flutter test --coverage, with the domain layer's coverage at least 90% (`tool/check_domain_coverage.dart`); coverage goes to Codecov.
- **Build Android** and **Build iOS:** debug builds.
- **Integration tests (Android emulator):** `integration_test/` on an emulator.

`main` is protected by a ruleset that requires all four checks before a pull request can be merged.

**Error handling:** No analytics or ad SDKs. Crash reporting is the one exception to the no-tracking stance: Sentry, configured to scrub PII and device identifiers so it only ever reports stack traces — never used for behavioral analytics. It is off by default; the user opts in via a one-time prompt or a settings toggle, the same way the content download only happens when the user asks for it. Debug logs otherwise stay device-local.

**License / hosting:** MIT license (Colin Lubout), public GitHub repo, with a README (setup + architecture overview), CONTRIBUTING.md, and issue templates for bug reports and content suggestions. Semantic versioning with a CHANGELOG.md. The LICENSE and README exist from the start; CONTRIBUTING, the issue templates and the CHANGELOG come with the release pass (milestone 9).

### Development Principles

- **Clean interfaces** — small, single-responsibility widgets; presentation layer contains no business logic; domain logic (scheduling, grading) stays pure Dart so it can be tested without spinning up the UI.
- **Performance over design** — target a steady 60fps; avoid unnecessary rebuilds (const constructors, Riverpod select); app should be interactive in well under a second from launch, since near-zero friction to start a session is the whole point.
- **No user tracking** — no analytics and no ad SDKs, ever. The only exceptions to "nothing leaves the device" are the user-initiated content download and opt-in crash reporting (Sentry, PII-scrubbed, off by default) — both require the user to actively turn them on, never a background default. The content update is a plain download started by the user; it sends no identifiers or data.
- **Always available offline** — every feature works with no network connection; the only network use is user-initiated: the Mettre à jour le contenu download and opt-in crash reporting.
- **Open source** — MIT-licensed, public repo, documented well enough for an outside contributor to build and run it from the README alone.
- **Testing rigor (high)** — unit tests for all domain logic (FSRS wrapper, grading, answer normalisation) at ≥90% coverage; widget tests for every screen; integration tests for core flows (complete a full drill session, force-close mid-session and confirm no data loss). CI enforces all of this on every PR.

### Design Principles

- **Visual style:** Minimal Material 3. Native, platform-consistent components with light custom theming — fast to build, accessible by default, and deliberately calm rather than branded or attention-grabbing.
- **Light and dark mode:** both supported, following the system setting by default.
- **No engagement engineering in the visuals:** no mascots, confetti, streak counters, or celebratory animations. Motion is minimal and purposeful — e.g. a subtle transition when a card is answered — nothing designed to trigger a dopamine loop.
- **Accessibility:** respects OS text-scaling; WCAG AA color contrast; color is never the sole signal — the green/red typing feedback needs a secondary cue (underline or icon) for colorblind users; all interactive elements have screen-reader labels.
- **Layout:** one primary action visible at a time during drills, generous whitespace, designed for one-handed thumb use — consistent with "pick it up for 30 seconds in a spare moment."
- **Edge to edge on every Android version:** the status and navigation bars are transparent, with icons that follow the theme. Android 15+ requires this anyway.
- **Tablets:** iOS builds for iPhone only, and iPads run it in phone-compatibility mode; on Android tablets the layout stays in a centred column 480 dp wide.

### Color scheme

Three brand colours, from the Layouts document: teal for actions, yellow for the chosen or highlighted thing, and blue, which also gives the dark theme its background. Colour carries meaning here (which answer is selected, whether an answer was right), never decoration.

| Colour | Hex | Role | Text on it |
| --- | --- | --- | --- |
| Turquoise | #6EC9C8 | primary: the main button (Continuer), the selected answer tile, filled indicators | **Navy #14334C** (6.8:1). Never white, which fails at 1.9:1 |
| Jaune | #FACD3F | the symbol or label inside a selected tile, and small highlights | navy (8.6:1); never yellow text on white (1.5:1) |
| Bleu | #5172A1 | unselected answer symbols, secondary icons, links | white (4.9:1); as text it needs a light background |
| Navy | #14334C | the dark theme's background, and text on teal or yellow | white text on it reads at 13:1 |

- **Light theme:** plain white background, with no gradient anywhere, matching the dark theme's plain navy. Text is navy.
- **Dark theme:** navy #14334C background, white text, teal and yellow keep their values. Bars and cards are slightly lighter shades of navy. The blue is only used on light backgrounds, since it nearly disappears on navy (2.7:1); use #8FB0DB in its place there, with navy text on it (5.9:1).
- **Generating the theme:** `ColorScheme.fromSeed(seedColor: Color(0xFF6EC9C8))` for light and dark, then override `primary` (teal), `onPrimary` (navy), `tertiary` (yellow), `secondary` (blue / #8FB0DB) and the dark `surface` (navy) with the exact values. Do not enable Android dynamic colour, so the brand and feedback colours always sit on predictable backgrounds.
- **Feedback colours** are separate from the brand, fixed, and defined once as a `ThemeExtension`:

| Role | Light | Dark | Used for |
| --- | --- | --- | --- |
| Correct | #1E7A3C | #6FD08C | correct letters, *Correct* result |
| Accent only | #A6520A | #F5B35C | letters right except for the accent, *Presque* result |
| Wrong | #C0362C | #FF8F80 | wrong letters, *Incorrect* result |

- **Contrast:** feedback colours measure 5.4:1 to 5.5:1 on white and 5.9:1 to 7.1:1 on the navy background, meeting WCAG AA. A widget test checks every text and background pair in both themes.
- **Keeping feedback distinct:** the brand yellow is never used near the answer field, so it can't be confused with the orange *accent only* colour. No red or green outside answer feedback, so red always means a wrong answer.
- **Never colour alone:** feedback always carries its cue from Activities (solid underline, dotted underline, ✗ icon, result word), and a selected answer tile is marked by its filled shape, not only by colour.

### Logo, icon and splash

- **Logo:** the cartoon character above the *BAH!* / *FRANÇAIS* wordmark, supplied as PNG and SVG by the project owner. It appears on the Welcome screen and the launch screen only; no header on other screens carries it.
- **Launch screen:** the logo centred on a plain background, with no gradient: white in light mode, navy #14334C in dark mode. On iOS and Android 8–12 it follows the phone's light/dark setting from the first launch: the OS draws the launch screen before the app runs, so only Android 13+ can follow the app's own *Thème* setting, which it does once that setting exists. On Android 12+ the system crops the launch image to a circle, so it shows the character alone.
- **App icon:** the character alone on a plain background, without the wordmark, which is unreadable at icon size. Supplied in the sizes both stores need, with an Android adaptive-icon foreground and background layer.
- **Until the real assets arrive,** the app icon and the launch logo are a plain teal square. The files and sizes needed are listed in `assets/branding/README.md`.
- The logo is decorative, so it carries a screen-reader label of *BAH Français* and is not read out twice.

### Typography

The whole app uses **Poppins** in three weights, taken from the Layouts document. The font files (Light 300, Regular 400, Bold 700) come from Google Fonts' repository (google/fonts) and are bundled as assets, not fetched at runtime, so the app stays offline; their SIL Open Font License is bundled and listed on the licence page.

| Weight | Used for | Example from the layouts |
| --- | --- | --- |
| Light 300 | the display and large headline roles (all 28 sp or more), and the main button label at 22 sp | *chien*, *continuer* |
| Regular 400 | everything else: body text, list rows, the answer field, screen titles | *C’est un bon* |
| Bold 700 | `titleMedium` (the result word), and an emphasis style for the target word inside an example sentence and emphasis in lists | **chien** |

- Map these onto the Material 3 `TextTheme` once, in the theme, with a theme-level emphasis style for the bold word in a sentence; widgets never set a font weight directly.
- Light is only used at 16 sp or larger, since thin strokes are hard to read at small sizes.
- All sizes follow the OS text-scaling setting.

## Build plan

Build in the order below, one milestone at a time. Each milestone ends with its checks passing and a commit; nothing from a later milestone starts before an earlier one is done. The order puts the logic that has to be right first, and the screens on top of it.

### App identity

| Item | Value |
| --- | --- |
| Display name | BAH Français |
| Bundle / application id | com.bahfrancais.app (never changed after the first release: stores treat a new id as a different app) |
| Repo | public GitHub repo, MIT (see Tech Stack) |
| Orientation | portrait only |
| Devices | phones; tablets run the phone layout centred, and are not a design target (see Design Principles) |
| Backups | the database is included in iCloud and Android backups, so a new phone keeps the user's progress |

### Milestones

| # | Milestone | Done when |
| --- | --- | --- |
| 0 | Project setup: Flutter app, feature-first folders, Riverpod, go\_router, lints, CI, theme (colours, Poppins), the strings files and their generator, app icon, launch screen | CI is green, `flutter analyze` and the format check are clean, and the app launches to an empty Accueil in both themes |
| 1 | Domain core, pure Dart: FSRS wrapper, grading and answer normalisation, the queue builder (session flow, daily limits, weighting, known and Jamais exclusions), mastery levels, injectable clock | every acceptance criterion in Spaced Repetition has a passing test; domain coverage ≥ 90%; no Flutter import in the domain layer |
| 2 | Data layer: Drift tables for cards, logs, sessions, content and images; DAOs and streams; migrations; plus the content validator and pack builder in `tool/`, and the sample content set | the sample pack builds, imports and reads back unchanged; the validator rejects each rule it enforces, with a test per rule |
| 3 | Vocabulaire drill end to end: card screen, typing rules, accent bar, live feedback, Je ne sais pas, Je le connais, the correction, session summary; the everyday pack bundled and imported on first launch, and the drill's tile on Accueil | an integration test completes a session; a force-close mid-session loses no answered card; widget tests cover each drill state |
| 4 | Genre and Conjugaison drills, the rest of Accueil, and the mixed session | each drill has the same test coverage as milestone 3; a mixed session interleaves drills and respects each drill's limits |
| 5 | Mots, Fiche mot, Ajouter un mot with the image picker, Verbes, Fiche verbe, Ajouter une phrase | a user-added word appears in both drills; a user-added sentence is used by its card; images are stored, shrunk and rendered |
| 6 | Liste de révision, Statistiques, Réglages, the three drill settings screens, Welcome, À propos | every setting changes behaviour from the next card; stats match the review log in a test with seeded data |
| 7 | Content updates: manifest, download, checksum, merge rules, the bundled pack after an app update | every merge rule has a test; a failure mid-merge leaves the content untouched; user data is never modified |
| 8 | Content: the passé composé, imparfait and futur simple, and the lists grown to 30 verbs and 100 nouns (Content → Phase 1 content) | the content teaches all four tenses with 30 verbs and 100 nouns, passes the validator, and the owner has checked it |
| 9 | Release pass: accessibility (text scaling, screen-reader labels, contrast test), performance (interactive in under a second, steady 60 fps), French text reviewed by a fluent speaker, CONTRIBUTING, issue templates and CHANGELOG, privacy policy published and both stores' privacy forms completed | the release checklist in the README is fully ticked |

### Privacy and store compliance

Both stores ask what an app collects before it can be published, even when the answer is nothing. Prepare these in milestone 9:

- **Privacy policy:** a page on GitHub Pages, linked from both store listings and from À propos. It says the app stores everything on the device, collects nothing, has no accounts and no analytics, that content updates are downloads the user starts, and that crash reports are off unless the user turns them on, PII-scrubbed, and processed by Sentry.
- **Apple privacy labels:** *Data Not Collected* while crash reporting is off by default; if the labels must cover the opt-in path, declare Diagnostics, not linked to identity, not used for tracking.
- **Google Play Data safety form:** the same answers, with crash logs marked optional and explained.
- **No advertising identifier** is requested, and the Android `AD_ID` permission is removed from the merged manifest.
- **Android permissions:** the merged manifest is checked at this milestone, so it holds only `INTERNET` (used by the content download and, when enabled, crash reports). The photo picker needs no permission.
- **Store listing:** French and English descriptions, screenshots in both themes, the app icon, and a content rating questionnaire (the app has no user-generated content shared between users).

### How Claude Code should work

- **One milestone per branch and pull request**, with its tests. Do not start the next milestone in the same PR.
- **Keep `PROGRESS.md`** at the repo root: the current milestone, what is done, what is left, and any decision taken along the way. Update it at the end of every session.
- **Keep this spec current.** It lives in the repo and is the source of truth. When it is wrong, incomplete, or doesn't fit what the code needs, stop and ask the owner. Once a decision is agreed, record it under Decisions in `PROGRESS.md` (dated, with what was agreed and why) and fold it into this spec in the same pull request. Never change specified behaviour without the owner's agreement, and never rewrite a requirement to match what was built.
- **All user-facing text comes from the strings files** (see Tech Stack → Strings). Adding a screen or a message means adding keys to `strings/strings_fr.json` first, then using the generated class. No literal text in widgets.
- **Ask instead of guessing.** If the spec doesn't answer something, stop and ask, record the answer in `PROGRESS.md`, and fold it into this spec. Do not invent a behaviour and move on.
- **Build only what the spec describes.** No extra features, screens, settings or engagement mechanics, however small.
- **Never invent French content.** Only the sample set may contain words and sentences, and they are marked as samples. Real content comes from the project owner, except the everyday categories, which Claude Code drafts for the owner to check (see Content → Phase 1 content); run `tool/dictionary_check.dart` on a draft before handing it over.
- **Run `flutter analyze`, the format check and the full test suite** before calling any milestone done.
- **Tests come with the code**, in the same PR, not in a later clean-up pass.
