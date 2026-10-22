# Content

The words, verbs and sentences the app teaches, as JSON files that
`tool/content_build.dart` validates and turns into a content pack.

- `tenses.json`: the tenses the content teaches. Verbs keep all 24 forms, but
  only these tenses get Conjugaison cards and need sentences.
- `grammar.json`: the grammar concepts sentences are tagged with, each at the
  CEFR level (A1 to B2) courses usually teach it, and `max_level`, the highest
  level the sentences may reach. Each sentence lists its concepts (`grammar`)
  and its `level`, that of its hardest concept.
- `verb-categories.json`: every verb category.
- `nouns/<category>.json`: one noun category and its nouns.
- `verbs/<verb>.json`: one verb and its 24 forms.
- `sentences/<name>.json`: sentences in plain French, each listing the verbs it
  is a Conjugaison prompt for and the nouns it is an example of. One sentence can
  serve several. Which file a sentence is in doesn't matter to the app.
- `images/<noun id without n.>/`: a noun's SVG images.
- `schema/`: the JSON Schema of each kind of file. The validator checks the
  files against them first, then the rules beyond them (see
  `tool/src/content/content_validator.dart`).
- `sample/`: a small sample set for development and tests. It never ships.

Validate the content and build its pack (from the repo root):

```bash
dart run tool/content_build.dart content
```

The app bundles this pack and imports it on first launch. After changing the
content, rebuild the bundled copy, or a test fails:

```bash
dart run tool/content_build.dart content --version 1 --out assets/content/content-pack.sqlite
```

Tag new sentences with their grammar concepts and level first. Tags already
in a file are kept, and where the detection disagrees with them it says so:

```bash
dart run tool/grammar_tag.dart content
```

## Checking against Wiktionary

`tool/dictionary_check.dart` compares the content with Wiktionary: each
noun's gender and plural-only, each synonym's gender, and each verb's
auxiliary and 24 forms. It lists where they disagree, and notes such as a
variant form the content doesn't accept. Wiktionary can be wrong too, so a
disagreement is something to look at, not an automatic fix. It can't check
*h aspiré*, which this data doesn't mark.

It also checks the words of the sentences (decision 64): a sentence uses only
the content's nouns and verbs, conjugated in a tense it teaches, with no
infinitive straight after a conjugated verb. It goes by each word's parts of
speech in Wiktionary, so what it lists is to look at, not a sure mistake.

It needs Kaikki.org's French dictionary, a large download kept out of the
repo:

```bash
mkdir -p data/kaikki
curl -L -o data/kaikki/kaikki.org-dictionary-French.jsonl \
  https://kaikki.org/dictionary/French/kaikki.org-dictionary-French.jsonl
dart run tool/dictionary_check.dart content
```

## Sources and credits

Most sentences come from [Tatoeba](https://tatoeba.org), a collection of
sentences and translations available under the
[Creative Commons Attribution 2.0 France licence](https://creativecommons.org/licenses/by/2.0/fr/)
(CC BY 2.0 FR). Only sentences written in French by native speakers are used,
not translations. Each one keeps its Tatoeba number and its author in its
`credit`, and its id is `s.tatoeba.<number>`: the sentence is at
`https://tatoeba.org/fr/sentences/show/<number>`. Their apostrophes are made
typographic (’) and a space is put before *? ! : ;*, as in the rest of the
content; nothing else is changed. Sentences without a `credit` were written
for this app.

The content is checked, and drafted, against
[Wiktionary](https://www.wiktionary.org), whose text is available under the
[Creative Commons Attribution-ShareAlike licence](https://creativecommons.org/licenses/by-sa/4.0/),
through the machine-readable [French dictionary at Kaikki.org](https://kaikki.org/dictionary/French/),
extracted with wiktextract (Tatu Ylonen, *Wiktextract: Wiktionary as
Machine-Readable Structured Data*, LREC 2022). Nothing is copied from it:
the definitions are written for this app.

## Status

**Checked by the owner on 2026-10-22.** A small first pack (decision 62 in
`PROGRESS.md`): the present only, A1 grammar only (decision 65), with the
everyday categories *Les essentiels* (10 nouns) and *Les verbes essentiels* (6
verbs), drafted by Claude Code (decision 57). Of their 72 sentences, 45 are from
Tatoeba, 11 are the owner's own wordings, and 16 were drafted for the verb forms
nothing else fits (decisions 61, 64 and 65). Every word, gender, form, sentence,
link and grammar level was checked by the owner; anything added or changed is
checked again before it ships.

- The nouns have definitions and no images yet.
- `rank` orders the words within the everyday set, most useful first. It is an
  estimate, not a corpus frequency rank.

The other three tenses, and lists of 30 verbs and 100 nouns, come in milestone 8
(decision 63).
