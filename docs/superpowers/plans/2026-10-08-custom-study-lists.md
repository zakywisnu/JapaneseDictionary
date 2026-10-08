# Custom Study Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Preserve phase-by-phase execution and use scoped agents when helpful. Centralize Tuist/builds and shared-file edits.

**Tech Stack:** iOS 18, Swift 5, SwiftUI, SwiftData, Tuist; AVFoundation for pronunciation; Python standard library for sentence tooling.

**Spec:** ../specs/2026-10-08-study-lists-pronunciation-goals-design.md (approved).

## Global Constraints

- Local only: no accounts, sync, runtime corpus fetches or network-dependent product UI.
- Preserve learner IDs, saved meanings, AI notes, Add next order/cursors and existing review schedules.
- Follow DESIGN.md / Forest, existing composer and state/send patterns, native routing and explicit loading/empty/error states.
- VoiceOver and TestFlight remain deferred.
- Sentence publication requires fluent human decisions; no AI-generated approval.
- Native navigation routes must be included in AppNavigationStack.isPushed.
- Workers own explicit files, are not alone, and must not revert others. Shared backup/Composer/routing edits belong to the coordinator.

**Goal:** Organize saved words into multiple local lists and practice a chosen list without copying words or changing schedules.

**Architecture:** Normalized SwiftData list/membership records reference learner IDs. Central storage foundation includes goal/activity models and the complete format-3 backup contract now, so subsequent phases cannot silently lose new fields through an older format-3 exporter. Views consume repository DTOs and existing saved review snapshots.

## Review Focus

- Case/width-equivalent names and repeated membership saves must not create ambiguous lists or duplicate rows.
- Deleting a word/list must leave no memberships while preserving unrelated words, schedules and counters.
- Schema upgrade or failed saves must preserve the existing learner store exactly.
- Old/future/corrupt backups must not replace live data or silently drop lists/goals/history.
- Empty/missing/deleted list routes and practice snapshots must provide safe navigation and recovery.

### Task 1: shared schema, list repository and complete format-3 backup

**Create:** DataKit/Sources/SwiftDataModel/Lists/StudyListModel.swift, StudyListMembershipModel.swift; DataKit/Sources/SwiftDataModel/Goals/DailyGoalSettingsModel.swift, PracticeActivityModel.swift; DataKit/Sources/Repository/StudyListRepository.swift; DataKit/Tests/StudyListTests.swift, StudyFeaturesBackupTests.swift.

**Modify:** DataKit/Sources/Store/StudyStore.swift; Sources/Backup/StudyBackup.swift, BackupRepository.swift, BackupValidator.swift; Sources/Repository/StudyMutationRepository.swift; DataKit/Tests/StudyBackupTests.swift, CatalogMigrationTests.swift. Paths above are under Frameworks/.

**Interfaces:** Public immutable StudyList (id/name/createdAt/wordCount), PracticeActivity (key/dayKey/studyID/completedAt), DailyGoalSettings (target: Int?, default 10); repository methods below. Model IDs are strings; membership key is listID + saved-word ID encoded unambiguously. Normalized list names trim whitespace and fold case/width in a fixed locale. Names contain 1–60 characters.

```swift
public protocol StudyListRepository {
    func lists() throws -> [StudyList]
    func create(name: String) throws -> StudyList
    func rename(id: String, name: String) throws
    func delete(id: String) throws
    func words(listID: String) throws -> [SavedStudyItem]
    func listIDs(wordID: String) throws -> Set<String>
    func setLists(wordID: String, listIDs: Set<String>) throws
    func removeWord(listID: String, wordID: String) throws
}
```

- [ ] Write failure-first fixtures asserting one word belongs to two lists once; duplicate normalized names reject; membership replacement is atomic; absent words/lists reject. Inject a save failure and assert previous memberships/name remain unchanged.

```swift
try repository.setLists(wordID: savedWordID, listIDs: [travel.id, exam.id])
try repository.setLists(wordID: savedWordID, listIDs: [travel.id, exam.id])
XCTAssertEqual(try repository.listIDs(wordID: savedWordID), [travel.id, exam.id])
XCTAssertEqual(try repository.words(listID: travel.id).count, 1)
```

