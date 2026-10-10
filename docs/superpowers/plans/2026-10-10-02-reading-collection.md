# Reading-to-collection integration Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Save vocabulary from a passage into a reusable local study list and review it.

**Architecture:** Carry passage context through existing shared dictionary routes. A DataKit transaction combines selected-word addition and membership; dictionary sense selection remains explicit.

**Tech Stack:** Swift 5, iOS 18+, SwiftUI, SwiftData, Tuist; Apple frameworks only.

**Spec:** docs/superpowers/specs/2026-10-10-connected-learning-design.md

**Path convention:** Source/test paths below are relative to Frameworks/ unless they start JapaneseDictionary/ or DESIGN.md. Created names are proposed interfaces, not existing APIs.

## Global constraints

- Deployment target remains iOS 18; Swift 5 language mode.
- No runtime network, accounts, backend, sync, or server recognition fallback.
- Use Forest tokens and native AppRouter routes; update DESIGN.md before UI changes.
- Preserve Add-next ordering/indexes, saved identities and current review semantics.
- Include durable records in validated export, restore and recovery backups.
- No mastery, pitch-accent or calibrated pronunciation-percentage claims.
- Check light/dark and accessibility text sizes; VoiceOver/TestFlight remain deferred.

## Review focus

- Membership failure rolls back newly added word (Task 1).
- Repeated save reuses exact word/list identities (Task 1).
- Alternate dictionary senses are not conflated (Task 1).
- Passage list deletion does not delete saved vocabulary (Task 2).
- Back preserves passage/search context and reloads saved count (Task 2).

### Task 1: Atomic passage word saving

**Create:** DataKit/Sources/Learning/PassageWordRepository.swift; DomainKit/Sources/Learning/SavePassageWordUseCase.swift. **Modify:** DataKit/Sources/SwiftDataModel/Lists/StudyListModel.swift and existing word-addition/list repositories to share the same transaction context; Backup files for optional stable passage-list key. **Tests:** DataKit/Tests/PassageWordTests.swift, PassageListBackupTests.swift.

**Consumes:** existing selected-word catalog identity, `SavedStudyID`, mixed list memberships. **Produces:** `save(catalogID: String, passageID: String, title: String) throws -> SavedStudyID`. Store a unique optional sourceKey `passage:<id>` on StudyListModel; old lists have nil. Never match lists by editable display name.

- [ ] Test newly saved word + membership rollback, reuse of saved catalog identity without overwrite, stable list-key dedup after renaming, distinct catalog senses and unchanged Add-next indexes.
- [ ] Implement word/membership/sourceKey writes in one context/save, using existing catalog validation. Resolve canonical duplicate saved identity deterministically; preserve saved dates/meaning and historical records.
- [ ] Extend format 5 list payload with backward-compatible optional sourceKey, reject duplicate nonnil source keys, preserve it in recovery; test older nil field and restore.
- [ ] Run disk-reopen and failure tests; commit.

Transaction regression:
```swift
let before = try words.allSavedIDs()
XCTAssertThrowsError(try passageWords.save(catalogID: selectedID, passageID: "morning", title: "A quiet morning"))
XCTAssertEqual(try words.allSavedIDs(), before)
```
`allSavedIDs()` is a test helper over StandardReviewRepository.savedItems(kind: .word).

### Task 2: Passage-context dictionary and review

**Modify:** SwiftUIApps/Sources/Presentations/Learning/ReadingPracticeView.swift; Presentations/Dictionary/{DictionaryBrowseComposer,DictionaryBrowseDetailView,DictionaryBrowseDetailViewModel}.swift; Router/AppRoutes.swift. **Test:** SwiftUIApps/Tests/PassageVocabularyTests.swift.

**Produces:** `PassageContext(id: String, title: String)` carried as an optional Hashable route parameter. Saved count reads actual memberships by sourceKey; Review passage vocabulary creates the existing mixed-list review session.

- [ ] Test an ambiguous search offers selection, an existing saved word can still be added to the passage list, and failed saving leaves the button retryable.
- [ ] Add Save to passage list and confirmation/status naming the passage; retain ordinary Add to collection without passage context.
- [ ] Add saved-count/review action to passage detail; handle missing/deleted lists with count zero and an actionable empty state.
- [ ] Run light/dark/large-text and passage -> search -> detail -> save -> Back -> review checks; commit.

## Verification and handoff

For each owned task: add behavior tests, regenerate with `tuist generate --no-open` when files change, run its framework test target, fix failures, inspect diff and commit. A phase finishes with independent review of its own changes and required simulator/device evidence. Root serializes Tuist/Xcode operations; do not run concurrent builds from workers.

Full checks:
```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
python3 -m unittest discover -s tools/data -p 'test_*.py'
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
git diff --check
```

Use XcodeBuildMCP equivalents during execution when available. Preserve learner simulator data. No push, PR or merge is implied by executing the feature.
