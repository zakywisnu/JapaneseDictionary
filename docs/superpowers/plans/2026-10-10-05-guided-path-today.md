# Beginner path and Continue learning Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Connect current activities into a small beginner path with a clear next action on Today.

**Architecture:** A versioned offline path catalog references actual existing content; persisted path state and history checkpoints resolve one Continue learning destination. Today main content scrolls at accessibility sizes.

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

- References must resolve to shipped kana/questions/passages (Task 1).
- Content revision changes do not imply completion of new material (Task 1).
- Skip is visibly different from completed activity (Task 1).
- An unfinished session takes priority over a fresh path step (Task 2).
- Today keeps Add-next and selection usable at maximum text size (Task 2).

### Task 1: Versioned path state

**Create:** DataKit/Sources/Learning/BeginnerPathCatalog.swift, LearningPathProgress.swift, LearningPathRepository.swift; DomainKit/Sources/Learning/ContinueLearningUseCase.swift. **Modify:** StudyStore and Backup files. **Tests:** DataKit/Tests/LearningPathTests.swift, LearningPathBackupTests.swift.

**Produces:** `LearningPathStep(id, revision, title, activityKey, requiredContentIDs)` and `LearningPathProgress(pathID, currentStepID, completedRevisions, skippedStepIDs, updatedAt)`. `ContinueLearningUseCase.execute() throws -> LearningDestination?` first selects latest valid unfinished checkpoint, then next uncompleted/unskipped path step. LearningDestination is a DomainKit value (activity kind/key), mapped into AppRoutes by composer.

- [ ] Validate a shipped eight-step starter path against KanaCatalog, ExerciseCatalog snapshots and ReadingCatalog: basics, voiced, katakana, contracted, particles, morning passage, polite verbs, remaining passages.
- [ ] Test every reference resolves, revision mismatch retains historical completion without marking new content complete, skip/revisit and checkpoint-priority deterministic tie behavior.
- [ ] Persist path changes atomically; completion requires attempted required current-revision items, not a mastery threshold. A kana step completes after the selected group's items finish an explicit practice session; never on Select group alone.
- [ ] Advance backup to format 6 with validated pathProgress, preserving formats 1–5; old backups default to empty path progress. Test corrupt references, duplicate path IDs, recovery and rollback.
- [ ] Run migration/disk reopen tests and commit.

Completion test:
```swift
XCTAssertFalse(policy.isComplete(step: step, attemptedIDs: Set(step.requiredContentIDs.dropLast())))
XCTAssertTrue(policy.isComplete(step: step, attemptedIDs: Set(step.requiredContentIDs)))
```
`policy` is a pure LearningStepCompletionPolicy over current-revision IDs.

### Task 2: Path UI and Today integration

**Create:** SwiftUIApps/Sources/Presentations/Learning/LearningPathViewModel.swift, LearningPathView.swift, ContinueLearningCard.swift. **Modify:** HomeView.swift, MaterialsComposer.swift, Home/Components/KotobaView/HomeKotobaView.swift, Home/Components/KanjiView/HomeKanjiView.swift and AppRoutes/AppNavigationStack. **Tests:** SwiftUIApps/Tests/ContinueLearningTests.swift.

- [ ] Show current step, attempted/completed/skipped status and Revisit/Skip actions with clear next-step effects.
- [ ] Put Continue learning and Daily study plan summaries into the scrollable Today content; avoid nesting competing scroll views. Keep one clear primary action and neutral supporting actions.
- [ ] Test load failure/retry, finished path and missing checkpoint content give concrete alternatives; Verify state reload on appearance after completion and backup restore.
- [ ] Check all five Today study kinds in light/dark/max text, native back paths and source notices; commit.

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
