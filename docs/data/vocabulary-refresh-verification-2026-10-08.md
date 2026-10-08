# Vocabulary refresh verification — 2026-10-08

## Shipped data

JMdict English snapshot dated 2026-10-07; OpenJLPT commit `0d1d3410bec90bd4098a7c72de820543cb4f707c`. Input hashes: `data/vocabulary/sources.json`. Dictionary-derived glosses and metadata ship locally; no app network calls or imported source examples.

| Community level | Study entries |
|---|---:|
| N5 | 690 |
| N4 | 634 |
| N3 | 1,710 |
| N2 | 1,809 |
| N1 | 3,143 |
| Total | 7,986 |

Catalog SHA-256: `daaa7d255a34ff8ac1614e819ee182622c3be9b21834cff69a4f70a765af62ab`.
A repeat builder run from pinned snapshots produced identical bytes.
Original CSV remains unchanged: 8,130 legacy slots, 7,393 confidently mapped and 737 retired slots. There are 1,098 excluded candidate rows across the two sources; detailed causes and included provenance are in `data/vocabulary/report.json`. Different study senses retain separate catalog identities. Retired learner records remain usable with their saved meanings.

JLPT tags are community estimates, not an official vocabulary syllabus. Matching is conservative automated analysis plus recorded overrides, not a claim of manual review of every word. Ambiguous mixed glosses such as グラス/glass–grass, ビル/building–bill and バット/bat–VAT are excluded rather than forced into an unrelated entry. いっぱい/full and いらっしゃい/welcome select their intended source senses; 開ける/open and 明ける/dawn remain distinct.

## Automated checks

- 14 builder tests pass, including restricted readings, inherited POS, overrides, homographs and selected-sense identities.
- 105 Swift workspace tests pass; XcodeBuildMCP reports zero warnings/errors.
- Debug app build/run and Release simulator build pass.
- Full shipped catalog loads through Swift validation, including distinct source code-point forms that compare canonically equal in Swift.
- Migration failure/recovery-write failure rolls back; current versions are idempotent and future versions reject without mutation.
- Stale study updates preserve migrated anchors. Failed updates preserve content and AI advice. Successful changed-context updates invalidate only advice.
- Current-anchor deletion uses current catalog level; retired deletion preserves cursor.
- Legacy backups validate their old catalog before conversion. Restore preview and progress shadow use converted cursors; current backups validate after restore/restart.
- Add next skips prior-day saved catalog identities even when learner UUIDs differ.
- Metadata loading does not change study context; ambiguous matches cannot become replacements. Review continues to use saved study meanings and hide answers until reveal.
- `git diff --check` passes.

## Existing simulator store

Before installation, copied a consistent SQLite backup and field snapshot under `/private/tmp/kotoba-pre-vocabulary.*`.
After the actual app upgrade, compared the three saved word rows, two kanji rows, one progress row and one review row. All prior learner content, IDs, dates, counters, AI advice and review state matched. Word anchors changed to current identities/indexes; catalogVersion became 2 and cursor became 3. The original version-1 recovery export exists at `Application Support/Backups/vocabulary-v1-recovery.json` with the original collection.

Add next added 青い at current slot 3 with a new learner UUID, preserving the old three records. Inspected all visible dictionary sense groups, restrictions, readings and written forms in light mode. Dark mode with accessibility XXXL text wraps long definitions and labels without horizontal clipping. Simulator appearance restored to light/large afterward.

## Verification limits

Simulator: iPhone 17 Pro, iOS 27. This is not a device-release or iOS-18 runtime claim. Explicit update/restore confirmation sheet paths are validated through domain/repository/view-model tests; native navigation automation was unreliable, so no additional end-to-end UI claim is made for those actions. No VoiceOver or TestFlight check was requested. Git delivery was subsequently authorized on 2026-10-08; the delivery PR records commit and merge status.
