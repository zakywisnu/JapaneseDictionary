# Broader study material and difficult-item practice

Date: 2026-10-08
Status: implemented and verified on 2026-10-10. See docs/implementation/broader-study-verification.md.

## User intent

The learner wants difficult-item practice and an app that supports more than vocabulary and kanji. They explicitly selected both custom study cards and bundled lessons. The app remains entirely offline, without accounts, a backend, runtime downloads, or sync. Existing saved words, kanji, lists, schedules, goals, and backup compatibility must survive the expansion. VoiceOver and TestFlight work remain deferred.

## Chosen approach

Add a shared saved-study identity and rating path for words, kanji, grammar lessons, sentence cards, and custom cards. Keep each content type's appropriate presentation and storage rather than forcing grammar explanations into a word model. Reuse the current reveal / Again / Got it interaction, calendar-day scheduler, local goal, and Forest design system.

Alternative: independent lesson and custom-card review systems. This duplicates ratings, goal accounting, difficult-item handling, and backup behavior. Alternative: user-created cards only. This is smaller but does not satisfy the user's choice of bundled lessons as well.

Implementation proceeds in dependent phases: shared identity/rating storage, custom cards and mixed lists, bundled lessons, then integrated UI and verification. A later implementation plan defines file ownership and whether independent parts warrant subagents. No runtime content service is introduced.

## Content and provenance

### Custom cards

Create, edit, and remove local cards with a required prompt and answer, optional kana reading, optional notes, optional JLPT level, and a category: grammar, sentence, kana, or other. The category describes the card; it does not create separate identity namespaces. Every card has a stable UUID string, creation date, and edit date. Limit prompt to 500 characters, answer to 4,000, reading to 500, and notes to 4,000. Trim required fields and reject empty values; optional blank fields become absent. Keep edits in the form after a failed save.

Cards are learner-authored, explicitly labeled “Your card.” They do not appear in the bundled dictionary. An absent JLPT level is valid and never inferred from text. Speech uses only an explicitly supplied valid kana reading. Editing a prompt, answer, or reading clears that card's scheduled review and difficult-item state after confirmation, because previous recall measured different content. Notes, category, or level changes alone retain those records. Historical goal activity remains historical; deleting a card does not reduce past completions.

### Bundled grammar and sentences

