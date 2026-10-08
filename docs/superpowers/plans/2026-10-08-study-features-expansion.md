# Study Features Expansion Implementation Plan

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

**Goal:** Deliver custom word lists, local pronunciation, daily practice goals and a current-catalog sentence review batch.

**Architecture:** Four phase plans share the approved design. The list phase establishes the full additive schema and format-3 backup contract; pronunciation is independent; goals then integrate transactional practice activity. Sentence preparation can run separately, but publication requires fluent human input.

## Review Focus

- The old learner store and its advice/schedules must survive schema and backup changes.
- List membership must reference learner IDs without copying or duplicating study data.
- Pronunciation must never reveal a recall answer or use a guessed reading.
- Practice and due review must preserve distinct scheduling semantics while counting daily activity once.
- No example content can be presented as approved without external human decisions.

## Execution order and ownership

1. [Custom study lists](2026-10-08-custom-study-lists.md): storage/backup foundation, then list UI/review context.
2. [Pronunciation](2026-10-08-pronunciation.md): speech service, then detail/reveal controls.
3. [Daily goals](2026-10-08-daily-goals.md): activity transactions, then queue/goal UI.
4. [Sentence preparation](2026-10-08-sentence-review-preparation.md): current-catalog batch/tooling, then human-gated publication.

Preserve the previously chosen phase-by-phase execution with scoped orchestration where helpful. Coordinator owns shared StudyStore/BackupRepository/BackupValidator/AppComposer/routing and all generation/builds; workers receive non-overlapping model/repository/UI/tooling responsibilities. A focused reviewer checks each phase’s persistence/recall/backup risks before proceeding. Do not run competing xcodebuild/Tuist operations.

- [x] Execute list phase and its store preservation/backup gate.
- [x] Execute pronunciation phase and record actual audio availability/runtime checks.
- [x] Execute daily goals and due/practice retry/idempotence gate.
- [x] Execute sentence preparation and deliver the pending human worksheet.
- [ ] Publish sentences only if human decisions arrive; otherwise mark the publication dependency explicitly.
- [x] Whole-branch review, full workspace suite, all Python data regressions and Release build.
- [x] Record evidence in docs/implementation/study-features-expansion-verification.md, including light/dark/XXXL and simulator automation limits.
- [x] Keep tested commits local; Git push/PR/merge is a subsequent delivery step.

## Final preservation gate

Compare an existing disk store before/after schema upgrade, list assignment, a list practice session, a due rating and format-3 export/restore. Original learner IDs/meanings/advice, kanji values and Add next cursors must remain unchanged except the precise requested mutation. Exercise failure rollback with injected contexts and recovery-write errors. Never replace a user's live store merely to prove a test; use fixtures or obtain the specific restore authorization.

## Plan self-review

All four approved phases have exact files, interfaces, failure-first examples and verification gates. Shared-format fields are introduced together, preventing phase-local exporters from dropping later goal/history data. Word-only lists, explicit kanji readings, default goal 10, local-day semantics and human publication requirements are preserved. No new tab, backend, notification, artificial refresh delay or mastery statistic is planned.

Status: implemented and verified. Sentence publication remains dependent on fluent human decisions; pending worksheet and publication tooling delivered. Evidence: ../../implementation/study-features-expansion-verification.md.

## Verification command convention

After new sources/tests, run `tuist generate --no-open` centrally. Observe the named new tests failing before implementation, then passing. Focused simulator command:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DataKitTests
```

Replace the final selector with the named framework/class for the task. Prefer configured XcodeBuildMCP test tools when available. End each phase with the full workspace suite, app Release build, Python regressions when affected, and `git diff --check`. Commit verified phase work locally; no push/merge during implementation.
