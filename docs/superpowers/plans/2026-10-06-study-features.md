# Study Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The user has requested planning and dataset preparation; this document does not authorize a new commit, push, or merge.

**Goal:** Turn the local collection into repeatable practice with due reviews, useful examples, and recoverable backups.

**Architecture:** Keep presentation state in @Observable view models composed by AppComposer. Add a pure queue and scheduler in DomainKit, a separate review-record model and repositories in DataKit, and versioned Codable backup DTOs rather than encoding SwiftData objects. Sentence preparation happens in repository tooling; only approved examples enter the app bundle.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Foundation, iOS 18, Tuist, Python 3 standard library for dataset preparation.

**Spec:** `docs/design/study-features.md`; preserve `DESIGN.md` and the baseline `docs/design/review-flow.md`, updating the latter as rated practice replaces reveal/next.

## Execution status — 2026-10-07

The user subsequently authorized committing, pushing and opening a PR for review. Earlier no-commit notes below describe the implementation run, not this later delivery authorization.

Tasks 1, 2, 3 and 5 are implemented. Task 4 tooling, loader and UI are implemented with an empty approved bundle; human content review and a durable external release-data archive remain publication dependencies. Raw inputs are hash-verified in the Gitignored local snapshot archive.

Final production-source verification: 54 workspace tests and 12 Python tests passed; app builds and diff checks pass. Independent review's clock rollback, populated backup without progress, and stale due-session replay findings were fixed with regression tests. Simulator review/setup/backup preview and confirmation were inspected in light/dark and accessibility-large text. System export sheet opens; user-approved live-simulator restore succeeded, returned to Progress, preserved 1 word / 2 kanji, and created a valid recovery backup with progress and review records. Fixture replacement/reopening/rollback tests pass. VoiceOver remains deferred. Temporary QA source changes were removed. No commits, push or merge in this execution.

Historical per-step checklists below describe the original sequence; combined commit/publication steps remain unchecked.

## Global Constraints

- Local only: no account, backend, sync, runtime downloads, or network-dependent UI.
- iOS 18, Swift 5, Tuist-generated projects.
- Forest tokens, shared components, Mincho headwords, system text styles, native routing.
- Preserve stable bundled order and saved Add next semantics.
- Tests must protect existing store data, scheduling idempotency, and restore atomicity.
- Inspect light, dark, accessibility-large text; honor Reduce Motion. VoiceOver testing remains deferred as requested.

## Review Focus

1. Homographs and mismatched dictionary senses: an example must teach the stored meaning, not merely contain the same spelling (Task 4).
2. Repeat taps, saving failures, and relaunch: one session must not multiply scheduling advances or lose existing collection data (Task 3).
3. Local midnight, daylight-saving changes, and time-zone changes: due dates use an injected calendar and deterministic dates (Task 3).
4. Corrupt, duplicated, future-version, or foreign-catalog backups: import must reject before any live mutation (Task 5).
5. Empty filtered collections and one repeatedly missed item: actions remain usable and arrays stay within bounds (Tasks 1–2).

## Preparation already completed

- [x] Download official `wwwjdic.csv` and Japanese/English detailed metadata into `/private/tmp/kotoba-tatoeba-20261006` (about 68 MiB total).
- [x] Add `tools/data/prepare_tatoeba.py` and three index-matching tests. Generate `data/tatoeba/n5-candidates.json`, `coverage.json`, and source notes.
- [x] Record source URLs/checksums and keep raw/candidate data outside app resources.

Measured result: 147,836 indexed pairs, 718 distinct N5 headword/reading pairs, 557 matched words, 863 candidates, **zero approved examples**. Exact matching deliberately misses aliases and unresolved JMdict entry IDs. No claim of full N5 coverage. Candidate owners may be null; do not invent attribution or readings. Temporary raw files need a durable release-data archive before a reproducible published dataset can be regenerated.

## Delivery order

Collection practice → Again queue → durable due review → approved N5 examples → backup/restore. Dataset review can happen alongside phases 1–3 without changing app behavior. Each phase is independently useful and should be reviewed and committed before the next. Finish all five phases before treating the full scope as shipped; example publication depends on human content review.

