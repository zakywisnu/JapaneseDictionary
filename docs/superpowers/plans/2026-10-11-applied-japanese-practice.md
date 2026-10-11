# Applied Japanese Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Preserve the user's preference for phases, with orchestration when useful.

**Goal:** Implement all five requested features: conjugation, sentence building, contextual reviews, listening comprehension, and weekly recap.

**Architecture:** Extend the existing immutable exercise payloads and format 7 backups once, then deliver five bounded feature phases. Bundle explicitly reviewed original content; reuse history/checkpoints, atomic review actions, the native router, Forest components, and shared pronunciation/audio services. Compute recaps from retained local history without new persistent models.

**Tech Stack:** Swift 5, iOS 18+, SwiftUI, SwiftData, Tuist, AVFoundation, Python unittest; no new external dependency.

**Spec:** ../specs/2026-10-11-applied-japanese-practice-design.md

## Global Constraints

- Swift 5 language mode; iOS 18 minimum deployment target.
- No runtime network calls, accounts, backend, sync, speech asset downloads, or server fallback.
- Preserve saved identities, Add-next list order/cursors, current review scheduling, and daily-goal semantics.
- Durable new responses and checkpoints participate in validated backup/recovery; audio and derived recaps do not.
- Forest tokens/components, native router, @Observable state/send view models, explicit Check/Next/Finish, and loading/empty/error/retry states.
- Validate light, dark, and accessibility text sizes. VoiceOver and TestFlight checks remain deferred.
- No mastery, full JLPT coverage, natural-speaker pronunciation, or pitch scoring claims.

## Review Focus

1. Previously saved snapshots must retain their exact fingerprint and reopen after new fields are introduced: Task 1 golden JSON fixtures.
2. Repeated sentence tokens and valid alternate orders must not produce false mistakes: Task 3 repeated-token and alternative-order tests.
3. A learner-edited sense or ambiguous homograph must never receive a misleading context: Task 4 edited-meaning and homograph tests.
4. Transcript reveal followed by resume must not turn assisted answers into checked success: Task 5 restart/resume reveal tests.
5. A retained or retired history record must never imply complete lifetime history or produce a broken recap action: Task 6 retention/retired-topic tests.

## Ownership, sequencing, and verification commands

Root owns Task 1 contracts, all backup switches, AppRoutes/AppNavigationStack, AppComposer integration, generated projects, and audio integration. Each remaining phase owns its named feature directory and tests. Use focused workers only after Task 1 lands; never have two workers modify shared history or routes. Content authors may prepare disjoint JSON sections in parallel; root merges and runs the validators. Do not edit learner data for UI tests.

After adding/removing source files: `tuist generate --no-open`. Each test cycle uses the owning framework scheme and test class, then integration runs the workspace scheme:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme DataKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DataKitTests/AppliedPracticeCatalogTests test
# Substitute DomainKit or SwiftUIApps and the named test class below for their tests.
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
python3 -m unittest discover -s tools/data -p 'test_*.py'
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary \
  -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Prefer the configured XcodeBuildMCP equivalents when available. One root process runs Tuist/build/tests at a time. For each task: run its named tests to observe the missing contract/failure, implement, rerun to green, review the diff, then make its scoped commit. No commit/push/PR/merge is implied by the planning request; use commit steps only after execution is authorized.

## Task 1: Durable contracts and reviewed-content pipeline

**Files:**
- Create `Frameworks/DataKit/Sources/Learning/AppliedPractice/PracticeMetadata.swift`, `AppliedPracticeCatalog.swift`, `AppliedPracticeCatalogRepository.swift`.
- Create `data/practice/draft.json`, `data/practice/approved.json`, `data/practice/README.md`, `tools/data/prepare_practice.py`, `tools/data/test_prepare_practice.py`.
- Create `Frameworks/DataKit/Resources/applied-practice.json`.
- Modify `Frameworks/DataKit/Sources/Learning/History/ExerciseHistory.swift`, `ExerciseHistoryValidator.swift`, `ExerciseAnswerNormalizer.swift`.
- Modify `Frameworks/DataKit/Sources/Backup/StudyBackup.swift`, `BackupValidator.swift`, `BackupRepository.swift`.
- Modify enum switch consumers in `Frameworks/DomainKit/Sources/LearningProgress/LearningProgressUseCase.swift`, `Frameworks/SwiftUIApps/Sources/Presentations/Recall/RecallComposer.swift`, `ExerciseResumePolicy.swift`, `RecallSessionViewModel.swift`, and history/mistakes/progress views.
- Create `Frameworks/DataKit/Tests/AppliedPracticeCatalogTests.swift`, `AppliedPracticeBackupTests.swift`; extend `ExerciseHistoryTests.swift`.

