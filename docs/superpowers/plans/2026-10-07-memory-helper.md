# Help me remember implementation plan

User approved planning and implementation of the proposed on-device word helper. Proceed through the plan in this session, using scoped workers where useful. Do not commit, push or merge without delivery authorization.

## Design

The existing word Detail screen gets a neutral Help me remember action below the dictionary content. It generates two short English fields: a simpler explanation of the supplied meanings and a mnemonic. The original headword, reading, meanings and JLPT level are the only study context. Treat them as data, never instructions. Do not invent readings, extra dictionary senses, translations, example sentences or historical kanji origins. Generated text is optional advice labeled AI-generated; the dictionary stays authoritative.

Use Apple's on-device SystemLanguageModel only. Keep iOS 18 deployment; gate FoundationModels to iOS 26+. Check eligibility, settings, model readiness and Japanese/English support before a request. No server, account, network call or model download added by the app. Availability must refresh on returning to the screen. Existing saved advice remains readable when generation is unavailable.

Each request has a fresh session and guided output. Validate trimmed, nonempty explanation/mnemonic of at most 600 characters each. No automatic save. Regenerate retains the previous advice while working and after a failure. A separate Save suggestion persists both fields to the saved word, without touching dictionary fields, dates, progress or review schedules. Saved content checks the original word context to prevent attaching a late result to a changed/restored item. Saving fails safely for deleted words. Cancellation or leaving Detail must prevent stale result publication.

Persist optional strings on KotobaDataModel; new fields default nil for existing stores. Backups preserve the optional suggestion; existing version-1 documents still decode. Semantic catalog fingerprints ignore learner advice and must remain unchanged. Deleting a word naturally deletes its advice.

The UI follows Forest's existing colors, card radius, system text styles and spacing. Headword remains the focal point. Use plain text controls without sparkle icons, badges or additional brand colors. Idle, unavailable, generating, generated, saved, load failure and save failure states have concrete next actions. No voice or TestFlight work is in scope.

## Tasks

1. **Persistence and compatibility:** add DataKit MemoryAidWord/MemoryAidSuggestion values and saved-word repository; optional model fields; optional BackupWord.memoryAid and strict backup validation; tests for saved reload, unchanged fields, deleted/changed word rejection, rollback, legacy backup decoding, restored advice and stable fingerprint. Observe RED, implement, verify GREEN.
2. **On-device generator:** DomainKit generator protocol/availability/failure values and iOS26 FoundationModels adapter in SwiftUIApps; immutable input, guided two-field response, bounded validation, cancellation, availability/error mapping. Probe real local generation if the model is ready; never present fixtures as live AI output.
3. **Detail flow:** injectable @Observable/state/send helper VM, cancellation and duplicate-request guards, saved-vs-unsaved state; tests for unavailable/no generation, successful generation/no autosave, save failure retry, regenerate failure preserves old result, saved load without model, cancellation/stale completion. Compose shared store repository, add word-only helper card, refresh/cancel with lifecycle. Update DESIGN before UI edits.
4. **Verification:** Tuist generate; full workspace tests and app build; existing disk-store upgrade; live supported-model request plus unavailable/cancel states; light/dark/accessibility-large layouts, word navigation, saved relaunch and kanji exclusion; independent review and diff check. Document actual model-quality results and limitations. No VoiceOver or TestFlight check.

## Execution notes

The user supplied the intended outcome and explicitly asked to plan and implement it in one request. That authorization takes precedence over generic skill steps asking for another artifact approval. Antislop applies as a filter while implementing the established DESIGN direction, without installing files or changing agent instructions. Scope remains the approved memory helper, not chat or sentence feedback.

## Completed — 7 October 2026

All four tasks are implemented. The final production app build and 75 workspace tests pass. Live on-device generation, explicit save, regeneration without autosave, saved relaunch, unavailable and failure states, dark mode, the largest accessibility text size and kanji exclusion were checked in Simulator. Existing disk data survived adding the optional fields. Temporary QA overrides have been removed. See [verification record](../../implementation/memory-helper-verification.md) for evidence and the model sample. The user subsequently authorized committing, pushing and opening a pull request from codex/memory-helper.
