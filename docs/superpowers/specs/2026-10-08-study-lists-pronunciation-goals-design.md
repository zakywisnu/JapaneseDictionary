# Study lists, pronunciation and daily goals

Status: concrete design for user review. The user requested all three features and continued example-sentence work. Product implementation follows approval of this written design and its execution plan.

## Purpose and constraints

Let learners organize words they chose from the offline dictionary, hear supplied readings, and see a clear daily practice target. Keep the iOS 18 / Swift 5 app local, with no accounts, sync, runtime corpus fetches or network-dependent product UI. Preserve learner IDs, saved meanings, AI notes, Add next order/cursors and existing review schedules. Follow DESIGN.md / Forest, existing composer and state/send patterns, native routing and explicit loading/empty/error states. VoiceOver and TestFlight remain deferred.

Implementation proceeds in phases, with scoped agents for independent work when useful, as previously agreed. Each phase must produce usable, tested behavior before integration of the next. The shared store and backup changes are coordinated centrally.

## Chosen approach

Use normalized local list membership referencing existing learner IDs, the system speech synthesizer with an available Japanese voice, and persisted daily practice activity. Reuse the existing review setup/queue and saved detail.

Copying words into each list would create conflicting meanings and schedules, so lists hold references instead. A downloaded audio corpus would require a separate asset/licensing pipeline and more bundle storage; system speech is the first pronunciation implementation. Deriving daily totals solely from review schedules would miss collection practice and overwrite earlier-day activity, so goals use a separate activity ledger.

## Phase 1: custom word lists

### Learner flow

- Collection Words gains a neutral Study lists action alongside Browse dictionary. No new tab. Kanji collection remains unchanged in this first list implementation.
- Study lists shows list names and saved-word counts, with Create list and loading/empty/error guidance. Names are trimmed, nonempty and at most 60 characters. Case/width-insensitive duplicate names are rejected with a concrete message.
- Create/rename use a native sheet with text input, Save and Cancel. Save failures keep entered text available for retry.
- List detail shows its words using StudyRow, a neutral Review list action, and rename/delete controls. An empty list explains adding saved words through Word Detail.
- Saved Word Detail offers Organize in lists. A sheet shows existing lists with independent checkboxes and saves the chosen membership set atomically. A word may belong to multiple lists. Unsaved dictionary entries must first be added to the collection; their detail then links to the saved word.
- Selecting a word opens the existing saved detail. Remove from this list is clearly separate from Remove from collection; list removal never deletes the word or changes progress/schedules.
- Deleting a list asks for confirmation and removes only that list and its memberships. Deleting a word from Collection removes its memberships in the same transaction as existing deletion/progress/review cleanup.
- Review list reuses the current level/limit setup and saved-word snapshots. It reports the list context and returns to the list through native navigation. List practice does not change due-review dates.

### Storage and boundaries

Add StudyListModel (ID, normalized name, display name, creation date) and StudyListMembershipModel (list ID, saved word ID, deterministic membership key). The repository uses fresh contexts, validates referenced lists/words, and saves one transaction per mutation. Duplicate membership requests are idempotent. List ordering is normalized name then ID; words retain newest-added order with learner ID as tie-break.

Expose repository DTOs/use cases rather than live models to views. Composer provides list/membership loaders and mutations. New routes are included in AppNavigationStack's pushed-route filter. List review uses the existing queue and carries its list ID/name as return context; deleting the list during a session does not alter its in-memory snapshot, and return handles a missing list safely.

### Backup compatibility

Introduce backup format 3 independently of vocabulary catalog version 2. Preserve the current catalog fingerprint and progress catalogVersion. New exports contain lists and memberships; the goals phase also adds its settings/activity fields. Accept current format-2 backups and existing format-1 conversion, supplying empty new collections and documented goal defaults. Reject unsupported future formats, duplicate names/IDs/membership keys, missing lists and orphan word memberships before mutation.

Old apps reject format 3 rather than silently dropping new data. Restore writes a recovery backup first, replaces all learner models in one save, rolls back on failure and invalidates routes afterward. List-only fresh stores can have no progress row if there are no words, kanji or reviews. Retain existing validation for populated collections. Upgrading the app must open the old four-model store and preserve every prior learner field.

## Phase 2: pronunciation playback

- Add a neutral Listen / Stop pronunciation control near the reading in saved Word Detail and Dictionary word detail.
- Speak the supplied primary kana reading, including kana-only headwords. Do not infer a reading from a kanji spelling, invent pitch-accent data, or represent synthesized speech as a human recording.
- In word review, playback is available only after Reveal answer. Switching items, hiding the answer, leaving the screen or backgrounding stops playback. No automatic audio reveals an answer.
- Kanji detail may play each explicitly supplied On'yomi/Kun'yomi reading separately when it is speakable kana. Strip dictionary punctuation used to mark inflection boundaries for speech only; retain the original displayed reading. Ambiguous or missing readings do not get guessed pronunciation.
- Select an available Japanese system voice deterministically and use AVSpeechSynthesizer / AVSpeechUtterance. Do not request personal-voice access, microphone access, speech recognition or a network service. This feature is unrelated to VoiceOver.
- If no usable Japanese voice is available, show Japanese voice unavailable with Check again. The app does not download voices. Check availability again when returning to the app.
- Own the synthesizer in a retained main-actor service. One active utterance at a time; a new request replaces prior speech. Delegate completion/cancellation clears the state only for the active utterance, preventing stale callbacks from stopping a newer request.
- Use a finite playback timeout/failure state so a stalled synthesizer cannot leave the button indefinitely in Stop. Stop on disappearance/background and avoid interrupting unrelated playback unnecessarily. Audio/session behavior must be checked on an actual runtime; mock tests prove lifecycle logic, not audible quality.