**Interfaces:** Define public Codable/Hashable `PracticeMetadata` with `schemaVersion`, `activityKind`, `topicID`, `stimulus`, `suppliedReading`, `translation`, `tokens`, `acceptedOrders`, `source`, `review`, and `assisted`; optional fields encode only when present. Define `PracticeToken(id:String,text:String)`, reviewed provenance structs, and `AppliedPracticeCatalog` with typed conjugation/sentence/context/listening arrays. `AppliedPracticeCatalogRepository.init(data: Data) throws` validates; `bundled() throws -> AppliedPracticeCatalog` propagates required-content errors. `ExerciseSnapshot.metadata: PracticeMetadata?` defaults nil. Add `.conjugation`, `.sentenceOrder`, `.listeningComprehension` and `.orderedTokens([String])`. `ExerciseSnapshot` fingerprints include metadata when present. New review event metadata is optional `contextID:String?`; existing events remain unspecified. Avoid timestamps in content fingerprints.

- [ ] Write compatibility tests before changing encoding. Capture a valid format 6 JSON fixture and its fingerprint from current code. Assert exact old fingerprint, format 6 restore/export compatibility, new kinds roundtrip, malformed sequence rejection, future metadata rejection, atomic rollback, and mixed history disk reopen. Add this core assertion:

```swift
func testOldSnapshotFingerprintIsUnchanged() throws {
    let old = try JSONDecoder().decode(ExerciseSnapshot.self, from: legacySnapshotJSON)
    XCTAssertNil(old.metadata)
    XCTAssertEqual(old.fingerprint, old.computedFingerprint)
}
```

`legacySnapshotJSON` must be committed bytes captured before implementation, not a fixture re-encoded by the changed model. Run the named DataKit test classes; new-contract tests must fail initially.

- [ ] Implement metadata validation: positive known version, stable nonempty IDs (max 256), stimulus/explanations max 20,000 characters, answer text max 500, token count 1–40 with unique IDs, accepted orders 1–20, each order a permutation of every token exactly once. Check provenance/review hashes and response/outcome agreement. Assisted snapshots reject objective attempts. Extend format 7 compatibility and every exhaustive kind switch; do not map new kinds to an old metric to make compilation pass.

```swift
case .sentenceOrder:
    guard let metadata = snapshot.metadata,
          !metadata.tokens.isEmpty,
          metadata.acceptedOrders.allSatisfy({
              $0.count == metadata.tokens.count && Set($0) == Set(metadata.tokens.map(\.id))
          }) else { throw ExerciseHistoryError.invalidRecord }
```

Preserve all existing validator bounds and add the new checks, rather than replacing validation with this fragment. Old nil metadata must not appear as `null` in fingerprint JSON. Rollback tests must verify that invalid new fields do not delete existing saved items, checkpoints, or ratings.

- [ ] Implement the offline content preparation script with deterministic sorted-key UTF-8 output, duplicate/reference validation, explicit draft/approved separation, hash checking, and stable revisions. Hash canonical sorted-key content with the review record excluded to avoid a circular hash; include all answer-bearing fields and provenance. It must refuse unreviewed/changed approved entries and never invent a reviewer. README specifies Japanese correctness, ambiguity, distractors, readings, and alternative-order review checklist. Assert bad hashes, missing reviewers, invalid variants, duplicate tokens/IDs, and deterministic output with Python unittest.
- [ ] Regenerate Tuist, run DataKit migration/history/backup/catalog and all exhaustive-switch consumer tests. Commit scope: `feat: add reviewed applied-practice contracts and format 7 backup`.

## Task 2: Conjugation practice

