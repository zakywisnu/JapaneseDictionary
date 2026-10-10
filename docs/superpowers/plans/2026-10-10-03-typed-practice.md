# Typed-answer practice Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Let learners recall kana romanization or Japanese readings with transparent answer comparison.

**Architecture:** DomainKit owns deterministic normalization and accepted-answer policy; UI reuses durable exercise attempt/checkpoint contracts. Quiz results stay separate from due reviews.

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

- IME composition is not submitted before explicit Check (Task 1).
- Small tsu, voicing and long vowels remain meaningfully different (Task 1).
- Configured Hepburn aliases are accepted without accepting arbitrary guesses (Task 1).
- Saved content changes invalidate stale answer snapshots (Task 2).
- Save failure preserves typed draft and retry identity (Task 2).

### Task 1: Answer policy

**Create:** DomainKit/Sources/Learning/TypedAnswerPolicy.swift; DataKit/Sources/Learning/History/RecallQuestion.swift. **Test:** DomainKit/Tests/TypedAnswerPolicyTests.swift.

**Produces:** `TypedAnswerPolicy.evaluate(input: String, accepted: [String], mode: TypedAnswerMode) -> TypedAnswerResult`, where mode is kanaReading or romanization and result is match/different/empty. `RecallQuestion` stores activity type, prompt, source SavedStudyID when available, acceptedAnswers, revision and fingerprint. Map RecallQuestion into the existing ExerciseSnapshot kanaReading/romanization kinds and ExerciseResponse.text from Plan 01. Format 5 already carries these response tags; no schema or backup-version change is needed. Never coerce text into choice indexes.

- [ ] Test normalization of composed/half-width kana, whitespace, configured hiragana/katakana equivalence and aliases; verify きて differs from きって, おばさん from おばあさん, and か from が.
- [ ] Implement bounded input (500 characters), Unicode normalization and explicit alias matching. Never collapse voicing, small kana or vowel length. Roman aliases come from a shipped reviewed table (shi/si, chi/ti, tsu/tu, fu/hu), attached to the exact kana entry.
- [ ] Exclude entries without supplied readings; kanji-reading questions require learner-selected on/kun reading rather than silently accepting every unrelated reading.
- [ ] Run policy tests and commit.

Core semantic test:
```swift
XCTAssertEqual(TypedAnswerPolicy.evaluate(input: "きて", accepted: ["きって"], mode: .kanaReading), .different)
XCTAssertEqual(TypedAnswerPolicy.evaluate(input: "キッテ", accepted: ["きって"], mode: .kanaReading), .match)
```

### Task 2: Typed session UI and persistence

**Create:** SwiftUIApps/Sources/Presentations/Learning/TypedPracticeViewModel.swift, TypedPracticeView.swift, TypedPracticeComposer.swift. **Modify:** LearningPracticeView, AppRoutes/AppNavigationStack and history presentation. **Tests:** SwiftUIApps/Tests/TypedPracticeTests.swift; DataKit/Tests/RecallHistoryBackupTests.swift.

- [ ] Test selection snapshots, explicit Check locking, input preserved on save failure, identical retry payload and Next clears the keyboard/draft.
- [ ] Add native mode/kind/list selection, selected count and missing-reading exclusions; show loading/empty/retry and readable accepted answers after Check.
- [ ] Persist raw submitted text and deterministic outcome through the history contract, with mode-specific fingerprint. Resume restores typed response and feedback. English meaning mode uses explicit self-rating after reveal, with its own result type, and does not pretend exact synonym grading.
- [ ] Test format 5 typed payload backup roundtrip, corrupt result/reference rejection and older choice-only histories.
- [ ] Check Japanese keyboard composition, dark/large text and routing; commit.

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