Apple API references: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer and https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices().

## Phase 3: daily study goal

### Learner flow and defaults

- Today shows a compact daily practice summary: X of Y items practiced today. The initial target is 10; Progress offers a goal setting of Off, 5, 10, 20 or 30. This is a stated implementation default, not a user-selected value.
- Count distinct saved words and kanji marked Got it after answer reveal across Today practice, Collection practice, list practice and Due review. Again does not complete an item. Repeating the same learner ID on the same local calendar day counts once across all session types.
- Listening, browsing and adding words do not count as review. Completion means practice performed, not mastery or a correct-answer percentage.
- When the target is met, show Goal reached. Continue studying freely. No streak penalties, notifications, reminders or extra gamification in this phase.
- Changing the target recomputes progress using the same day's activity; turning it off does not erase history. New local days start at zero. Refresh on screen appearance and foregrounding; inject the date/calendar for testing.

### Persistence and failure semantics

Add a settings model with a validated target and PracticeActivityModel keyed by local Gregorian day + study kind + learner ID. Capture the local day when recording an item; existing recorded day keys remain unchanged after timezone changes. Record a completed activity before advancing the Got it queue. Duplicate requests do not insert or increment twice.

For Due review, schedule save and optional Got it activity save occur in the same transaction. Again updates the due schedule as it does today without adding a completed activity. Keep session-rating idempotence. For practice sessions, save only activity; never change a review schedule or Add next progress. A save failure retains the answer and pending action, offering Retry / Exit. Retries use the originally captured action date/day rather than moving an overnight retry into a new day.

Deleting a saved item keeps already completed daily activity as history; activity is therefore not a live membership reference. Lists, memberships, goal settings and activities are included in format-3 backup/restore. Validate activity keys, supported kinds, finite dates and unique identities; historical activities may reference deleted learner IDs. Older backups receive no activity and the default goal.

Do not derive mastery statistics from Got it. No historical chart or streak display is required for this phase.

## Phase 4: sentence-example preparation and publication

The existing production bundle has zero approved examples. The human approval gate stays intact. No AI analysis is represented as fluent human review.

- Reconcile existing candidate worksheet entries against the current version-2 vocabulary identities and selected study meanings. Retain source sentence IDs, text hashes, credits and license. Ambiguous or missing mappings remain unresolved, never silently assigned to a homograph sense.
- Prepare a focused review batch of common N5 words with current catalog ID, reading, selected study meanings, full sense notes and Japanese/English candidate text. Keep status pending until a fluent reviewer supplies decisions.
- Extend deterministic builder/validation only where needed to bind approvals to the current study sense and exact source text. Changing word context or sentence text invalidates approval. Approved content alone can enter bundled resources; preserve attribution and verified readings.
- Publish the reviewed batch only after receiving explicit human decisions. Until then the empty production bundle and hidden optional cards remain correct behavior. The content-publication dependency does not block lists, audio or goals.

Required external input: a fluent Japanese review of the prepared batch, recorded with reviewer credit, date, intended-sense reasoning and approved/rejected status. The agent can prepare this work but cannot manufacture that input.

## Verification and delivery

Write meaningful tests before new persistence behavior. Cover old disk-store upgrade, list CRUD and idempotent membership, delete cleanup, atomic failure/rollback, current/legacy backup compatibility and format-3 roundtrip. Test daily counts across review modes, duplicate ratings, Again, midnight, timezone/DST, goal changes and retry after failure. Test audio availability, answer gating, repeated taps, cancellation, backgrounding and late callbacks with a fake engine.

Run Tuist after new files; use the full workspace test suite and app Release build. Keep existing vocabulary and sentence-builder regression tests green. Inspect all new screens/states in light/dark and accessibility XXXL. Repeat the live-store preservation comparison; do not claim audible simulator quality or complete UI navigation if runtime tools prevent verification.

Implement on a codex feature branch. Keep reviewable commits local during implementation; push/PR/merge remains the next delivery step after verification. No production example publication without the human content gate.

## Self-review

Shared storage changes and backup versioning are centralized. List practice and daily activity have explicit scheduling semantics. Missing voice/content states are concrete. Migration, duplicate, rollback, recall-answer leakage and human-content approval have named verification requirements. The design makes no network, mastery, recording-quality or approved-content claims.