**Files:**
- Create `Frameworks/DomainKit/Sources/AppliedPractice/ConjugationPolicy.swift` and `Tests/ConjugationPolicyTests.swift`.
- Create `Frameworks/SwiftUIApps/Sources/Presentations/Conjugation/ConjugationComposer.swift`, `ConjugationSetupViewModel.swift`, `ConjugationSetupView.swift`.
- Modify `Presentations/Recall/RecallSessionViewModel.swift`, `RecallSessionView.swift`, `RecallComposer.swift`, `ExerciseResumePolicy.swift` and `Presentations/Learning/LearningPracticeView.swift` (all under SwiftUIApps/Sources).
- Add routes in `Sources/Router/AppRoutes.swift`, `AppNavigationStack.swift` and metrics in existing learning progress files.
- Create `Frameworks/SwiftUIApps/Tests/ConjugationPracticeTests.swift`; add conjugation entries to approved practice JSON.

**Interfaces:** `ConjugationPolicy.matches(_ input:String, accepted:[String]) -> Bool` uses explicit variants and kana normalization, not an inferred conjugation engine. Catalog `ConjugationItem` contains `id`, `revision`, `lemma`, `classID`, `formID`, `meaning`, `answers`, `explanation`, and metadata. `ConjugationSetupViewModel.send` accepts load/class/form/limit/start actions; resulting `[RecallQuestion]` uses `.conjugation`, stable activity keys, and `AppComposer.exercisePersistence(activityKey:)`.

- [ ] Add tests and run DomainKit/ConjugationPolicyTests to fail initially:

```swift
func testTeFormDoesNotAcceptPoliteOrWrongVoicing() {
    XCTAssertTrue(ConjugationPolicy.matches("いって", accepted: ["行って", "いって"]))
    XCTAssertFalse(ConjugationPolicy.matches("いきます", accepted: ["行って", "いって"]))
    XCTAssertFalse(ConjugationPolicy.matches("いで", accepted: ["行って", "いって"]))
}
```

Also test 見る/帰る class differences, する/来る, ある→ない, いい→よかった, na-adjective で, whitespace, composed kana, and no arbitrary suffix guessing. Catalog tests verify all minimum lemma families and applicable target forms listed in the spec.
- [ ] Implement exact supplied-answer grading. Reuse RecallSession state/Check/save-error behavior, extending submit eligibility for conjugation without weakening other kinds. New view setup uses system selectors, counts, empty/retry states and labels “Original beginner practice.” Explanations stay hidden before submission. Eligible Word Detail offers a neutral conjugation link only on exact catalog match; arbitrary saved verbs do not gain invented forms.
- [ ] Test filter intersection/zero results, stable selection, failing save retains draft/action UUID/date, resume keeps feedback, changed revision requires explicit restart, correct retry clears only the same fingerprint, and no review date/daily-goal mutations. Run focused tests, regenerate, inspect light/dark/large text. Commit: `feat: add reviewed conjugation practice`.

## Task 3: Sentence building

**Files:**
- Create `Frameworks/DomainKit/Sources/AppliedPractice/SentenceOrderPolicy.swift`, `Tests/SentenceOrderPolicyTests.swift`.
- Create `Frameworks/SwiftUIApps/Sources/Presentations/SentenceBuilding/SentenceBuildingViewModel.swift`, `SentenceBuildingView.swift`, `SentenceBuildingComposer.swift`.
- Create `Frameworks/SwiftUIApps/Tests/SentenceBuildingTests.swift`.
- Modify native routes, LearningPracticeView, ExerciseResumePolicy/RecallComposer dispatch, history/mistake presentation and progress labels; add approved sentence entries.

**Interfaces:** `SentenceOrderPolicy.matches(_ ids:[String], tokens:[PracticeToken], acceptedOrders:[[String]]) -> Bool` requires an exact token-ID permutation and compares corresponding rendered token strings against accepted orders. VM initializer consumes immutable `[ExerciseSnapshot]`, `activityKey:String`, and `ExercisePersistence`; `send` includes load, append(String), remove(String), undo, clear, check, next, finish, retry, restart. Pending attempt retains response, UUID and timestamp; snapshot supplies tokens for catalog-independent mistake review and resume.

