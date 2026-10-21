# Content

The words, verbs and sentences the app teaches, as JSON files that
`tool/content_build.dart` validates and turns into a content pack.

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

## Checking against Wiktionary

`tool/dictionary_check.dart` compares the content with Wiktionary: each
noun's gender and plural-only, each synonym's gender, and each verb's
auxiliary and 24 forms. It lists where they disagree, and notes such as a
variant form the content doesn't accept. Wiktionary can be wrong too, so a
disagreement is something to look at, not an automatic fix. It can't check
*h aspiré*, which this data doesn't mark.

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
(CC BY 2.0 FR). Each one keeps its Tatoeba number and its author in its
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

**Draft, not yet checked.** The everyday categories, *Les essentiels* (30 nouns)
and *Les verbes essentiels* (10 verbs), were drafted by Claude Code for the owner
to check (decision 57 in `PROGRESS.md`). Their 383 sentences are from Tatoeba,
except 17 drafted for the verb forms Tatoeba has no suitable sentence for
(decision 61). Every word, gender, form and sentence, and every link from a
sentence to a verb or noun, must be checked by a fluent French speaker before it
ships.

- The nouns have definitions and no images yet.
- `rank` orders the words within the everyday set, most useful first. It is an
  estimate, not a corpus frequency rank.

The topic categories come with the rest of the content in the final milestone.
