# Pronunciation Playback Implementation Plan

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

**Goal:** Play supplied Japanese readings on request without revealing answers early or using a network speech service.

**Architecture:** A retained main-actor speech service owns an injected engine and active utterance identity. A small reusable view binds Listen/Stop/unavailable/failure states. The system engine uses available Japanese AVSpeechSynthesisVoice entries; no personal voice permission.

## Review Focus

- Missing Japanese voice must disable speech without falling back to an English voice.
- A stale completion/cancellation callback must not stop a newer utterance.
- Recall, item switching, navigation and backgrounding must not leak an answer through audio.
- Kanji punctuation/empty readings must not cause guessed pronunciation or unbounded requests.
- Missing delegate callbacks/audio interruptions must clear the active state with useful recovery.

### Task 1: speech service and testable lifecycle

**Create:** SwiftUIApps/Sources/Services/Pronunciation/PronunciationService.swift, SystemPronunciationEngine.swift; SwiftUIApps/Tests/PronunciationTests.swift.

**Interfaces:** Main-actor protocol engine reports availability and utterance UUID in callbacks. Service state contains idle/playing/unavailable/failed and activeID. Reading normalization is display-independent and bounded; only supplied kana readings are accepted for kanji controls.

```swift
@MainActor protocol PronunciationEngine {
    var hasJapaneseVoice: Bool { get }
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void)
    func stop()
}
// PronunciationService: refreshAvailability(), listen(reading:), stop().
// Completion checks identity before clearing current speech.
guard finishedID == activeID else { return }
```

- [ ] Write fake-engine tests: missing voice refuses playback; repeated Listen replaces current speech once; empty/unbounded reading rejects; normalization removes inflection markers without changing displayed content; stale callbacks ignored; Stop/background/disappearance clear state; simulated timeout is retryable.
- [ ] Run tests RED. Implement AVSpeechSynthesizer retained by engine with utterance.voice explicitly Japanese. Select available voices by stable identifier ordering; stop prior speech at .immediate before replacement. Preserve active utterance object/ID mapping across delegate callbacks. Avoid Personal Voice and microphone/speech-recognition permissions.
- [ ] Main-actor service updates state; injected timeout scheduler stops stalled speech. Calculate a bounded timeout from reading length (minimum 15 seconds, maximum 60). Cancel timeout on completion/stop/new speech; stale timeout IDs must not affect a new utterance. Observe app backgrounding and stop; refresh voices on foreground.
- [ ] Verify actual available voice on runtime, record audible check or precise runtime limitation. Run tests/Release and commit `Add local Japanese pronunciation service`.

### Task 2: pronunciation controls and recall gating

**Create:** SwiftUIApps/Sources/Presentations/Pronunciation/PronunciationControl.swift.
**Modify:** Details/DetailView.swift, Details/DetailComposer.swift; Dictionary/DictionaryBrowseDetailView.swift, DictionaryBrowseComposer.swift; Review/ReviewView.swift, ReviewSession.swift; Composer/AppComposer.swift; SwiftUIApps/Tests/PronunciationTests.swift; DESIGN.md. Presentation paths are under Frameworks/SwiftUIApps/Sources/Presentations/.

**Interfaces:** Control accepts a supplied reading and service. Word review retains its original spokenReading even when display reading is nil for kana-only headwords. Kanji controls accept individual supplied readings rather than the bare character.

```swift
// ReviewItem gains explicit speech context, derived from saved data.
let spokenReading: String?
// Render controls only for the revealed answer.
if viewModel.state.isAnswerVisible, let reading = item.spokenReading {
    PronunciationControl(reading: reading, service: pronunciation)
}
```

- [ ] Add tests proving kana-only words retain their speech reading and kanji character-only entries have no guessed reading. Gate controls and stop speech on reveal→hidden, presentationRevision changes, disappearance and backgrounding. Cover unavailable Check again and failure retry.
- [ ] Add neutral Listen/Stop near the reading in both word details. Add per-reading controls in kanji detail only for validated supplied kana. Use Forest/system text styles and 44pt targets. Label speech synthesized; do not claim human recordings or pitch accents. Update DESIGN.md.
- [ ] Verify long-reading wrapping, stop/new-item behavior and no control during recall in light/dark/XXXL. Full suite/Release; commit `Add pronunciation controls to detail and revealed review answers`.

## Verification command convention

After new sources/tests, run `tuist generate --no-open` centrally. Observe the named new tests failing before implementation, then passing. Focused simulator command:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DataKitTests
```

Replace the final selector with the named framework/class for the task. Prefer configured XcodeBuildMCP test tools when available. End each phase with the full workspace suite, app Release build, Python regressions when affected, and `git diff --check`. Commit verified phase work locally; no push/merge during implementation.
