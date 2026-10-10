# Connected Learning Implementation Roadmap

> **For agentic workers:** Execute the linked feature plans phase by phase using superpowers:subagent-driven-development or superpowers:executing-plans. Root owns schema, backup versions, routing and audio integration; delegate only disjoint modules.

**Goal:** Connect existing practice into lasting progress, add listening/typed recall and provide an honest offline speaking check.

**Architecture:** Shared durable attempt/checkpoint contracts support history, mistakes and learning continuity. Existing saved-word/card review semantics remain intact. Speech recognition supplies transcription evidence; optional Foundation Models text explanations do not grade audio.

**Tech Stack:** Swift 5, iOS 18+, SwiftUI, SwiftData, Tuist, AVFoundation, Speech; Foundation Models optional on iOS 26+.

**Spec:** ../specs/2026-10-10-connected-learning-design.md

## Global constraints

- No runtime network, accounts, backend, sync, or server recognition fallback.
- Preserve current learner data, saved identities and deterministic Add-next indexes.
- Add durable state to validated backup/recovery; never include raw recordings.
- Forest UI and native router; loading/empty/retry and light/dark/large-text checks.
- No mastery, pitch-accent or percentage pronunciation-score claims.
- VoiceOver/TestFlight remain deferred; speaking needs real-device audio acceptance.

## Scope

All six recommendations plus Today UI and speaking practice are included. Implementation was authorized after planning and completed locally on codex/connected-learning. Beginner exercises and passages remain labeled original starter material.

| Phase | Deliverable | Dependency | Plan |
|---|---|---|---|
| 1 | Exercise history, resumable sessions, mistake review and review-rating history | Current app | [History](2026-10-10-01-exercise-history.md) |
| 2 | Save passage vocabulary into a reusable list and review it | Phase 1 backup contract | [Reading to collection](2026-10-10-02-reading-collection.md) |
| 3 | Typed kana/reading recall and listening recall | Phase 1 history; shared audio coordinator | [Typed](2026-10-10-03-typed-practice.md), [Listening](2026-10-10-04-listening-practice.md) |
| 4 | Beginner path, Continue learning on Today and meaningful progress | History and completed practice contracts | [Path and Today](2026-10-10-05-guided-path-today.md), [Progress](2026-10-10-06-learning-progress.md) |
| 5 | Record/replay, Japanese recognition comparison and optional AI explanation | Speaking capability/audio work below; other phases not required for base speaking | [Speaking](2026-10-10-07-offline-speaking.md) |

Do Plan 07 Task 1 (capability, permissions and audio coordinator) early, before Phase 3 listening integration. This validates hardware support without letting optional recognition availability block unrelated features. Complete Plan 07 Tasks 2–3 later as the independently reviewable speaking feature.

## Review focus

1. Save failure cannot advance a queue, lose a draft or double-count Retry.
2. Backup replacement validates all new records before modifying the current collection.
3. Answer normalization does not erase Japanese sound distinctions.
4. Audio interruption and late callbacks do not restart capture/playback after leaving.
5. Unsupported offline recognition never falls back to a network request.

Each input is assigned tests in its feature plan.

## Execution checklist

- [x] Create a codex/ feature branch and record each plan's owned tasks and contracts.
- [x] Implement/review history with real disk reopen, migration and format 5 recovery tests.
- [x] Implement/review passage list saving with atomic word/membership failure tests.
- [x] Implement capability/audio coordinator with offline-only and cancellation tests.
- [x] Implement typed and listening modules with separate worker ownership; root integrates shared history/routes/audio.
- [x] Implement the path/Today layout, format 6 path backups and read-only progress queries.
- [x] Implement speaking comparison and optional Foundation Models explanation; verify simulator unavailable behavior.
- [ ] Validate microphone, replay and supported recognition on a real iPhone in airplane mode.
- [x] Run independent reviews, full workspace tests, Python data tests and Release build; record runtime evidence.
- [x] Deliver phases separately when requested; do not infer permission to push or merge from this plan.

## Scope boundaries

The speaking MVP checks what the recognizer heard, not whether every sound or pitch accent was correct. A dedicated acoustic scoring model, trained/evaluated Japanese pronunciation dataset and human score calibration require a separate future project. No speech assets are downloaded by the app. Missing assets, permissions or hardware produce a usable unavailable/playback-only state.

Existing first-review scheduling remains the app's current behavior. Exercise/typing/listening outcomes do not silently create scheduled ratings or inflate the saved-item daily goal. Progress distinguishes objectively checked answers, self-reported recall and recognition matches.

## Self-review

- All requested features map to a linked plan; Today improvements belong to Plan 05.
- History defines choice/text/self-rating payloads up front. Phase 1 uses format 5; path state later uses format 6, with older-version restore tests.
- Root serializes schema/backups/builds. Typed/listening modules can be delegated after interfaces settle; both consume the same durable history contract.
- Audio coordinator is introduced once in Plan 07 Task 1 and reused by playback/listening/speaking.
- Each phase specifies failure tests, files, interfaces, completion checks and commit boundaries. No code changes were made while planning.

Recommended execution: dependent phases, using focused workers for typed/listening and an independent review at each phase. This follows the user's earlier preference for phases with orchestration when useful.

## Implementation verification (2026-10-10)

All roadmap features are wired through the native router. Durable answers, resumable sessions, review events, passage-list source identity and learning paths participate in format 6 export/restore/recovery. Older formats default to empty new history/path state. Audio is session-only and never exported.

Validation: 315 Swift tests passed, one existing Foundation Models error-construction test skipped; 45 Python data tests passed. Debug and Release simulator builds succeeded without warnings. Light/dark and accessibility-extra-large layouts checked for Today/Continue, typed/listening, starter path and speaking; Progress content verified. Temporary QA startup routing was removed. No publish/PR/merge performed.

Remaining hardware acceptance: real iPhone microphone capture/replay/15-second limit, interruptions/routes, and Japanese recognition in airplane mode. The simulator lacks on-device Japanese recognition and correctly keeps Record unavailable while Listen remains usable. Optional AI output selects validated, reviewed transcript explanations and practice tips; it cannot provide acoustic scores or pitch judgments. Device acceptance is pending, not a claim of verified device performance.

## Follow-through details

Speaking is linked from eligible sentence/custom-card details using supplied readings. Starter path shows current/attempted state and completing an explicitly finished, fully answered step advances it in the same transaction as checkpoint removal. Revealed/skipped questions do not claim completion. Progress groups remaining mistakes by answer type and shows distinct due items now, including first reviews; the due count is independent of selected history dates. Today displays the existing daily-plan recommended batch counts with a neutral Open plan action. All these details are implemented; real-device audio acceptance is still pending.