- [ ] Add an old four-model disk fixture; reopen with the expanded schema and compare every old field. Add tests deleting a word removes its memberships in the same save; deleting a list keeps words/reviews/progress unchanged. Failure rolls back cleanup and existing mutations.
- [ ] Run new tests RED, centrally regenerate projects, then implement models and repository. Each mutation uses prepare/migration hook → fresh autosave-disabled context → validate references/name/uniqueness → change → one save → refresh; catch rolls back. List sorting is normalized name/ID; word sorting is date descending/learner ID.
- [ ] Define complete backup DTOs for all new models. Format 3 is independent of catalog version 2; retain catalog fingerprint and progress.catalogVersion. Export production as format 3, with lists, memberships, target and activities. A missing goal model exports target 10. Goal settings have one fixed singleton ID; reject multiple settings rows on export and invalid settings on restore rather than combining them. Keep legacy catalog-1 test fixtures compatible without permitting new fields to be silently discarded.
- [ ] Implement custom decoding defaults for v1/v2 missing fields (empty lists/memberships/activity, target 10), distinguishing an explicitly null target (Off). Validate future version rejection, name/ID/key uniqueness, membership references, target in nil/5/10/20/30, valid Gregorian day keys, finite timestamps and activity key consistency. Historical activities need not reference an extant word. Format-1 conversion runs before current validation; preserve its learner content.
- [ ] Test format-3 roundtrip including goal/activity fixtures, older restore defaults, orphan/duplicate list data, invalid goal/day/kind, recovery-write failure and save rollback. Allow progress absent for an empty learner store with lists but no saved items/reviews. Restore removes/reinserts all new models in the same save as words/progress/reviews and posts existing invalidation only after success.
- [ ] Run focused and full tests, inspect diff, commit `Add study list storage and complete study backup format`.

### Task 2: list use cases, native screens and review context

**Create:** DomainKit/Sources/Lists/StudyListUseCases.swift; SwiftUIApps/Sources/Presentations/StudyLists/StudyListsViewModel.swift, StudyListsView.swift, StudyListDetailViewModel.swift, StudyListDetailView.swift, WordListMembershipViewModel.swift, WordListMembershipView.swift, StudyListsComposer.swift; SwiftUIApps/Tests/StudyListPresentationTests.swift.

**Modify:** SwiftUIApps/Sources/Presentations/Composer/AppComposer.swift, WordsCollection/WordsCollectionView.swift, Details/DetailView.swift, Details/DetailComposer.swift, Review/ReviewSession.swift, ReviewSetupView.swift, ReviewView.swift; Router/AppRoutes.swift, AppNavigationStack.swift; DESIGN.md.

**Interfaces:** StudyListUseCases wraps the repository methods without duplicating validation. View models inject use cases/closures, expose state, and send load/retry/create/rename/delete/remove/membership-save actions. Detail state includes list DTO and saved words; membership state includes selected set and original set so Cancel mutates nothing. Composer passes live learner IDs, never dictionary UUIDs.

```swift
// ReviewOrigin carries the list route; other origins keep existing behavior.
case list(id: String, name: String)
// ReviewSetupView's default remains .collection for current callers.
var origin: ReviewOrigin = .collection
// New native routes:
case studyLists
case studyList(String)
```

- [ ] Write tests for loading/empty/error/retry; invalid-name/save failure preserves input; checkbox cancel/failed save preserves original data; duplicate requests remain safe; missing list after deletion yields guidance; new routes survive pushed-route filtering. Extend review selection tests to prove a list session snapshots only member learner IDs with existing level/limit ordering.
- [ ] Run presentation tests RED. Implement shared-use-case composition, neutral Collection Words action, list create/rename sheets, member rows, list-only removal and explicit list deletion confirmation. Update DESIGN.md before screens. Existing saved Word Detail gets Organize in lists; unsaved dictionary detail keeps its current save-first flow.
- [ ] Extend review setup to accept origin. List completion/back pops to its originating list; missing list on return shows recovery. Practice queue and schedules remain unchanged. Include list sessions in the daily-goal phase without classifying them as due review.
- [ ] Verify lifecycle reload after membership change/restore and all loading/empty/error states. Inspect light/dark/XXXL, run full suite/Release and commit `Add study list organization and list practice`.

## Verification command convention

After new sources/tests, run `tuist generate --no-open` centrally. Observe the named new tests failing before implementation, then passing. Focused simulator command:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DataKitTests
```

Replace the final selector with the named framework/class for the task. Prefer configured XcodeBuildMCP test tools when available. End each phase with the full workspace suite, app Release build, Python regressions when affected, and `git diff --check`. Commit verified phase work locally; no push/merge during implementation.
