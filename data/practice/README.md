# Original beginner practice content

This corpus is original, model-authored material. Model/rule checks and a separate model code/content review have been performed. Independent human Japanese language review is pending. The app discloses this status; a content hash verifies integrity, not linguistic correctness.

## Files and regeneration

- `authored-drafts.json`: explicit answers, token orders, contexts and listening material.
- `validation-evidence.json`: model/rule validation evidence bound to the canonical draft hash. It must not name an invented human reviewer.
- `review-packet.md`: a readable checklist of every question/context from the current draft, with a SHA-256 of the exact draft bytes.
- `../../Frameworks/DataKit/Resources/applied-practice.json`: generated bundle, containing question fingerprints and validation evidence.

Run from the repository root:

```sh
python3 tools/data/prepare_practice.py
python3 tools/data/prepare_practice.py --check
python3 -m unittest discover -s tools/data -p 'test_*.py'
```

The exporter rejects changed drafts whose validation evidence is stale. Review all changed answer-bearing fields before replacing evidence. Increment an item's revision when its intended question, answer or teaching explanation changes. Never edit only the generated bundle. Existing ReadingCatalog items use their original IDs/fingerprints; listening counterparts use separate IDs.

## Human language acceptance

A competent Japanese reviewer should read `review-packet.md`, mark each item accepted or list corrections by stable ID, and record their name, date, scope and the exact reviewed draft hash in a separate review report. Do not mark pending human acceptance complete without that report. A reviewer may add natural alternate orders; do not infer that every unlisted Japanese order is ungrammatical.

Check:

- Conjugation: word class, reading, meaning, requested register/form, written and kana variants, 行く/ある/いい exceptions, する/来る, and misleading explanations.
- Sentences: particles, natural meaning, predicate-final instruction, all reasonable phrase orders, repeated identical tokens, and explanations after Check. Flag ambiguity rather than forcing one order.
- Contexts: exact dictionary headword/reading/selected meanings, a single cloze that hides the answer, natural sentence/translation, and no unintended alternate fill that changes the tested sense.
- Listening: natural Japanese and kana reading, faithful English translation, a uniquely defensible correct choice, plausible distractors, and no feedback that reveals an unanswered question. Transcript reveal makes remaining passage questions ungraded.

Any content correction requires updated draft/evidence, deterministic export, and full validation. Keep the source's pending-human-review disclosure until actual acceptance is recorded and the publication policy is explicitly updated.

## Device acceptance still pending

On a physical iPhone, check Japanese passage audibility in silent mode, stop/replay, interruption/background handling, unavailable voice, and successful playback before Check. At the largest accessibility text size, scroll to every sentence token and listening action, verify back navigation, and avoid submitting QA ratings into a real learner collection. VoiceOver and TestFlight checks were deferred by the user.
