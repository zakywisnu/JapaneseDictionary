# Applied Japanese practice design

Status: implemented locally on 11 October 2026 following user approval. Human language review and physical-device audio acceptance remain pending.

## Goal and boundaries

Add sentence building, conjugation practice, contextual word reviews, listening comprehension, and a weekly recap. Keep learning local, make grading reproducible, and connect the new activities to the existing history, mistakes, and continuation flows.

- Swift 5 language mode; iOS 18 minimum deployment target.
- No runtime network calls, accounts, backend, sync, speech asset downloads, or server fallback.
- Preserve saved identities, Add-next list order/cursors, current review scheduling, and daily-goal semantics.
- Durable new responses and checkpoints participate in validated backup/recovery; audio and derived recaps do not.
- Forest tokens/components, native router, @Observable state/send view models, explicit Check/Next/Finish, and loading/empty/error/retry states.
- Validate light, dark, and accessibility text sizes. VoiceOver and TestFlight checks remain deferred.
- No mastery, full JLPT coverage, natural-speaker pronunciation, or pitch scoring claims.

## Shared content and history

Ship an original, versioned starter practice JSON resource in DataKit. It holds explicit conjugation answers, sentence token sequences, contextual word prompts, and listening passages/questions. Entries carry stable IDs, positive revisions, topic IDs, explanations, provenance, and content-hash review evidence. A review record names the reviewer, date, checked content hash, and decisions; drafting or generating content never counts as language review. Only entries checked for Japanese correctness and ambiguity are published. Keep draft entries outside the app bundle. Validate the resource in Python and Swift before release. Label the corpus “Original beginner practice”; it is not a new N5–N1 syllabus.

Extend ExerciseSnapshot with optional versioned practice metadata, included in its fingerprint. Old snapshots omit the absent field when encoded so their fingerprints do not change. Metadata stores the full stimulus, topic, supplied reading, approved-answer evidence, and sentence token definitions needed for history/resume after a catalog changes. New kinds: conjugation, sentenceOrder, listeningComprehension. New response: orderedTokens([String]). Keep listening comprehension separate from text transcription and keep self-rated recall separate from checked accuracy.

Format 7 export includes new kinds/metadata/responses. Formats 1–6 restore as before, with no fabricated metadata or attempts. No new SwiftData model is necessary when extending the existing payload models. Unknown versions or malformed token sequences reject before recovery/replacement. Root owns schema, backup, enum switches, routing, generated projects, and audio integration.

## 1. Conjugation

Offer form and word-class filters, a matching count, and 5/10/All practice sizes. First release: at least 24 lemmas: 14 godan verbs covering all nine ending families, 4 ichidan verbs including an explicit -る classification exception, する and 来る, 2 i-adjectives including いい, and 2 na-adjectives. Include 行く as a godan て-form exception and ある as a negative exception. Do not infer classes from spelling or apply adjective て forms to verbs.

Verb targets: polite present, polite negative, plain negative, plain past, and て form. Adjective targets: polite affirmative, plain negative, plain past, and connective て/で. Each lemma has every applicable target with explicit reviewed written and kana variants, English cue, rule explanation, and supplied reading. Grade only enumerated answers under width/NFC/kana-script normalization; preserve voicing, small kana, long vowels, and internal word boundaries. Do not silently accept polite forms for plain prompts. Display dictionary form, meaning, and requested target before Check; answers and rule after submission. Use new conjugation history kind; practice never changes saved-item schedules.

## 2. Sentence building

Start with at least 20 reviewed sentences covering は/が, を, に/へ, で, possession の, negatives, and time expressions. The English cue and optional non-answer hint set the intended meaning. Show reusable system buttons for tokens, a selected sequence, Undo/Clear, and explicit Check. Tokens have unique IDs even when their displayed strings repeat. No drag-only interaction.

Store accepted orders as token-ID sequences, including reviewed alternative word orders; equivalent repeated-token swaps compare by rendered token text. Require every token exactly once. If a valid alternative cannot be bounded and reviewed, rewrite the item. Feedback says “Matches this exercise’s accepted order” or “Try this order”; it does not declare every other Japanese order ungrammatical. Particle-role explanation is revealed afterward. Submitted order and immutable token snapshot survive resume/backup. Unsubmitted drafts may be lost on exit and are not presented as saved.

## 3. Contextual reviews

Add an optional “Use sentence context” setting to Word review setup, default Off. Support due, collection, and list word sessions; mixed/non-word sessions retain their ordinary presentation. Enrich the session before entering review, without altering item identities or order. A reviewed context entry must match the saved word's exact form, reading, and selected meaning evidence; conflicting edited meanings and ambiguous homographs fall back to the ordinary word prompt. Do not publish the currently pending Tatoeba examples as a shortcut.

