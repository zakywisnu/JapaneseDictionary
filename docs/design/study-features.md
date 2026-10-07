# Study features specification

Approved scope: collection review, an Again queue, spaced repetition, bundled example sentences, and local backup/restore. Implementation order follows the plan in `docs/superpowers/plans/2026-10-06-study-features.md`. Collection practice, Again, due scheduling and local backup/restore are implemented on codex/study-features. Example loading and presentation are implemented with zero approved sentences; publishing content still requires fluent human review.

## Collection practice

Collection offers Review words / Review kanji above its rows after successful loading. A small setup sheet chooses all collected items or a single JLPT level and a limit of 10, 20 (default), or all. Search continues to filter browsing; review has its own explicit level filter so hidden search state cannot silently change a session. Show the number selected before starting. Sort newest-first with a stable saved-ID tie-break. Snapshot saved content, excluding deleted items only when starting the next session. Empty selection offers change-level/return actions. Today retains its current review entry.

## Again queue

After reveal, two explicit actions replace Next: Again and Got it. Again places the current item at the end of the queue; Got it removes it. If only one item remains after Again, hide its answer and offer the same item again. Position copy reads “3 remaining”; it does not claim mastery or count unique words twice. Completion reports distinct items practiced and repeat attempts separately. Native back exits without confirmation; the queue is in memory. Remove Previous during this rated queue mode so already consumed ratings cannot be silently changed. Both practice entry points use this temporary queue; no scheduling changes occur outside the dedicated due-review mode.

## Due review

Today adds a clearly labeled Due for review section for the selected kind, separate from “added today.” Unrated collected items are due immediately. Due review snapshots the oldest due items, with saved ID as the tie-break, and uses the Again queue. A simple transparent schedule advances successful reviews through 1, 3, 7, 14, and 30 calendar days (then remains at 30). Any Again within a session resets that item's next interval to one day; repeated Got it for the same item/session never advances multiple stages. Inject Date and Calendar; compute due at local start of day. No claim that this schedule measures mastery or is optimal.

Persist each rating successfully before advancing the UI. Use a session UUID and item ID to make retries idempotent, retaining the session's baseline stage and whether Again occurred. Saving errors keep the answer visible with Retry/Exit. Backgrounding keeps in-memory queue state; termination ends the queue but retains saved schedules. Existing collection counts, Add next indexes, and original dates remain unchanged. Deleting an item removes its schedule; re-adding starts unrated. A completed due session cannot restart its old snapshot; start a new session from the current due list. No reminders or notifications in this scope.

## Examples

Use only an approved N5 subset from the downloaded Tatoeba candidates, one example per covered word initially. A fluent Japanese reviewer checks the target meaning, naturalness, English translation, learner suitability, and any reading supplied. Missing approval means no example card. Examples appear on Detail and after reveal in Review, never in recall. Show Japanese and English; show reading only if verified. A neutral Sources screen includes bundled license/attribution text; the app requires no live fetch. For kanji, do not pretend character occurrence teaches a particular reading: sentence examples initially apply to vocabulary only. Retain both sentence IDs, source URLs, owners/credits, modification details, and source snapshot checksum.

## Local backup and restore

Progress offers Export backup and Restore backup. Export one versioned JSON document using the system file exporter; include saved word/kanji values, IDs, dates, added indexes, WordsProgress fields, schedules, and relevant app preferences. Do not include the bundled dictionary/example corpus or device identifiers. User-selected storage may be provided by Files; this app adds no account or sync.

Restore first decodes and validates the entire document without touching live data. Show item counts, backup date, and a clear explanation that restore replaces the current collection and schedules. Apply only after explicit confirmation. Use a dedicated ModelContext with autosave disabled and one save; rollback on any failure. Create a recoverable pre-restore backup first, abort if that fails, and restore preferences only after the data save. Reload Today, Collection, Progress and discard active review sessions. Cancel is a no-op. Reject unsupported future formats, duplicate IDs, invalid enums/dates, orphan schedules, and mismatched catalog indexes; never clamp silently. Include a catalog fingerprint for safe compatibility checks. No merge-import in the first version.

## Shared constraints

- Local only: no account, backend, sync, runtime downloads, or network-dependent UI.
- iOS 18, Swift 5, Tuist-generated projects.
- Forest tokens, shared components, Mincho headwords, system text styles, native routing.
- Preserve stable bundled order and saved Add next semantics.
- Tests must protect existing store data, scheduling idempotency, and restore atomicity.
- Inspect light, dark, accessibility-large text; honor Reduce Motion. VoiceOver testing remains deferred as requested.
