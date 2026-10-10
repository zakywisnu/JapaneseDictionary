# Meaningful learning progress Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Show real exercise outcomes and recent activity alongside collection and review counts.

**Architecture:** Read-only queries aggregate durable exercise attempts, path records and existing review activity and new ReviewRatingEvent history. Keep differently measured outcomes separate and report denominators/date ranges.

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

- No history shows guidance rather than invented percentages (Task 1).
- Retry duplicates cannot inflate numerator or denominator (Task 1).
- Calendar-day boundaries and timezone changes are explicit (Task 1).
- Retired exercise snapshots remain included in historical activity (Task 1).
- Recognition matches are never displayed as pronunciation accuracy (Task 2).

### Task 1: Read-only aggregates

**Create:** DomainKit/Sources/Learning/LearningProgressUseCase.swift. **Tests:** DomainKit/Tests/LearningProgressTests.swift.

**Consumes:** attempts(), ReviewRatingEvent history, current path progress and DailyGoalRepository.activities(dayKey:). **Produces:** `LearningProgressSummary` with submitted/correct counts by activity kind, distinct attempted content count, current mistakes, date range and path-step statuses. Review recall is labeled self-rated: count the first rating per (sessionID, SavedStudyID) only, Got it / all first ratings. Do not count later repeats as first-try success. Label the available recording date range because older review events cannot be reconstructed. Objective accuracy includes only deterministically graded typed/choice attempts; self-rated meaning and recognition results have separately named totals.

- [ ] Test empty returns nil accuracy, one wrong/two right yields 2/3, duplicate UUID counted once, cancelled sessions contribute only actually submitted answers, repeated Again -> Got it remains a first-try miss, and history from retired content is retained.
- [ ] Inject Calendar and now. Assign each timestamp to current-local-calendar boundaries for requested Today/7 days/30 days; tests cover midnight and DST/timezone shifts. Show date-range caption so a boundary change is understandable.
- [ ] Keep exercise totals separate from the existing distinct-saved-item goal. No schema writes in this use case.
- [ ] Run tests and commit.

Denominator regression:
```swift
XCTAssertEqual(summary.grammar.correct, 2)
XCTAssertEqual(summary.grammar.submitted, 3)
XCTAssertNil(emptySummary.grammar.accuracy)
```

### Task 2: Progress presentation

**Create:** SwiftUIApps/Sources/Presentations/Learning/LearningProgressViewModel.swift, LearningProgressView.swift. **Modify:** Presentations/Profile/ProfileView.swift and composer/routes. **Tests:** SwiftUIApps/Tests/LearningProgressPresentationTests.swift.

- [ ] Add native time-range picker, collection section, review activity section and exercise/path section with distinct labels. Use text-first counts and denominators; only add a chart if it clarifies daily trends with real samples.
- [ ] Link recurring mistakes to history review and path steps to Continue learning. Keep backup/source entry points accessible.
- [ ] Test loading/error/empty data and exact displayed totals; no mastery or exam-readiness badges.
- [ ] Check light/dark/max text; run full workspace/Python tests and Release build; commit.

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