A context item supplies an authored cloze prompt, a hidden answer-bearing full sentence, supplied reading, translation, and source/credits. No automatic substring replacement (conjugated forms and repeated occurrences are unsafe). Before Reveal, hide the full sentence, translation, reading, hints that expose the answer, and Listen. After Reveal, display those fields plus the saved definition. Ratings remain Again/Got it and go through the existing atomic action; context is self-rated, not objective accuracy. Due dates change only for existing due origins. Optional examples missing or corrupt fall back without blocking review or creating an error that hides the saved word. Record the mode as optional review-event metadata; older events decode as unspecified, not assumed contextual.

## 4. Listening comprehension

Start with the existing six ReadingCatalog passages and their reviewed questions, moved to the shared catalog without changing reading IDs or breaking existing starter path fingerprints. Give listening questions separate stable IDs and activity keys. Audio uses supplied full readings, existing synthesized Japanese speech, and AudioSessionCoordinator. A meaning question has two or more distinct choices and one approved answer. This mode is not dictation or speech recognition and can work when microphone recognition is unavailable.

Before successful playback, Check is disabled. Before submission, hide transcript, supplied reading, translation, target vocabulary, answer text, and explanations; question/answer choices about meaning remain visible. No autoplay. Replay is explicit. After submission, reveal feedback and a “Show transcript” control. If the learner reveals the transcript before answering, turn the remaining questions for that passage into ungraded practice: allow interaction/explanations but do not create checked attempts or accuracy. Persist that reveal policy in the snapshot/checkpoint so resume cannot regain graded status. Played audio is not durable; an unrevealed resumed question requires playback again. Audio failure, stop/interruption, or unavailable voice never records an incorrect answer. Stop when leaving, changing passage, or backgrounding. Move between questions only explicitly; a full successful play may unlock the current passage's questions during one uninterrupted screen visit.

## 5. Weekly recap

Progress gains “Weekly recap”; Today gains a neutral compact recap entry after at least one retained practice event in the period. No notifications, background work, or AI are required. Use the last seven local calendar days including today through the captured current instant, and the immediately preceding seven complete local days. Show both exact date ranges and timezone, checked question counts/accuracy by mode, self-rated first responses separately, active days, and currently outstanding mistakes.

Use first checked attempt per session/content fingerprint for comparison so retry spam does not inflate improvement. Deduplicate UUIDs and ignore future/non-finite timestamps. Show an accuracy change only when both periods have at least ten comparable first attempts in the same mode and unchanged content fingerprints; otherwise say “Not enough comparable practice yet.” Never call a percentage change mastery. Retention may have truncated history; describe all recap results as “From retained local history,” even when no truncation flag exists.

A deterministic next focus uses the most repeated incorrect topic in the current period, then latest miss, then stable topic ID. Require at least two distinct sessions to call it recurring. Include only available, eligible activities; historical unknown/retired topics show history without a broken practice button. With no recurring topic, suggest an outstanding mistake; with no mistakes, offer the next unfinished path step; otherwise offer optional practice. Show the reason and launch existing routes. The recap is derived on open, is not backed up, and does not write learner history merely by viewing.

## Delivery order and acceptance

Shared contracts/content pipeline → conjugation → sentence building → contextual review → listening comprehension → weekly recap → integration. Independent content drafting can run alongside code after contracts settle; one integration owner serializes backups/routes/audio/Tuist. Each phase is independently reviewable. Do not alter the existing eight-step starter path in this release; new activities are optional Learning practice entries.

Acceptance: disk reopen, format 1–7 migration/recovery, historical fingerprint compatibility, save-failure Retry identity, repeated tokens, authored alternatives, exact meaning matching, transcript reveal integrity, silent-mode audible synthesis, timezone/DST comparisons, retired content, and all screen states. Physical-device listening acceptance remains required alongside the earlier pending microphone tests. There is no push/merge authorization from planning alone.


## Execution amendments

The user approved one or two extra tabs; implementation adds one Practice tab and keeps Weekly recap in Progress. Bundled original beginner content has transparent model/rule validation and hash-bound evidence; this is not independent human language approval. UI and provenance explicitly disclose pending independent review. The initial human-review publication gate is not represented as fulfilled. Existing ReadingCatalog data and fingerprints remain unchanged; listening counterparts have distinct IDs. See the implementation plan's Execution result for verification and remaining acceptance checks.