- [ ] Write tests and run DomainKit/SentenceOrderPolicyTests to fail:

```swift
func testRepeatedTokensCompareWithoutLosingIdentity() {
    let tokens = [PracticeToken(id: "a", text: "も"), PracticeToken(id: "b", text: "も")]
    XCTAssertTrue(SentenceOrderPolicy.matches(["b", "a"], tokens: tokens, acceptedOrders: [["a", "b"]]))
    XCTAssertFalse(SentenceOrderPolicy.matches(["a", "a"], tokens: tokens, acceptedOrders: [["a", "b"]]))
}
```

Also test unknown/missing token, reviewed alternate ordering, punctuation tokens, an unlisted order's neutral feedback, and bounded malformed snapshots.
- [ ] Implement a wrapping button layout with token identity separate from text, selected-order buttons removable by tap, Undo/Clear, and one Check primary action. No mandatory drag. Build metadata snapshots from approved corpus; compare only explicit permutations; explanation names particles/roles after Check. Resume submitted order exactly; initial shuffled token bank must be deterministic for the checkpoint/session, not change on view recomputation.
- [ ] Verify at least 20 reviewed items meet topic coverage. SwiftUIApps tests assert Check disabled for partial order, repeated tap cannot duplicate a token, persistence failure keeps pending order, retry records once, next clears state, historical mistake replay uses old metadata after catalog revision, and no scheduled rating. Regenerate, run focused tests and all history/backup consumers, inspect light/dark/large text. Commit: `feat: add sentence building with reviewed alternate orders`.

## Task 4: Contextual word reviews

**Files:**
- Create `Frameworks/DomainKit/Sources/AppliedPractice/ContextReviewUseCase.swift`, `Tests/ContextReviewTests.swift`.
- Modify `Frameworks/SwiftUIApps/Sources/Presentations/Review/ReviewSession.swift`, `ReviewSetupView.swift`, `ReviewView.swift`, `ReviewViewModel.swift`, and composer factories that assemble due/collection/list sessions.
- Create `Frameworks/SwiftUIApps/Tests/ContextReviewPresentationTests.swift`.
- Modify `Frameworks/DataKit/Sources/Learning/History/ReviewRatingEvent.swift` and `Sources/Difficulty/StudyRatingRepository.swift` to preserve optional contextID atomically; extend backup tests.
- Add at least 20 reviewed contextual prompts linked to exact catalog-selected meanings in approved JSON, independently of the pending Tatoeba bundle.

**Interfaces:** `ContextReviewUseCase.context(for key:ExampleWordKey, savedMeanings:[String], catalogID:String?) -> ReviewedContext?`; `ReviewedContext` includes stable ID, authored cloze, full Japanese/reading/translation, exact selected-meaning evidence and provenance. `ReviewSession.useSentenceContext:Bool` defaults false; `ReviewItem.context:ReviewedContext?` defaults nil. Enrich sessions once; the VM never derives context from arbitrary string replacement. Preserve the existing rating interface by adding optional contextID with default nil at the repository boundary.

- [ ] Add failing Domain tests for an exact meaning match, an edited conflicting meaning, two identical-form/reading homographs with different senses, empty optional examples, and absent metadata. Use these required assertions in fixtures:

```swift
XCTAssertNotNil(useCase.context(for: exactKey, savedMeanings: approvedMeanings, catalogID: approvedCatalogID))
XCTAssertNil(useCase.context(for: exactKey, savedMeanings: ["learner-changed unrelated meaning"], catalogID: approvedCatalogID))
```

Define the fixture key, approved meanings and selected-sense catalog identity in ContextReviewTests from a complete explicit context entry; avoid matching meaning by arbitrary substring.
- [ ] Add a default-Off setup toggle for word sessions. Match exact identifiers and selected sense evidence, otherwise ordinary prompt. Before Reveal, render only authored cloze and neutral cue; after Reveal, show supplied full sentence, translation, reading, saved meanings, credits, and Listen. Stop speech on hiding/changing/exiting; no pre-reveal audio or answer-bearing metadata. Optional catalog loading failure silently removes enrichment, not saved word review.
- [ ] Add presentation tests for all hidden fields before Reveal, non-word fallback, unchanged queue order/composite IDs, Again/Got it, due-only schedules, first-response counts, once-per-day goal deduplication, contextID roundtrip, and atomic retry with the same action ID/date. Regenerate, run Review/StudyRating/Backup/Pronunciation tests, inspect modes. Commit: `feat: add optional sentence context to word reviews`.

