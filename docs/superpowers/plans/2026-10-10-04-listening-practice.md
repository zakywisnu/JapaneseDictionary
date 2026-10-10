# Listening recall practice Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Practice understanding supplied Japanese speech before revealing text.

**Architecture:** Build listening questions from explicit saved readings and use the same durable recall contracts as typed practice. Reuse PronunciationService through the shared audio coordinator introduced by Plan 07 Task 1. Listening can be implemented with injected playback before speaking, but audio-coordinator integration must precede its final acceptance.

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

- Missing voice or failed playback cannot become a scored wrong answer (Task 1).
- Text stays hidden before reveal and is not leaked by answer-control labels (Task 1).
- Repeated replay/Next stops earlier audio and ignores stale completions (Task 1).
- Entries with missing/invalid readings are excluded visibly (Task 2).
- Listening outcomes remain separate from vocabulary review ratings (Task 2).

### Task 1: Listening state machine

**Create:** SwiftUIApps/Sources/Presentations/Learning/ListeningPracticeViewModel.swift, ListeningPracticeView.swift. **Modify:** Services/Pronunciation/PronunciationService.swift only to expose validated playback state to injected session controls. **Test:** SwiftUIApps/Tests/ListeningPracticeTests.swift.

**Consumes:** RecallQuestion, history recorder and an injected PronunciationEngine. **Produces:** state ready/playing/awaitingAnswer/revealed/failed/unavailable; actions play/submit/reveal/next/cancel. An unavailable engine records no attempt. New questions never auto-play. Persist attempts only after an explicit answer/reveal rating.

- [ ] Test unavailable/error/timeout no-score outcomes, playback cancellation, request-ID rejection, hidden prompt state and replay followed by Next.
- [ ] Implement Listen/Replay, answer input and Reveal; stop audio on every route/background/interruption transition. A Check action uses TypedAnswerPolicy only for supplied kana readings; meaning recall is self-rated with honest result labels.
- [ ] Keep answer content out of the pre-reveal accessibility labels. Playing announces playback, not the expected word.
- [ ] Run injected-engine tests and commit.

Availability test shape:
```swift
model.send(.play)
XCTAssertEqual(model.state.phase, .unavailable)
XCTAssertTrue(recorder.attempts.isEmpty)
```
`recorder` is the in-memory injected history test double; phase availability is an explicit enum case.

### Task 2: Selection and history integration

**Create:** SwiftUIApps/Sources/Presentations/Learning/ListeningPracticeComposer.swift. **Modify:** LearningPracticeView, Router files, history screen and backup recall-kind validation. **Tests:** SwiftUIApps/Tests/ListeningSelectionTests.swift.

- [ ] Build bounded sessions of 10/20/all saved items with supplied short readings (maximum 200 kana characters, matching current pronunciation service); display excluded counts.
- [ ] Preserve queue/reveal state across resume. Replay on resume is learner-initiated.
- [ ] Test kana marks without standalone reading, missing material readings, duplicate composite identities and separate listening-vs-typed fingerprints.
- [ ] Confirm device speech output for kana, words and short sentences, no automatic score/due changes, light/dark/large text; commit.

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
