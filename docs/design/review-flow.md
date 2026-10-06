# Review today's words and kanji

Status: implemented in the iPhone app. The interactive design preview remains a sample of the flow.

## Purpose

Turn the items collected on Today into a short recall exercise. A learner should be able to start with one tap, attempt a reading and meaning, reveal the answer, and finish without setup. The flow uses saved local items and bundled definitions. Collection counts continue to describe items added, rather than mastery.

## Entry point

Keep Add next word / Add next kanji as Today's moss primary action. Add a neutral, full-width Review today's words / Review today's kanji button in the Added today section header area, before the rows. Show it only when the selected kind has at least one saved item today and loading has succeeded. Add a short caption: Try the reading and meaning before revealing the answer.

Use the existing Words / Kanji selection to determine the session. Do not add a separate setup screen or mix both kinds in a session. Push the review screen with AppRouter and the app's native navigation stack; keep the tab bar hidden during the focused exercise, as on Detail.

## Session sequence

1. **Recall.** Title: Review words or Review kanji. A quiet item position reads Word 1 of 3 / Kanji 1 of 3. Show the headword in the existing practice squares and its JLPT tag. Hide every reading and meaning. Prompt: Try the reading and meaning. Primary action: Reveal answer.
2. **Answer.** Retain the headword in place. Show the reading (when different from the headword) and meanings. Kanji separates On'yomi, Kun'yomi, and Strokes using the existing definition-card styling; omit missing fields. Primary action: Next word / Next kanji, or Finish review on the final item. Do not advance automatically or ask the learner to score themselves.
3. **Complete.** Title: Review complete. Copy: You've gone through 3 words added today. Primary action: Back to Today. Secondary neutral action: Review again. Use singular grammar for one word and the unchanged plural kanji. No percentage score, mastery claim, streak, or celebration animation.

The existing native back action exits at any time without confirmation: reviewing does not write to the collection or saved progress. A neutral Previous action is available after the first item; revisiting an item hides its answer again so it can be attempted anew.

## Layout and behavior

- Reuse Forest colors, spacing and radii, PracticeCells / Headword, LevelTag, PrimaryButtonStyle, and StateMessage. Preserve Mincho for headwords and system text styles for supporting copy.
- Put the content in a ScrollView, with the one primary action inset above the bottom safe area. Long definitions and large text scroll while the action remains reachable.
- Fit headword cells using the existing detail sizes and plain-text fallback. Reserve the reading area for the revealed state; no hidden reading may remain in the visible prompt.
- Show item position as text. A completion meter is unnecessary and could be confused with the persisted collection progress.
- Use native push/pop and a brief reveal transition; honor Reduce Motion. Keep the headword stable during reveal.
- Remove controls are absent from the review screen. Removing items remains a collection/detail action with confirmation.
- VoiceOver interaction verification is deferred at the user's request; implementation should preserve existing labels and grouping rather than discard them.

## Data and integration

Capture a value snapshot of the selected kind's Today items when starting. Preserve their existing newest-first order. This does not alter bundled sorting, saved indexes, or Add next behavior.

Add ReviewViewModel with the app's @Observable / state / send(_:) shape. Its session state owns the snapshot, current index, answer visibility, and completion. Session actions are reveal, next, previous, and restart; close uses the native router. Advancing requires an answer reveal; finishing never indexes beyond the last item.

Use a ReviewItem presentation model with headword, optional word reading, meanings, level, and optional kanji fields. Map saved Kotoba / Kanji models at the composition boundary so the review view has no repository access. Do not reconstruct definitions by searching bundled kanji UUIDs. AppComposer supplies the view model, and a review route carries the selected session snapshot.

No SwiftData model changes are needed for this first version. Do not persist review counts or mutate WordsProgress. Going to the background retains the active screen's in-memory state; terminating the app ends the session. Starting again takes a fresh snapshot. A session started before midnight retains its original set until closed. External collection changes affect the next session, not the active snapshot.

## States and edge cases

- Empty input: StateMessage titled No words to review / No kanji to review, with Add an item on Today to begin and Back to Today. Never index an empty array.
- Missing reading: omit that field; reveal the available meaning. A kana-only word can have no distinct reading annotation.
- Missing meanings: say No meaning is available for this item and still allow Next after reveal. Never fabricate a definition or block the session.
- One item: reveal, then Finish review; Previous is absent.
- Long headword or definitions: fit cells or use plain Mincho; let text wrap and scroll.
- Failed Today loading: preserve Today's existing cause-specific retry state; do not offer a review session from an incomplete list.
- Repeat: reset the position and hide the answer while retaining the same session snapshot.

## Why this version

A reveal-and-next flow fits the current local data and avoids demanding new scoring or scheduling rules. A self-rating flow could support repeat queues later, but it adds decisions to every item and needs agreed persistence semantics. Spaced repetition is a larger feature with due dates and migrations; it should have its own design when requested.

## Implementation acceptance checks

- Today offers the correct review action only for nonempty, successfully loaded items of the selected kind.
- Every item starts with its reading and meaning hidden; reveal shows real stored content.
- Previous, next, repeat, one-item, and empty-session transitions stay within valid indexes.
- Finishing, exiting, and repeating leave collection counts and saved indexes unchanged.
- Light mode, dark mode, and accessibility text sizes remain readable; primary actions stay reachable with long definitions.
- Native back and swipe-back work through AppNavigationStack.

Seven view-model tests cover session transitions and saved-content mapping. The interactive preview demonstrates the interaction with labeled samples from the bundled vocabulary; it does not read the learner's actual collection.