## Task 5: Listening comprehension

**Files:**
- Create `Frameworks/SwiftUIApps/Sources/Presentations/ListeningComprehension/ListeningComprehensionViewModel.swift`, `ListeningComprehensionView.swift`, `ListeningComprehensionComposer.swift`.
- Create `Frameworks/SwiftUIApps/Tests/ListeningComprehensionTests.swift`.
- Modify `Presentations/Learning/ReadingCatalog.swift`, ReadingPractice view/model, ReadingCatalog consumers, LearningPracticeView, and native routes.
- Modify resume/mistakes dispatch and progress summaries for `.listeningComprehension`; extend metadata/checkpoint validator tests for assisted state.
- Move six existing passages into approved practice resource with stable IDs, exact existing reading question bytes, supplied readings and separate listening questions/IDs.

**Interfaces:** VM consumes passage metadata, ordered `.listeningComprehension` snapshots, `ExercisePersistence`, and injected `PronunciationService`. `send` includes load/play/playbackChanged/stop/choose(Int)/check/revealTranscript/next/finish/retry/restart/cancel. `state.heardPlayback` is transient; `metadata.assisted` is durable across all remaining questions of the revealed passage. For a graded submitted question, retain its original immutable snapshot/attempt; do not mutate its fingerprint to assisted. Assist only unanswered snapshots and save the changed checkpoint before showing transcript. History dispatch recreates the matching original listening stimulus.

- [ ] Write failing tests with a fake playback engine: successful completion unlocks Check; failure/unavailable/explicit Stop/background do not; no autoplay; old completion cannot unlock new passage. Test `.revealTranscript` save failure keeps transcript hidden and exposes Retry, successful reveal marks all remaining questions assisted, and reload must retain that flag. Core behavior:

```swift
viewModel.send(.revealTranscript)
XCTAssertTrue(viewModel.state.assisted)
viewModel.send(.choose(0))
viewModel.send(.check)
XCTAssertEqual(recordedAttempts.count, 0)
```

Use an initialized loaded VM and a recording persistence spy in ListeningComprehensionTests. In an unassisted sister test, successful playback followed by Check records exactly one attempt of the new kind.
- [ ] Implement neutral Listen/Stop/Replay, meaning choices and single Check, explicit transcript reveal, feedback, Next/Finish and assist explanation. Keep reading/translation/vocabulary/full transcript absent from pre-answer UI. Feedback before optional transcript reveal must not quote evidence that gives away unanswered questions; corpus review must check cross-question leakage. After a checked answer, transcript for that answered question may be shown; because it assists later questions, mark the remaining passage questions assisted before showing it. Never persist playback completion. Stop through existing AudioSessionCoordinator leases; no microphone or recognition dependency.
- [ ] Preserve old ReadingCatalog/StarterPathCatalog fingerprints in golden tests while migrating resource storage. Add tests for resume requiring playback, checkpoint atomicity, assisted session finish, old catalog revisions, same-passage/multiple-question behavior, transcript remaining absent after failed save, history accuracy separation, and no fake wrong answer on interrupted audio. Run Reading/StarterPath/Recall/Pronunciation/Backup tests. Inspect light/dark/large text; test audible synthesis/interruption on a physical iPhone when available, documenting pending hardware acceptance otherwise. Commit: `feat: add listening comprehension with honest transcript-assisted practice`.

## Task 6: Weekly recap and next focus

**Files:**
- Create `Frameworks/DomainKit/Sources/LearningProgress/WeeklyRecapUseCase.swift`, `WeeklyRecap.swift`, `Tests/WeeklyRecapTests.swift`.
- Create `Frameworks/SwiftUIApps/Sources/Presentations/WeeklyRecap/WeeklyRecapViewModel.swift`, `WeeklyRecapView.swift`, `WeeklyRecapComposer.swift`, `Tests/WeeklyRecapPresentationTests.swift`.
- Modify `Presentations/LearningProgress/LearningProgressView.swift`, `Presentations/LearningPath/TodayLearningHeader.swift`, and native routes.
- Extend existing progress mode labels/counts; no recap SwiftData model or backup array.