## Task 1: Review older collected items

**Files:**
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/WordsCollection/Components/CollectionListView.swift`
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/WordsCollection/Components/Kotoba/KotobaWordsCollectionView.swift`
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/WordsCollection/Components/Kanji/KanjiWordsCollectionView.swift`
- Create: `Frameworks/SwiftUIApps/Sources/Presentations/Review/ReviewSetupView.swift`
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/Review/ReviewSession.swift`, `ReviewView.swift`
- Test: `Frameworks/SwiftUIApps/Tests/ReviewSelectionTests.swift`

**Interfaces:** `ReviewSelection(level: String?, limit: Int?)` exposes `func selected(_ items: [ReviewItem]) -> [ReviewItem]`. Add `savedID: String` and `dateAdded: Date?` to ReviewItem, copied from saved Kotoba/Kanji. Add `ReviewOrigin` (`today`, `collection`) to ReviewSession so completion says “collected words” for collection sessions. Input is saved values; output is an immutable snapshot, never bundle UUID lookups.

- [ ] Write selection tests with explicit fixtures: items a/N5/old, b/N4/new, c/N5/new. `ReviewSelection(level: "N5", limit: 1).selected(items).map(\.savedID)` equals `["c"]`; an N1 selection equals `[]`; equal dates order by savedID. Extend existing mapping tests to retain saved IDs and dates.
- [ ] Run the SwiftUIApps suite; verify these tests fail before adding selection.
- [ ] Implement filtering by exact level, ordering by descending dateAdded (nil as distantPast), ascending savedID as tie-break, then prefix(limit). Treat nil limit as all. The setup owns level/limit; do not feed the browsing search filter into it.
- [ ] Add a neutral review action only on loaded/nonempty Collection. Present setup with All/N5–N1 and 10/20/All options, selected count, Start review, and Cancel. Disable Start for an empty result and show a clear next step. Push the existing review route using the snapshot.
- [ ] Use origin-specific completion and Back to Collection/Today labels. Keep native back semantics. Update DESIGN.md before any token changes (none expected).
- [ ] Regenerate with `tuist generate --no-open`, run SwiftUIApps tests and app build. Inspect both kinds, filtering, empty selection, native back, and large text. Commit this phase as `Add collection review setup`.

## Task 2: Repeat difficult items within a session

