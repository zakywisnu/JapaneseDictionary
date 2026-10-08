# Daily Practice Goals Implementation Plan

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

**Goal:** Count distinct completed practice items across existing review modes toward a configurable local daily goal.

**Architecture:** Use goal/activity models and backup DTOs from the shared storage foundation. A repository saves idempotent daily activity; Due review saves schedule plus completion activity in one transaction. A compact Today summary and Progress goal settings consume a domain summary.

## Review Focus

- Repeated Got it across list/Today/Collection/Due modes counts one learner identity per day.
- Again, listening, browsing and adding do not inflate completed practice.
- Midnight/DST/timezone change and overnight retries preserve the action's captured local day.
- A failed save cannot advance the queue or partially update a due schedule/activity.
- Deletion, target changes, Off and legacy backup restore retain well-defined daily totals.

### Task 1: activity repository and atomic review completion

**Create:** DataKit/Sources/Repository/DailyGoalRepository.swift; DomainKit/Sources/Goals/DailyStudyGoalUseCases.swift; DataKit/Tests/DailyGoalTests.swift; DomainKit/Tests/DailyStudyGoalTests.swift.
**Modify:** DataKit/Sources/Repository/ReviewRepository.swift; DomainKit/Sources/Review/RecordReviewUseCase.swift; DataKit/Tests/ReviewStoreTests.swift; DomainKit/Tests/ReviewSchedulerTests.swift.

**Interfaces:** Activity uses kind+learner ID, captured completedAt and Gregorian local day key YYYY-MM-DD. Make day with an injected calendar/timezone, fixed Gregorian formatting, never locale-dependent week year. Summary has target:Int?, completedCount:Int, isReached:Bool. Nil means Off; absent model defaults to 10.

```swift
public protocol DailyGoalRepository {
    func target() throws -> Int?
    func setTarget(_ target: Int?) throws
    func activities(dayKey: String) throws -> [PracticeActivity]
    func record(_ activity: PracticeActivity) throws
}
// Extend ReviewRepository to save both in one transaction.
func save(_ record: ReviewRecord, activity: PracticeActivity?) throws
// DefaultRecordReviewUseCase creates activity only for Got it.
let activity = rating == .gotIt ? PracticeActivity(id: id, completedAt: now, calendar: calendar) : nil
try repository.save(record, activity: activity)
```

- [ ] Write tests for duplicate identity/day across modes, distinct word/kanji IDs, Again exclusion, nil/default/allowed targets and invalid target rejection. Test date boundaries around midnight and DST with fixed timezones; changing timezone changes new day selection but does not rewrite old keys. Test historical activities survive learner deletion and format-3 restore.
- [ ] Run RED. Implement repository with fresh contexts, current learner existence check for new recording, deduplicated key insertion and one save/rollback. Duplicate requests return without mutation. Query counts existing day records even if learner later deleted; do not attach cascade relationships to activity.
- [ ] Extend StandardReviewRepository.save(record,activity:) to validate both and save both atomically. Retain the existing save(record) overload delegating with nil for existing callers. Both context/store constructors work. DefaultRecordReviewUseCase still computes schedules with existing session-baseline/idempotence semantics, while activity captures the current Got it action time (not the earlier Again schedule baseline).
- [ ] Inject save failures after proposed schedule/activity changes and verify neither persists. Duplicate same-session ratings retain schedule; a new day's successful Got it may create that day's activity without advancing the same-session stage. Run review regressions and commit `Track daily practice with atomic due review completion`.

### Task 2: queue retries and goal presentation

**Create:** SwiftUIApps/Sources/Presentations/Goals/DailyGoalViewModel.swift, DailyGoalSummaryView.swift, DailyGoalSettingsView.swift, GoalsComposer.swift; SwiftUIApps/Tests/DailyGoalPresentationTests.swift.
**Modify:** Review/ReviewViewModel.swift, ReviewView.swift; Home/HomeView.swift; Profile/ProfileView.swift; Composer/AppComposer.swift; Router/AppRoutes.swift, AppNavigationStack.swift; DESIGN.md; SwiftUIApps/Tests/SwiftUIAppsTests.swift.

**Interfaces:** PracticeCompletionUseCase records activity for non-due Got it; GetDailyStudyGoalUseCase produces summary for a captured day. ReviewViewModel accepts injected practice completion and preserves pending rating/date on failure. Default existing test initializers may keep injected completion optional, but production composer must always supply it.

```swift
// Capture once when starting a rating; retry reuses this value.
let actionDate = state.pendingActionDate ?? now()
if state.session.origin == .due {
    try recordRating(id, state.session.id, rating, actionDate)
} else if rating == .gotIt {
    try recordPractice(id, actionDate)
}
// Only after successful persistence: clear pending action, then queue.rate(rating).
```

- [ ] Write failure-first tests proving failed practice save retains answer/current item, retry date is stable across midnight, Again skips completion, repeated sessions deduplicate, list sessions use practice path and due calls atomic path once. Existing practice tests still prove no schedule writes.
- [ ] Implement pendingActionDate reset on successful rating/restart, concrete save error + Retry/Exit and no queue advance on failure. Listening stops on queue transition. Add daily goal summary to Today; Progress opens native goal setting route with Off/5/10/20/30, Save/Cancel and retryable persistence failure. Target defaults 10, completion caption says Goal reached; no reminders/streaks/mastery claims.
- [ ] Reload summary on appearance, foreground and a local day-change notification. Respect current locale only in displayed counts/date, not persisted keys. Changing target recomputes from today's unchanged history. Off hides Today summary, retains history and remains editable in Progress.
- [ ] Inspect goal states, save failure, large text and midnight refresh. Full suite/Release/backup regressions; commit `Add daily practice goal settings and progress`.

## Verification command convention

After new sources/tests, run `tuist generate --no-open` centrally. Observe the named new tests failing before implementation, then passing. Focused simulator command:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DataKitTests
```

Replace the final selector with the named framework/class for the task. Prefer configured XcodeBuildMCP test tools when available. End each phase with the full workspace suite, app Release build, Python regressions when affected, and `git diff --check`. Commit verified phase work locally; no push/merge during implementation.