**Interfaces:** `WeeklyRecapUseCase.execute(now:Date, calendar:Calendar) throws -> WeeklyRecap` injects loaders for attempts/review events/path progress and available activity/topic IDs. `WeeklyRecap` exposes exact current/prior DateIntervals, per-kind first-attempt counts, comparable deltas, self-rated counts, recurringTopics, and `focus:WeeklyFocus?`. `WeeklyFocus` is a typed route descriptor and a plain reason; no arbitrary URL or generated claim. A `FirstAttemptKey(sessionID:UUID,fingerprint:String)` deduplicates current/prior comparisons. Current retained-history copy is always explicit.

- [ ] Write failing Domain tests for timezone midnight, spring/fall DST, empty periods, future timestamps, duplicate IDs, ten-sample threshold, differing fingerprints, repeated attempts in one session, prior-window first Again/later Got it, deleted saved items, retired topic and unknown metadata. Require:

```swift
XCTAssertNil(recap.comparableDelta[.conjugation]) // fewer than ten comparable first attempts
XCTAssertEqual(recap.recurringTopics.first?.topicID, "godan-te") // two distinct sessions
XCTAssertFalse(recap.availableFocusIDs.contains("retired-topic"))
```

Use fixture timestamps relative to an injected Calendar with an explicit timezone, never Date() in expected calculations. Test no-data copy and current mistakes separately from mistakes in the week.
- [ ] Implement read-only aggregation, a deterministic focus (repeat sessions → latest miss → topic ID), unavailable-topic exclusion, mistakes/path/optional-practice fallback and exact range labels. Compare unchanged content within each mode, expose sample denominators, and label percentage changes as percentage points. First response/self-rating is separate; exercise retries do not become daily-goal completions. No AI, reminder or cached persisted recap.
- [ ] Implement native recap route and onAppear reload with retry. Today neutral entry only when retained current-period activity exists; Progress route always available with empty guidance. Tests cover error clearing stale summaries, loader retry, disabled retired-content navigation, focus opening a valid native activity, no writes on viewing, and no manufactured improvement. Run focused Domain/UI tests, regenerate and inspect light/dark/large text. Commit: `feat: add retained-history weekly recap and next focus`.

## Task 7: Integrate, review, and document

**Files:** modify `DESIGN.md` before any necessary design token/component changes, `docs/superpowers/plans/2026-10-11-applied-japanese-practice.md`, generated framework project files, app routes/composer integration. Modify `Frameworks/SwiftUIApps/Sources/Presentations/Speaking/SpeakingView.swift` only to clarify simulator/unavailable guidance if included as a scoped copy fix; it is not a sixth practice feature.

- [ ] Verify content minimums: 24 lemmas and all applicable forms, 20 sentences, 20 contexts, six listening passages with at least two reviewed meaning questions each. Content review evidence must match exact bundled bytes. If review is unavailable, retain draft data outside bundle and report the blocked content acceptance; do not represent synthetic reviews as complete.
- [ ] Run full workspace tests, Python data tests, Debug and Release builds, and `git diff --check`. Verify original format 6 fingerprints plus formats 1–7 recovery/roundtrips. Walk Continue learning → each new mode → Finish/Exit → History/Mistakes → backup/reopen; ensure existing eight-step path still resumes unchanged. Verify all enum modes remain distinct in progress.
- [ ] Review offline behavior, source attribution, small/large lists, audio lifecycle, and content-switch leakage. Independently review shared persistence and new grading policies when orchestration is used. Fix findings before claiming completion; do not broaden the scope to speech scoring.
- [ ] Document counts, actual test/build results, content-review evidence, UI checks and any pending physical-device audio acceptance. Update plan checkboxes to completed only with evidence. Commit: `docs: document applied practice and verified acceptance`. Push/create/merge only on explicit user request.

