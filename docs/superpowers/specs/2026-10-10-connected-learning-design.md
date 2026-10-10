# Connected learning and offline speaking practice

Status: implemented locally, including follow-through UI details; real-iPhone audio acceptance pending.
Date: 2026-10-10
Baseline: main d30af57, PR #9 merged.

## Scope and intent

Connect the app's existing activities into an ongoing learning experience. This covers the six recommendations (exercise history/mistake review, listening, typed answers, reading-to-collection, beginner path, useful progress), the Today UI improvement and the subsequent speaking check. Maintain local-only operation and preserve learner records.

## Shared constraints

- Deployment target remains iOS 18; Swift 5 language mode.
- No runtime network, accounts, backend, sync, or server recognition fallback.
- Foundation Models explanations are optional and gated to iOS 26+, eligible hardware, enabled Apple Intelligence, ready model and supported languages.
- Use Forest tokens, existing components and native AppRouter paths; update DESIGN.md before UI code.
- Preserve deterministic Add-next ordering, word/kanji indexes, saved identities and existing review scheduling semantics.
- Learner persistence is SwiftData; all new durable records belong in export, restore and recovery backups.
- No pitch-accent, phoneme-accuracy, mastery or calibrated pronunciation-percentage claims.
- Verify light/dark and accessibility text sizes; VoiceOver and TestFlight remain deferred.

## 1. Exercise history and mistakes

Move grammar/comprehension identities and their immutable content snapshots into DataKit-compatible Codable values; keep screen rendering in SwiftUIApps. Persist each submitted answer and the next checkpoint in one transaction before advancing UI. Retry retains attempt ID and timestamp. Each exercise snapshot includes ID, corpus revision, content fingerprint, prompt, choices, correct answer and explanation, so historical outcomes do not silently change after a corpus update.

Persist review rating events in the existing atomic schedule/difficulty/activity transaction, keyed by action ID. New self-rated first-try recall metrics use the first event per session/item; older missing events are not invented. Keep at most one unfinished checkpoint per activity key (grammar deck, passage ID, typed/listening selection). Resume preserves question order, selected-answer/reveal state, score and remaining queue; restarting is explicit. Duplicate submit creates no extra attempt. Mistake review offers the latest incorrect question per exercise fingerprint, not an endlessly growing duplicate queue. A later correct submitted answer removes it from that queue, while history remains. Unavailable/changed content starts a fresh session with an explanation; old history stays readable.

Backups advance to format 5 for attempt/checkpoint/review-rating records and format 6 when path state is introduced. Define tagged choice/text/self-rating response payloads in format 5 from the start. Current format 4 and older formats restore with empty new records; format 5 restores with empty path state. Validate IDs, bounded snapshot fields, timestamps, answer indexes and checkpoint references before replacement. Historical snapshots may refer to retired bundled questions. Unknown optional future kinds are rejected with a cause rather than discarded. Raw recordings never enter backups.

## 2. Listening and typed recall

Listening plays only supplied, validated Japanese readings, hides prompt/reading/meaning until reveal, and lets the learner answer before seeing feedback. Start with short whole words and sentence cards; do not guess readings. Kana uses its catalog's explicit sound labels. Replay is explicit; no hidden automatic playback after Next. Recognition of a playback answer is not a speaking check.

Typed practice offers kana romanization and vocabulary kana-reading prompts. Normalize Unicode composition, whitespace and equivalent full/half-width kana; allow configured hiragana/katakana equivalents and catalog-defined romanization aliases. Keep small kana, voicing, small tsu and vowel length distinct. English-meaning recall is self-rated after reveal; do not grade arbitrary English synonyms by exact equality or AI. Both modes use the exercise-history/checkpoint system. Mode-specific results stay separate from self-rated review accuracy; no automatic due-date or difficulty mutation from a quiz score. Offer explicit standard Review for saved items.

## 3. Reading-to-collection

Keep existing passage -> vocabulary search -> dictionary detail routing. Pass passage ID/title as an optional context. Add explicit Save to passage list, which creates/reuses a list keyed to the stable passage ID and adds the exact selected saved-word identity. Preserve vocabulary dictionary sense selection. Saving a word and adding membership is one transaction: on failure neither is added. Existing words are reused by current catalog identity without overwriting learner meaning/date. Add-next indexes stay unchanged. Passage detail shows saved count and Review passage vocabulary only for actual members. Ambiguous dictionary queries require learner selection; never auto-save the first search hit.

