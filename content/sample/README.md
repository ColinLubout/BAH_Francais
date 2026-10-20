# Sample content

**Samples only: this content must never ship.** It exists for development and
tests, and is replaced by the real content, checked by a fluent French
speaker, before release.

It is small but uses every part of the content format:

- `verb-categories.json`: two verb categories, one of them the everyday set.
- `nouns/`: three noun categories of ten nouns, one of them the everyday set.
  Between them: all three genders, nouns taking *l’*, a plural-only noun, words
  starting with *h muet* and *h aspiré*, synonyms with their own gender or
  elision, a noun in two categories, an ending hint, and images with and
  without a credit.
- `verbs/`: five verbs with every form, including a reflexive verb, alternative
  forms (*paie* / *paye*) and a verb starting with *h*.
- `sentences/`: a sentence for each noun and for each verb's tense and person,
  with agreement in the passé composé, elided words before a verb (*j’*, and an
  *l’* that says `le`), and sentences that serve both a verb and a noun.
- `images/`: simple placeholder drawings, one folder per noun.

Validate it and build its pack (from the repo root):

```bash
dart run tool/content_build.dart content/sample
```