## Self-review and execution handoff

Each of the five requests has a complete phase (Tasks 2–6), and shared compatibility requirements belong to Task 1. The five Review Focus risks map to their owning tests. New enum kinds, token responses, optional metadata and format 7 are defined before UI consumers. Original reading and historical snapshot fingerprints are protected explicitly. Context review retains the existing self-rating/scheduling semantics; assisted listening never inflates objective accuracy. New content is bounded original beginner practice, with a publication gate for real language review.

Recommended execution: phase by phase, with focused orchestration for disjoint content/features after shared contracts pass. The user's earlier execution preference is preserved. This planning request does not start implementation, alter app code, or authorize publication.


## Execution result — 11 October 2026

All five feature phases are implemented on `codex/applied-japanese-practice`. One additional native Practice tab contains the study modes; Weekly recap remains in Progress. No commit, push, PR, or merge was performed for this change.

- [x] Shared optional metadata, ordered-token response, three distinct exercise kinds, context event IDs, and format 7 backup validation.
- [x] Conjugation filters, explicit grading, resume/history, and eligible Word Detail entry.
- [x] Sentence building with shuffled tap tokens, undo/clear, duplicate-token equivalence, and accepted alternate phrase orders.
- [x] Opt-in contextual word-only review sessions with exact saved-meaning matching and ordinary fallback; mixed sessions stay unchanged.
- [x] Listening comprehension, successful-playback gating, atomic transcript assistance, immutable submitted answers, and ungraded assisted questions.
- [x] Retained-history weekly recap, separate self-rating/checked metrics, comparable-sample gating, and native next-focus routing.
- [x] Independent core and final code reviews. Fixed alternate sentence orders, context-ID bounds, listening mistake playback mode, repeat conjugation navigation, and mixed-session context enrichment.
- [x] Full workspace verification: 360 Swift tests passed, one existing FoundationModels availability test skipped, no warnings/errors. All 53 Python tests passed; deterministic content `--check` and `git diff --check` passed. Debug launch and Release build succeeded.
- [x] Simulator inspection: light/normal text, dark/accessibility-medium and extra-large. Checked native tabs/back navigation, conjugation setup, sentence selection/clear, listening pre-answer gating, and empty recap. No graded answers or review ratings were inserted into the learner's collection for UI checks.
- [ ] Independent human Japanese language review.
- [ ] Physical iPhone audio/interruption acceptance. Automated system Japanese playback tests pass; this does not establish physical-device audibility.

The detailed task checklists above preserve the original acceptance proposal. Execution differs in two documented ways: the bundled starter corpus is transparently model-authored and model/rule-checked, with human review pending, rather than claiming independent human approval; existing ReadingCatalog content and fingerprints remain in place, with listening counterparts given new IDs instead of moving the original catalog. These choices preserve attribution and existing path/checkpoint compatibility. The corpus includes 24 lemmas / 116 conjugation questions, 21 sentence questions, 20 exact-meaning contexts, and six passages / 12 listening questions. Hash-bound evidence protects answer-bearing content and provenance. It is beginner practice, not a complete JLPT syllabus.

Simulator mouse scrolling did not reliably expose every lower control at the largest accessibility size. Accessible-medium controls and tap/clear were inspected; a full largest-size gesture walkthrough remains part of physical-device acceptance.


## Follow-up verification — 11 October 2026

User requested continuation. Added five targeted acceptance tests: failed listening initial-save timestamp preservation, failed restart checkpoint identity and assistance reset after successful save, context preference roundtrip/legacy reset, new-history rollback after an actual replacement save failure, and changed sentence content requiring atomic restart. Two listening tests failed before the fix and passed afterward. Listening load/restart now retain pending checkpoint IDs/timestamps on retry; unrelated actions cannot discard a pending failed answer.

Full workspace: 365 passed, one existing FoundationModels skip, no warnings/errors. Python: 53 passed; deterministic catalog check passed. Added `data/practice/README.md` and `review-packet.md` with every stable content ID, all accepted forms/orders, listening choices, exact context evidence, and draft byte hash. The packet is a review aid and records no human approval. No content or learner records were altered by this follow-up. Human review and physical-device acceptance remain pending.