## 4. Beginner path and Today

Bundle a small, visibly labeled beginner path referencing actual kana groups, the existing grammar questions and six original passages. Suggested order: hiragana basics, voiced sounds, katakana basics, contracted sounds, particles, first passage, polite verb forms, later passages. References are validated against shipped content; completion means a specified activity was completed, not language mastery. Completion criteria require each referenced item attempted in the current content revision, with no minimum correctness gate; show mistakes separately.

Persist the current step and explicit completed revisions. Let learners skip/revisit with transparent status. Today shows one Continue learning primary action from an unfinished checkpoint or current path step and a neutral Daily study plan summary using real counts. Put these in scrollable main content rather than growing the fixed header. Keep the current study-kind selector and Add-next actions accessible. No new tab is necessary.

## 5. Progress

Separate collection size, self-rated review activity and objectively marked exercise outcomes. Report counts with denominators and date range, e.g. 12 of 18 submitted grammar answers correct this week. Use submission timestamps and the learner's current local-calendar day boundaries; maintain an explicit timezone policy in tests. Show recent activity, mistakes by content type, path completion and remaining due count. Empty history says what to practice. Recognition matches are recognition outcomes, never pronunciation accuracy. Exercises/listening/typing do not silently inflate the existing distinct-saved-item daily goal; show separate activity totals until a broader goal is explicitly designed.

## 6. Speaking check

Entry points: saved-word/detail, kana practice (prefer a supplied whole-word example for isolated sounds) and supplied short sentences/passages. Listen -> Record -> Stop -> Replay my recording -> Check recognized phrase -> Try again. Capture at most 15 seconds; require a supported Japanese on-device recognizer before starting. Use SFSpeechRecognizer locale ja-JP on iOS 18+, require supportsOnDeviceRecognition and request.requiresOnDeviceRecognition = true. Ask microphone and speech permissions only after Record. Do not initiate asset downloads; unavailable local recognition gives playback-only practice with a clear explanation. SpeechAnalyzer is an optional future adapter, not a requirement for this release.

Extend supplied-reading speech validation to accept kana sentence punctuation and spaces, with the existing 200-character playback bound. Use one audio-session coordinator across synthesized speech, learner playback and recording. Starting recording stops playback; changing route, interruption/background, Cancel and deinit stop capture, remove taps, invalidate async IDs and clean temporary audio. Completed audio lives only for the current speaking screen and is deleted on retry/exit; clean abandoned app-owned temporary files on next launch. Recognition cancellation/failure still permits replay when a valid recording exists.

Feedback has three states: recognized phrase matches, recognized phrase differs, unable to compare reliably. Display expected phrase and recognized text. Canonicalize punctuation/spacing and configured orthographic alternatives only. Do not invent kana readings for recognized kanji. Matching written kanji can identify a phrase but cannot prove its pronunciation. Isolated kana, unclear/empty audio, unknown reading alignment and unstable recognition return inconclusive rather than an incorrect-pronunciation verdict. Do not pass the target as contextual recognition bias.

Optional Foundation Models Explain this result receives only bounded expected text/reading, recognized text and deterministic match evidence. No audio is sent to the language model. It may explain a spelling/read-back difference and offer a practice tip; it must not infer a pitch error, missing mora or phonetic error from transcription alone. Guided output is validated; failed/refused/cancelled generation leaves the basic feedback available. Mark explanation AI-generated and optional. Core speaking comparison works without Apple Intelligence.

Real-device verification in airplane mode is required before claiming Japanese offline recognition works on that device. Use supplied recordings or consented developer recordings with intended and confusable readings, silence and background noise. Report recognition reliability, not a validated pronunciation score. A real acoustic scoring model needs a separate evaluated project and is outside this plan.

## Platform references checked 2026-10-10

- https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition
- https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition
- https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
- https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models

## Execution boundaries

Use dependent phases, with disjoint workers for listening and typed practice after history contracts are stable. Centralize schema, backup, routing and audio-session integration. Each phase can be reviewed and shipped independently. Planning does not publish or implement these features. Future implementation remains authorized only when the user asks to execute it.