Candidate source: [nihongo-mono grammar data](https://github.com/stndaru/nihongo-mono/tree/master/src/data/grammar), including N5–N1 files. Its [data license](https://github.com/stndaru/nihongo-mono/blob/master/LICENSE-DATA.md) describes grammar explanations, structures, and example sentences as original MIT-licensed content. Preserve the upstream MIT notice, data-license statement, repository URL, pinned commit, file checksums, and all retained source references. This is community material, not official JLPT coverage or a claim of fluent-human verification.

During implementation, pin and download an exact commit, inspect actual schemas and content, and validate unique IDs, required text, level ranges, examples, references, and attribution. Evaluate every level rather than assuming a valid N5 sample proves the full corpus. Preserve original text in a raw snapshot and record normalization changes separately. Unsupported or malformed records fail the importer with named causes; do not silently skip them or fill gaps with generated explanations.

Bundle grammar lessons with title/pattern, short meaning, explanation, formation rules, usage notes, supplied reading, related patterns, and Japanese/English examples. Provide standalone sentence study from those source examples, retaining the parent grammar lesson and its level as context. Label sentence level as “From an N5 lesson,” for example, rather than claiming that the whole sentence is independently graded N5. Deduplicate identical sentence/translation pairs deterministically and retain every parent reference. IDs derive from pinned source identity and exact text, with content hashes recorded; they do not depend on array position.

Grammar detail shows meaning, formation, explanation, examples, and usage notes immediately. Sentence detail shows the Japanese sentence, translation, supplied annotations, and parent lesson references. Each has source information available offline. Furigana markup must be parsed and checked against the original Japanese before constructing a reading; omit speech when the reading cannot be validated, rather than guessing.

The existing Tatoeba approval ledger and production word-example bundle are separate. Pending Tatoeba examples remain pending. Their existing fluent-human approval requirement is preserved; this feature does not mark those records approved or populate dictionary word-example cards from unchecked matches.

## Saving and identity

Extend `SavedStudyKind` with grammar, sentence, and custom-card kinds. All review queues, lookups, counts, list memberships, schedules, difficulty records, and goal activities use `SavedStudyID(kind, id)`. A word and a custom card with the same raw string ID must remain distinct. Review presentation stores the complete identity on each item; session kind is no longer the authority for identifying an item. Mixed sessions use “item/items” in counts.

Store custom cards and saved lesson snapshots in additive SwiftData models. Saving a bundled lesson copies its current study content and provenance into the learner collection with a stable learner identity and a unique source key. Repeated Save is idempotent. Bundled updates never silently rewrite saved answers or schedules. Missing or retired source records leave the saved snapshot readable. The initial feature does not add automatic content updates.

Existing word and kanji Add next order, indexes, counters, and catalog fingerprint remain unchanged. Lessons have no sequential Add next cursor and never increment vocabulary/kanji collection progress. A saved lesson or card with no review record is eligible for due review, using the existing unscheduled-item convention.

## Lists

Make study lists support saved words, kanji, lessons, sentences, and custom cards, including mixed lists. Membership refers to composite identity, never copies content, and is unique per list/item. Removing a membership or deleting a list keeps the underlying study item and its progress.

Preserve existing word memberships through an explicit migration: their wordID becomes a `.word` identity with the same ID and list. Do not reinterpret old IDs as another kind. Keep the legacy membership model readable during migration, perform conversion atomically, and make repeated migration safe. Item deletion removes its memberships, schedule, and difficult-item record in one transaction, while retaining historical activities.

## Ratings and difficult items

Persist a difficulty record for each saved composite identity with miss count, last miss date, last rating session ID, and whether that session contained an Again. Every successful Again across today, collection, list, lesson, custom-card, due, and difficult practice marks the item difficult and increments its miss count.

Got it after an Again in the same session finishes the queue but does not clear difficulty. A Got it in a later session, before any Again for that item in that session, clears difficulty. This means immediate repetition cannot masquerade as first-try recall. Records measure observed ratings only; UI never calls the result mastery.

Each rating action has a UUID captured before saving. Retries retain that action UUID, session ID, and original timestamp. Persist the latest applied action on the difficulty record so repeating a save cannot increment misses twice; restarting practice creates a new session. Multiple real Again taps in the same session have different action IDs and count separately.

Due ratings save schedule, difficulty, and optional Got it activity together. Other practice modes save difficulty and optional activity together and leave due schedules unchanged. The queue advances only after the transaction succeeds. Failure retains the revealed answer and pending action with Retry / Exit. Empty stores and deleted items give concrete explanations; no partial record or goal completion survives a failed transaction.

Practice difficult items opens a setup screen with material type, optional JLPT level (including Unspecified), optional study list, and 10 / 20 / All. Filters intersect. List filters use saved membership identities. Order is miss count descending, last miss descending, then composite identity as a stable tie-break. Capture a session snapshot when starting. “No difficult items yet” explains using Again during review; an empty filtered result offers Clear filters. Completion reports distinct items practiced and repeats, without promising every item left the difficult set.

## UI placement

Keep Today, Collection, and Progress as the native tabs. Avoid a five-part segmented picker: replace the material selector with a native menu for Words, Kanji, Grammar, Sentences, and Your cards, reusing remembered raw values for existing Words/Kanji selections. Lists may contain all types.

Collection provides shared Study lists, Practice difficult items, and a Lessons entry point, with Browse dictionary available for Words and Create card available for Your cards. Lessons has searchable Grammar / Sentences views and a level menu, clearly separating available bundled material from saved collection items. Saving from lesson detail is its single primary action; after saving, View saved item opens its saved detail.

Today retains Add next for words and kanji. Other kinds show due review and added-today items, with a neutral Browse lessons or Create card action when appropriate. A shared difficult-practice entry remains available without requiring an item to be due. The goal counts any distinct saved study identity marked Got it once per local day; bundled browsing and unsaved lessons never count.

Review shows only the prompt before reveal. Grammar answers include meaning, formation and explanation; sentence answers include translation and related lesson context; custom answers include answer and notes. Source/categorization metadata must not disclose the answer before reveal. Long prompts use readable wrapping Mincho text instead of an unbounded row of practice squares. English/custom non-Japanese prompts use system text styles. Bottom reveal/rating actions stay reachable at accessibility sizes.

Every new list has named loading, empty, error, and no-match states. Create/edit sheets use native Save/Cancel and retain input on error. Destructive removal explains affected memberships and schedules. Forest colors, spacing, controls, system text styles, native back navigation, and light/dark behavior remain consistent. Update DESIGN.md before changing UI contracts.

## Backup and compatibility

Introduce backup format 4, independent of catalog version. Include custom cards, saved lesson/sentence snapshots and provenance, generalized memberships, and difficulty records alongside all current data. Validate kinds, identity uniqueness, content bounds, dates, miss counts, references, and source notices before any replacement. Every scheduled or difficult item must exist in the saved collection. Historical activities may refer to deleted items as they do today.

Continue accepting supported format 1, 2, and 3 backups through explicit conversion. Older word memberships become `.word` memberships; new content and difficulty default empty. Keep old catalog conversion rules. Restore replaces all learner models atomically, creates a format-4 recovery backup first, and clears active practice routes. Preview names counts by type and mentions difficult items; failure preserves both original data and the recovery file.

## Verification and acceptance

- A persisted word, kanji, grammar lesson, sentence, and custom card can share a list and review session without identity collision or answer leakage.
- Ratings persist difficulty across relaunches; Again retries do not duplicate misses; same-session recovery stays difficult; later first-try recall clears it.
- Extra practice leaves due dates untouched. Due ratings, difficulty, and goals roll back together on failure. Overnight retry retains the original action day.
- Custom-card validation, failed-save draft retention, meaningful-edit reset, and deletion cleanup have focused tests.
- Existing disk stores and word-list memberships migrate without loss. Format-4 roundtrip and legacy restore tests exercise all content types, orphan rejection, corruption, rollback, and recovery.
- Bundled importer is deterministic for pinned inputs; attribution, source IDs, references, and text hashes are checked. Tatoeba pending records do not enter the published example bundle.
- Verify new screens in light, dark, and accessibility text size, run relevant framework tests, then the workspace suite and a Release build. VoiceOver and TestFlight checks remain outside this request.

## Review notes

The source is a candidate pending download and validation, not an asserted authoritative grammar corpus. The implementation must report actual imported counts and rejected-data causes. Existing uncommitted icon assets are preserved and kept separate from this design. Product implementation awaits the written design review required by the active brainstorming workflow.
