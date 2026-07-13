# Prompt: Audit YDS Master word database for translation & example sentence quality

You are auditing a Turkish-English vocabulary database (`words.json`) used in an
iOS exam-prep app for YDS/YÖKDİL (Turkish English-proficiency exams). The file
is a JSON array of ~5,000 entries with this shape:

```json
{
  "id": 331,
  "englishWord": "way",
  "turkishMeaning": "yol",
  "partOfSpeech": "noun",
  "difficultyLevel": 1,
  "category": "academic-nouns",
  "ydsFrequencyRank": 316,
  "exampleSentenceEN": "There are several ways to solve this problem.",
  "exampleSentenceTR": "Bu sorunu çözmenin birkaç yolu vardır.",
  "synonyms": ["..."],
  "confusingWords": ["..."]
}
```

## Your task

Go through the file **in batches of 100 entries** (it's too large for one pass)
and for each entry, check:

1. **`turkishMeaning` accuracy** — Does it correctly translate `englishWord`
   for the given `partOfSpeech`? Flag if it's the wrong word entirely (e.g.
   "way" translated as "uzak" — that means "far", not "way"), a false-friend
   mistranslation, or just an unnatural/uncommon rendering a native speaker
   wouldn't use.
2. **`exampleSentenceEN` quality** — Is it a natural, grammatically correct
   English sentence that actually uses `englishWord` in a clear, exam-relevant
   way? Flag placeholder/templated junk (e.g. sentences that talk *about* the
   exam or the word itself instead of using it naturally, like "Many exam
   questions test whether students can use the verb 'X' correctly" or
   "Several scholars argue that the X is essential for cognitive
   development").
3. **EN↔TR sentence correspondence** — Does `exampleSentenceTR` actually
   translate `exampleSentenceEN`? Flag any pair where the two sentences are
   about different content (this happened before — an entry for "promote"
   had an English sentence about verb testing and an unrelated Turkish
   sentence about scientists and physical systems).
4. **Duplicate/near-duplicate template sentences** — Flag if you see the same
   sentence skeleton reused across many unrelated words (a sign of
   lazy/broken generation), even if not caught by #2.

## Output format

For each batch, output **only the entries with problems**, in this format:

```
id=331 englishWord=way
  ISSUE: turkishMeaning
  found: "uzak"
  suggested: "yol"

id=159 englishWord=promote
  ISSUE: EN/TR mismatch
  found EN: "..."
  found TR: "..."
  suggested EN: "..."
  suggested TR: "..."
```

If a batch has zero issues, just say `Batch N (ids X–Y): clean.`

At the end, give a total count of entries flagged and a breakdown by issue
type (wrong meaning / bad example / EN-TR mismatch / templated junk).

## Constraints

- Do not touch or restate entries you're confident are correct — only report
  problems, to keep output short across ~50 batches.
- Prefer natural, exam-register English (formal/academic tone fits this
  app's context — YDS is an academic English exam).
- Turkish translations should use standard, dictionary-accurate meanings —
  not overly literal or obscure alternatives.
- Do not modify `id`, `partOfSpeech`, `difficultyLevel`, `category`,
  `ydsFrequencyRank`, `synonyms`, or `confusingWords` — only flag issues in
  `turkishMeaning`, `exampleSentenceEN`, and `exampleSentenceTR`.