**Files:**
- Create: `Frameworks/DomainKit/Sources/Review/PracticeQueue.swift`
- Modify: `Frameworks/DomainKit/Project.swift` (`withUnitTest: true`)
- Create: `Frameworks/DomainKit/Tests/PracticeQueueTests.swift`
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/Review/ReviewViewModel.swift`, `ReviewView.swift`
- Modify: `Frameworks/SwiftUIApps/Tests/SwiftUIAppsTests.swift`, `docs/design/review-flow.md`

**Interfaces:** `public enum RecallRating { case again, gotIt }`; `public struct PracticeQueue` initialized with `[String]` unique saved IDs; `currentID: String?`, `remainingCount: Int`, `repeatAttempts: Int`, `mutating func rate(_ rating: RecallRating)`. Again rotates the first ID to the tail; Got it removes it. UI maps queue IDs back to its snapshot. Duplicate IDs at construction are de-duplicated preserving order.

- [ ] Add these behavioral tests before implementation:

```swift
func testAgainReturnsAfterOtherItems() {
    var queue = PracticeQueue(ids: ["a", "b"])
    queue.rate(.again)
    XCTAssertEqual(queue.currentID, "b")
    queue.rate(.gotIt)
    XCTAssertEqual(queue.currentID, "a")
    XCTAssertEqual(queue.repeatAttempts, 1)
}
func testOneMissedItemRemainsAvailable() {
    var queue = PracticeQueue(ids: ["a"])
    queue.rate(.again)
    XCTAssertEqual(queue.currentID, "a")
    queue.rate(.gotIt)
    XCTAssertNil(queue.currentID)
}
```

- [ ] Add empty-queue and duplicate-ID tests; run DomainKit and confirm failures.
- [ ] Implement guarded remove-first, append only for Again, increment repeatAttempts for Again. Keep unique original item count separate from attempts.
- [ ] Change the VM to reveal/rate/restart with rate guarded by visible answer. Reset reveal on every successful rating, including a one-item Again. Remove Previous in this mode. Add VM tests proving hidden-answer ratings are ignored and restart restores the original queue.
- [ ] Show “N remaining,” Again and Got it after reveal, and completion with distinct item count plus repeat attempts. Both actions meet 44pt targets, have clear text, and do not use different accent colors. Keep primary moss on Got it; Again neutral. Add a short explanation that Again repeats this session.
- [ ] Regenerate, run DomainKit/SwiftUIApps and workspace tests, and inspect empty/one-item/repeated Again in both themes and large text. Commit as `Add Again practice queue`.

## Task 3: Persist scheduling and offer due review

**Files:**
- Create: `Frameworks/DataKit/Sources/SwiftDataModel/Review/ReviewRecordModel.swift`
- Create: `Frameworks/DataKit/Sources/Repository/ReviewRepository.swift`
- Create: `Frameworks/DataKit/Sources/Store/StudyStore.swift`
- Modify: `Frameworks/DataKit/Project.swift` (`withUnitTest: true`)
- Create: `Frameworks/DataKit/Tests/ReviewStoreTests.swift`
- Create: `Frameworks/DomainKit/Sources/Review/ReviewScheduler.swift`, `GetDueReviewsUseCase.swift`, `RecordReviewUseCase.swift`
- Create: `Frameworks/DomainKit/Tests/ReviewSchedulerTests.swift`
- Modify: `Frameworks/SwiftUIApps/Sources/Presentations/Composer/AppComposer.swift`
- Modify: Home word/kanji views and VMs under `Frameworks/SwiftUIApps/Sources/Presentations/Home/Components/`
- Modify: Review session/VM/view and `DESIGN.md`

**Interfaces:** DataKit defines `SavedStudyID(kind: SavedStudyKind, id: String)` with Codable/Hashable and word/kanji cases. It keys **saved** IDs, not IDs regenerated from bundled CSV/JSON. ReviewRecordModel stores a unique composite key, kind, savedID, stage, dueDate, lastReviewedAt, lastSessionID, sessionBaselineStage, and sessionHadAgain. `ReviewScheduler.nextStage(baseline: Int?, hadAgain: Bool) -> Int` returns 0 after Again, else min((baseline ?? -1)+1, 4); `dueDate(stage: Int, now: Date, calendar: Calendar) -> Date` uses [1,3,7,14,30] and Calendar.date(byAdding:.day,... to startOfDay). `RecordReviewUseCase.execute(id: SavedStudyID, sessionID: UUID, rating: RecallRating, now: Date) throws` persists before queue mutation. Same-session updates retain baseline stage and accumulated Again; a new session captures the current stage. No record means due now.

- [ ] Before schema changes, create an on-disk store fixture using the current full schema (KotobaDataModel, KanjiDataModel, WordsProgressModel; ArrayString is a Codable value). Seed one word, one kanji and nonzero indexes; close it and reopen with the added model. Assert every field/index survives. The existing KotobaMigrationPlan is not used by AppComposer; do not assume it protects the live store. If additive migration fails, introduce full versioned V1/V2 schemas with frozen model definitions and test the actual on-disk upgrade before proceeding. Never delete/recreate a failing store.
- [ ] Add scheduler tests: no-baseline success → stage0; stage4 success → stage4; any Again → stage0; same-session repeats remain at the same stage; different sessions advance once; local midnight and a named DST zone produce calendar-day dates. Inject clock/calendar; never Task.sleep.
- [ ] Add repository tests for retrying the same session, partial save failure, and deleting a saved item removing its review record. An error leaves existing records unchanged. Ensure deletion save is one transaction, not independently saved model and record mutations.
- [ ] Implement the additive review model/repository and pure scheduler; move store construction into StudyStore and let AppComposer compose it. Maintain existing store URL and bundled sort. GetDueReviewsUseCase joins saved IDs to records, treats absent records as due, and sorts dueDate ascending then savedID.
- [ ] Add a due ReviewOrigin, inject RecordReviewUseCase only for due mode, and retain temporary ratings for Today/Collection practice. On rating, save first; error keeps reveal and queue position with Retry/Exit. Keep the session UUID stable across retries. Do not count Again multiple times during a failed write. Practice completion still changes no schedule.
- [ ] Add Due for review with loading, empty and error/retry states, count, and neutral entry action. Keep “added today” separate; due completion must not claim mastery. Existing items become unrated due items without changing WordsProgress. Refresh from disk onAppear.
- [ ] Regenerate; run real-store migration/repository tests, scheduler tests and workspace suite. Test background/relaunch, due-mode save error, and deletes in the simulator. Commit as `Add local due-review scheduling`.

## Task 4: Publish reviewed N5 sentence examples

**Files:**
- Modify: `tools/data/prepare_tatoeba.py`; create `tools/data/build_approved_examples.py`, `tools/data/test_approved_examples.py`
- Create: `data/tatoeba/approvals.json` (review ledger)
- Create: `Frameworks/DataKit/Resources/examples-n5.json`, `Frameworks/DataKit/Resources/tatoeba-attribution.txt`
- Create: `Frameworks/DataKit/Sources/Repository/ExampleRepository.swift`
- Create: `Frameworks/DataKit/Tests/ExampleRepositoryTests.swift`
- Create: `Frameworks/SwiftUIApps/Sources/DesignSystem/ExampleSentenceCard.swift`
- Create: `Frameworks/SwiftUIApps/Sources/Presentations/Sources/SourcesView.swift`
- Modify: DetailView, ReviewView, AppComposer, AppRoutes, ProfileView and DESIGN.md

**Interfaces:** `ExampleWordKey(headword: String, reading: String, level: String)` matches the bundled vocabulary exactly; it is separate from saved IDs. Example DTO includes Japanese/English text, optional verified reading, both source IDs/URLs, attribution/license, and reviewer/change metadata. `ExampleRepository.example(for key: ExampleWordKey) -> ExampleSentence?` returns nil if absent. Approval ledger entries identify the exact word key plus Japanese/English IDs, source text hashes, reviewer, review date, verified sense note, approved flag, and optional reviewed reading. Never use an index sense number as though it were our CSV gloss.

- [ ] Retain the downloaded raw snapshot in a durable release-data archive; verify hashes against coverage.json. Review N5 candidates with a fluent Japanese reviewer, starting with common words. Reject wrong senses (including the current ああ example), awkward wording and poor translations. Record rejected as well as approved decisions. This content step is a publication dependency, not something automated matching can complete.
- [ ] Write builder tests: pending/rejected examples never enter the output; changed source hashes invalidate approval; missing reviewer/license/source IDs fails the build; no approved record for a word produces no card. A fixture with spelling ああ but reviewer rejection for the interjection sense must be omitted. Verify stable output ordering and one example per word.
- [ ] Implement the builder as a deterministic join of candidate IDs/word keys to ledger approvals. Emit only approved entries. Preserve source metadata, list edits/readings, and produce coverage counts. If zero approved entries remain, do not release a fake example feature.
- [ ] Add Codable bundle loading with tests for duplicate keys, malformed resource and unknown version. Show no example for missing matches; keep definition/review usable if the resource is unreadable. Never make runtime requests to Tatoeba.
- [ ] Add ExampleSentenceCard on vocabulary Detail and only after Review reveal, with Japanese, English and optional verified reading. Keep kanji-only sessions without misleading sentence examples. Add a neutral Sources route with bundled credits and license text; full credits work offline.
- [ ] Run Python and DataKit tests plus workspace suite. Inspect a long example in light/dark/large text; assert no sentence or translation appears during recall. Update dataset/design notes with actual approved coverage. Commit as `Add approved N5 example sentences` only after the content gate is satisfied.

## Task 5: Export and safely restore local progress

**Files:**
- Create: `Frameworks/DataKit/Sources/Backup/StudyBackup.swift`, `BackupValidator.swift`, `BackupRepository.swift`
- Create: `Frameworks/DataKit/Tests/StudyBackupTests.swift`
- Create: `Frameworks/DomainKit/Sources/Backup/ExportBackupUseCase.swift`, `RestoreBackupUseCase.swift`
- Create: `Frameworks/SwiftUIApps/Sources/Presentations/Backup/BackupView.swift`, `BackupViewModel.swift`, `BackupDocument.swift`
- Modify: ProfileView, AppComposer, AppRoutes, StudyStore, DESIGN.md

**Interfaces:** `StudyBackup: Codable` has formatVersion=1, createdAt, catalogFingerprint, arrays of plain word/kanji/review DTOs, one progress DTO, and a typed preferences DTO. Preserve every current saved model field including english/readings arrays, IDs, addedIndex/dateAdded, levels and progress timestamps. Review DTO preserves stage/dueDate/session idempotency fields. Exclude raw SwiftData objects and bundles. `BackupValidator.validate(_ data: Data, catalog: CatalogSnapshot) throws -> StudyBackup`; `BackupRepository.export() throws -> Data`; `restore(_ validated: StudyBackup) throws` executes in a fresh autosave-disabled context. CatalogSnapshot fingerprints the actual stable order, not just the raw file bytes. BackupDocument implements FileDocument with `.json` readableContentTypes, Data payload, ReadConfiguration and FileWrapper writing.

- [ ] Add round-trip tests with Japanese strings, nil dates/indexes where the existing model permits them, nonzero progress, review dates and distinct word/kanji IDs. Encode/decode restores identical value DTOs. Test duplicate IDs within each kind, orphan records, invalid stage/index/level, future formatVersion, oversized input (>20 MiB), truncated JSON and foreign catalog fingerprint: every failure leaves live counts/indexes unchanged.
- [ ] Build a current-store fixture, export it, change collection data, restore and compare every field. Inject save failure to prove rollback after deletions/insertions. Test recovery-backup write failure aborts before mutation and file-selection cancellation changes nothing.
- [ ] Implement strict decode/validate first. Preserve progress counters exactly: current Add/Delete adjusts them cumulatively, not per active level. Validate nonnegative values and supported indexes without repairing historical inconsistencies or equating counters to filtered collection size. Reject incompatible catalog fingerprints with an actionable message; never re-sort/clamp silently. Check date range/calendar arithmetic can represent schedule values.
- [ ] Before applying, atomically write the current backup to an app-local recovery file. Use one dedicated ModelContext save for replacing models and schedules, rollback on failure, and keep recovery available. Apply whitelisted preferences only after the database save; refresh/recreate read contexts to avoid cached old models. BackupRestoreCompleted notification invalidates active review routes and reloads the list screens. Do not copy the open SQLite files.
- [ ] Use system fileExporter and fileImporter with security-scoped access. Decode asynchronously without blocking UI; release file access on all paths. Show backup date/counts and a destructive Replace current collection confirmation, then success/failure/recovery location. Cancel performs no writes. Export errors offer retry. No merge mode or sync copy.
- [ ] Regenerate, run DataKit/DomainKit/workspace suite and simulator export→change→restore. Exercise corrupt-file rejection and cancellation. Update DESIGN.md with copy and recovery behavior; commit as `Add local progress backup and restore`.

## Final integration check

- [ ] Run `python3 -m unittest discover -s tools/data -p 'test_*.py' -v`.
- [ ] Run `tuist generate --no-open`; verify generated files include DataKit, DomainKit and SwiftUIApps tests.
- [ ] Run `xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` and build the JapaneseDictionary app.
- [ ] Validate an existing store upgrade, fresh install, deletion/re-add, duplicate-rating retries, overnight due state, missing examples, backup rejection and restore rollback. Test both Words/Kanji routes.
- [ ] Inspect light/dark/accessibility-large text, navigation, safe-area actions and Reduce Motion. Record VoiceOver as deferred rather than claiming it passed.
- [ ] Run `git diff --check`; review schema changes, scheduler and import transaction before release. No commit/push/PR/merge without authorization for that execution run.
