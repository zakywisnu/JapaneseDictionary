# Offline speaking check with optional Foundation Models explanations Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Root owns shared schema, backups, routing and integration; workers own disjoint modules. Track completion using the checkboxes below.

**Goal:** Let learners record/replay Japanese speech and compare recognition with the target without claiming acoustic pronunciation grading.

**Architecture:** An on-device speech adapter and audio coordinator produce evidence for a deterministic comparison. Foundation Models optionally explains that evidence; recordings are temporary and never backed up.

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

- Unsupported on-device Japanese recognition must never start server fallback (Task 1).
- Denied permissions, silence, isolated kana and unknown reading alignment produce actionable/inconclusive states (Tasks 1–2).
- Background/interruption/navigation cancels capture and ignores stale recognition/AI callbacks (Tasks 1–3).
- Recording and synthesized playback cannot run concurrently (Task 1).
- Transcript matches must not be promoted to phonetic/pitch accuracy (Tasks 2–3).

### Task 1: Local recording and recognition services

**Create:** SwiftUIApps/Sources/Services/Speaking/AudioSessionCoordinator.swift, SpeakingRecorder.swift, OnDeviceSpeechRecognizer.swift, SpeechTextValidator.swift. **Modify:** existing SystemPronunciationEngine.swift and PronunciationService.swift to share audio ownership; JapaneseDictionary/Project.swift permission strings. **Tests:** SwiftUIApps/Tests/SpeakingLifecycleTests.swift.

**Produces:** `SpeakingRecording(id: UUID, temporaryURL: URL, duration: TimeInterval)`, `SpeechRecognitionEvidence(transcript: String, isFinal: Bool)`, injectable @MainActor protocols for recording/start/stop/cancel/playback and async recognition. Coordinator serializes TTS, recording and recorded playback; restore audio category only while holding its own operation lease.

- [ ] Add capability test double proving supportsOnDeviceRecognition false produces unavailable with zero recognition tasks. Test permissions denied/restricted, recording error, 15-second stop, background/interruption cleanup and stale request IDs.
- [ ] Add NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription truthful purpose text. Ask permissions only on Record; never at startup. Do not mislead the system permission text about its generic speech framework wording.
- [ ] Gate ja-JP recognizer support and availability; set requiresOnDeviceRecognition true unconditionally for supported tasks. No automatic model/asset download and no contextualStrings target hint. Keep empty/partial results out of final comparisons.
- [ ] Extend supplied-reading playback validation to allow kana, Japanese sentence punctuation and spaces without guessing readings, preserving long vowels/voicing/small kana. Cap spoken input at 200 kana/text characters, and test existing word/kanji playback alongside punctuated sentence readings. Record app-owned temporary audio, retain valid recording for replay when recognition fails, delete on retry/exit and clean abandoned speaking files on next launch. Stop engine/remove taps/deactivate owned session in every failure/cancellation path.
- [ ] Test existing Listen playback still works after capture; commit.

Mandatory gate implementation:
```swift
guard recognizer.supportsOnDeviceRecognition else { throw SpeakingError.localRecognitionUnavailable }
request.requiresOnDeviceRecognition = true
request.contextualStrings = []
```

### Task 2: Evidence comparison and speaking screen

**Create:** DomainKit/Sources/Speaking/SpeakingComparison.swift; SwiftUIApps/Sources/Presentations/Speaking/SpeakingViewModel.swift, SpeakingView.swift, SpeakingComposer.swift. **Modify:** saved word/material detail, KanaPracticeView and LearningPracticeView entry points, AppRoutes/AppNavigationStack. **Tests:** DomainKit/Tests/SpeakingComparisonTests.swift; SwiftUIApps/Tests/SpeakingViewModelTests.swift.

**Produces:** `SpeakingTarget(id: String, prompt: String, suppliedReading: String, acceptedWrittenForms: [String])`; `SpeakingComparisonResult` match/different/inconclusive plus expected/recognized text and reason. Outcomes do not save a review rating or clear difficult items. Base release persists no raw audio, transcript or speaking score; this is intentionally session-only.

- [ ] Test punctuation/spacing normalization; known kana orthographic equivalents; unknown kanji-reading alignment; empty/silent/nonfinal evidence; homophones and isolated kana return cautious outcomes. Never erase small tsu or vowel-length distinctions.
- [ ] Implement Listen/Record/Stop/Replay my recording/Try again with explicit state/action transitions. Check only final evidence; retain recording when recognition fails; Cancel/Back stops all work.
- [ ] Display expected and recognized phrase, named match/difference/inconclusive outcome and concise limitation: recognition matching does not assess pitch accent. No percentages or correctness emoji.
- [ ] Eligible entry points need supplied reading; marks without standalone sound are not enabled. Prefer a supplied whole-word example for isolated kana; without one offer listen/replay without a reliable verdict.
- [ ] Verify basic speaking flow with injected services in simulator, light/dark/max text and existing playback regression; commit.

Comparison regression:
```swift
XCTAssertEqual(compare(target: target, evidence: .init(transcript: "", isFinal: true)).outcome, .inconclusive)
XCTAssertEqual(compare(target: target, evidence: .init(transcript: target.prompt, isFinal: true)).outcome, .match)
```
The matched result copy is “The recognizer heard the expected phrase,” never “Perfect pronunciation.”

### Task 3: Optional explanation and real-device acceptance

**Create:** DomainKit/Sources/Speaking/SpeakingFeedbackGenerating.swift, SpeakingFeedbackPrompt.swift; SwiftUIApps/Sources/Services/Speaking/FoundationSpeakingFeedbackGenerator.swift. **Modify:** SpeakingViewModel/View. **Tests:** DomainKit/Tests/SpeakingFeedbackPromptTests.swift; SwiftUIApps/Tests/FoundationSpeakingFeedbackTests.swift.

**Produces:** `SpeakingFeedbackGenerating.generate(target: SpeakingTarget, evidence: SpeechRecognitionEvidence, comparison: SpeakingComparisonResult) async throws -> SpeakingFeedback` (explanation/practiceTip). iOS 26 factory reuses existing model availability classifications; iOS 18 fallback keeps deterministic feedback usable.

- [ ] Test unsupported OS/device/language, model-not-ready, refusal/malformed response, cancellation and stale result; basic comparison remains visible after any AI failure.
- [ ] Bound target/transcript to 500 characters and output fields to 1,000 characters each. Treat supplied text as data, use guided output and validate it. Instruct model to discuss the transcript and practice tips only; reject output containing unsupported pitch/phoneme verdicts or percentage grading. Such filtering is a guardrail, not proof of linguistic reliability; fixed basic feedback is the fallback.
- [ ] Generate only on Explain this result. No audio input, recording upload, auto-generation or mandatory Apple Intelligence. Label output AI-generated.
- [ ] On a real device in airplane mode, verify Japanese local capability, permissions, mic capture, replay, final recognition, interruption handling and cleanup. Use a consented/manual fixture matrix of intended phrases, confusable long-vowel/small-tsu phrases, silence/noise and single kana; document matches/differences/inconclusive behavior without a pronunciation-score claim.
- [ ] If Japanese assets/capability are unavailable, verify the designed unavailable/playback-only state. Do not claim device recognition verified based on simulator fakes.
- [ ] Run full tests/Release, independent review and commit. No TestFlight requirement; real-device audio validation remains an acceptance check for this feature.

Primary API references: Apple supportsOnDeviceRecognition and requiresOnDeviceRecognition documents, AVAudioApplication recording permission, and Foundation Models text generation, linked in the shared spec. Check current SDK interfaces before coding the adapters.

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
