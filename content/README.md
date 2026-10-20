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

## Status

**Draft, not yet checked.** The everyday categories, *Les essentiels* (30 nouns)
and *Les verbes essentiels* (10 verbs), with their 269 sentences, were drafted
by Claude Code for the owner to check (decision 57 in `PROGRESS.md`). Every word,
gender, form and sentence, and every link from a sentence to a verb or noun,
must be checked by a fluent French speaker before it ships.

- The nouns have definitions and no images yet.
- `rank` orders the words within the everyday set, most useful first. It is an
  estimate, not a corpus frequency rank.

The topic categories come with the rest of the content in the final milestone.
