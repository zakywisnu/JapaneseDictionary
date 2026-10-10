# Exercise history and mistake review Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Persist submitted answers and resumable sessions without losing feedback on save failure.

**Architecture:** DataKit owns immutable exercise snapshots, attempts and checkpoints; DomainKit owns recording/query rules. Observable presentation models advance only after one atomic persistence transaction.

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

- Double submission and retry retain the same attempt ID and timestamp (Task 1).
- A crash after submitting an answer resumes revealed feedback, not another attempt (Task 1).
- Changed bundled content keeps history but invalidates the old checkpoint (Task 2).
- A corrupt imported snapshot is rejected before learner replacement (Task 2).
- A later correct response clears a mistake while retaining its older attempt (Task 2).

### Task 1: Durable answer and checkpoint contract

**Create:** DataKit/Sources/Learning/History/ExerciseHistory.swift, ExerciseHistoryRepository.swift, ReviewRatingEvent.swift; DomainKit/Sources/Learning/RecordExerciseAnswerUseCase.swift. Paths are relative to Frameworks/. **Modify:** DataKit/Sources/Store/StudyStore.swift; DataKit/Sources/Difficulty/StudyRatingRepository.swift; SwiftUIApps/Sources/Presentations/Learning/ExerciseSession.swift, ExerciseSessionView.swift, ExerciseCatalog.swift, ReadingCatalog.swift. **Tests:** DataKit/Tests/ExerciseHistoryTests.swift; SwiftUIApps/Tests/ExerciseHistoryPresentationTests.swift.

**Interfaces:** `ExerciseSnapshot` stores id, revision, fingerprint, questionKind, prompt, choices, optional correctIndex, acceptedAnswers and explanation. Define questionKind choice/kanaReading/romanization/listeningReading/meaningSelfRated in this foundation so later modes do not change the format. `ExerciseResponse` is a Codable tagged choice(index), text(value), or selfRating(remembered) enum; `ExerciseAttempt` stores UUID id/sessionID, snapshot, response, outcome (correct/incorrect/selfRated), and submittedAt. Validate each question/response/outcome combination. Existing grammar and comprehension create choice snapshots and responses. `ReviewRatingEvent` stores actionID/sessionID, SavedStudyID, rating and submittedAt; historical events survive saved-item deletion. Add review-event insert to the existing atomic rating transaction, duplicate action ID is idempotent; do not reconstruct events from old latest-only records. `ExerciseCheckpoint` stores activityKey, sessionID, ordered snapshots, position, revealedAttemptID and updatedAt. `ExerciseHistoryRepository.record(_ attempt: ExerciseAttempt, checkpoint: ExerciseCheckpoint) throws` validates and saves both atomically; `attempts()`, `checkpoint(activityKey:)`, `deleteCheckpoint(activityKey:)` throw. A successful record returns only after save. Fingerprints use SHA256 of canonical content, excluding dates.

- [ ] Add repository tests for duplicate IDs, mismatched session/snapshot, injected-save rollback, real disk reopen and checkpoint revealed-state recovery; add VM test that save failure preserves choice and Retry uses identical attempt ID/date.
- [ ] Regenerate projects and run focused tests to establish the missing persistence failure.
- [ ] Test Again/Got it review events, action retry dedup, conflicting duplicate payload rejection and event/schedule/difficulty/activity rollback together. Add additive models and validator, UUID-idempotent transaction and store refresh. On selection persist the attempt/revealed checkpoint; on Next persist the next position before moving; on Finish remove checkpoint in the completion transaction. Explicit Restart creates a fresh session. Back retains checkpoint.
- [ ] Adapt exercise and reading factories to inject the recorder; show Save failed with Retry/Exit. Retain existing locked-answer behavior.
- [ ] Run tests; inspect disk reopen; commit the self-contained feature.

Example assertion for the transaction test:
```swift
XCTAssertThrowsError(try repository.record(attempt, checkpoint: checkpoint))
XCTAssertTrue(try repository.attempts().isEmpty)
XCTAssertNil(try repository.checkpoint(activityKey: checkpoint.activityKey))
```

### Task 2: History, mistakes and format 5 backup

**Create:** SwiftUIApps/Sources/Presentations/Learning/ExerciseHistoryViewModel.swift, ExerciseHistoryView.swift, MistakeReviewView.swift. **Modify:** DataKit/Sources/Backup/{StudyBackup,BackupRepository,BackupValidator}.swift; SwiftUIApps/Sources/Presentations/Backup/BackupView.swift; Router/{AppRoutes,AppNavigationStack}.swift. **Tests:** DataKit/Tests/ExerciseHistoryBackupTests.swift, SwiftUIApps/Tests/MistakeReviewTests.swift.

**Produces:** `ExerciseHistoryQuery.latestMistakes(_ attempts: [ExerciseAttempt]) -> [ExerciseAttempt]`, grouped by snapshot fingerprint and ordered by latest wrong submission then stable ID. History lists preserve retired snapshots. Resume rejects changed revisions with a clear Start new session action.

- [ ] Test wrong -> correct removes the mistake, wrong -> wrong yields one row, unrelated content revisions stay distinct, cancelled/unsubmitted choices do not count and ties are deterministic.
- [ ] Add format 5 attempts/checkpoints/reviewRatingEvents arrays, strict bounds (at most 10,000 attempts and 100 checkpoints), finite dates and matching references. Preserve older restore/migration behavior with empty new arrays; recovery includes every new record.
- [ ] Test current roundtrip across all defined response tags, format 4 restore, malformed answer index/fingerprint/reference and failed replacement/recovery rollback.
- [ ] Implement native history/mistake screens with actual counts, loading/empty/retry, resume/new-session choice and explicit mistake practice. Do not mutate saved-item schedules from exercise answers.
- [ ] Run focused/full tests and commit. This phase is independently usable before the other plans.

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
