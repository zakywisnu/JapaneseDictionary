# Review words and kanji

Status: Today and Collection practice are implemented. The original interactive preview demonstrates the earlier reveal-and-next flow, rather than the current Again queue.

## Purpose and entry points

Turn saved items into a short recall exercise. Today offers a neutral Review today's words / kanji action for successfully loaded nonempty lists; Add next stays primary. Collection offers Review words / kanji with a setup sheet for All levels or N5–N1 and a session size of 10, 20 (default), or All. Show the selected count and disable Start for empty selections with a change-level instruction. Browsing search never changes this selection.

Capture saved values when starting. Today preserves its list order; Collection uses newest-first dates with saved ID as a tie-break. Push through the native navigation stack and hide the tab bar during review. Native back exits without confirmation.

## Session sequence

1. **Recall.** Show the headword in practice squares, JLPT tag, and “N remaining.” Hide readings and meanings. Prompt: Try the reading and meaning. Primary action: Reveal answer.
2. **Answer.** Keep the headword stable and show saved reading and meanings. Kanji separates On'yomi, Kun'yomi, and Strokes; omit missing fields. Got it is the moss primary action and removes the current item from the queue. Again is neutral and moves it behind other remaining items. Explain: Again repeats this item in this session.
3. **Complete.** Report distinct items practiced, whether they were added today or came from Collection, and repeat attempts separately. Back to Today / Collection returns to the originating screen; Review again resets the original snapshot and attempts. No mastery claim, score, streak, or celebration animation.

There is no Previous action in rated practice: a consumed rating cannot be silently changed. Both ratings require reveal and hide the next answer. A one-item Again hides and reoffers that same item, without ending the session. Duplicate saved IDs appear only once in the queue.

## Layout and behavior

- Reuse Forest tokens, practice squares, Mincho headwords, system text styles, LevelTag, PrimaryButtonStyle, and StateMessage.
- Content scrolls while bottom safe-area actions remain reachable. Long definitions and accessibility text can wrap. Every accepted rating resets scroll, including one-item Again.
- Fit practice cells using detail sizes, with plain Mincho fallback for long headwords. Never leave hidden answer text in recall.
- Honor Reduce Motion for reveal transitions. Do not show a completion meter that could imply persisted collection progress.
- Keep removal in Collection/Detail; review has no remove action.
- VoiceOver interaction verification remains deferred at the user's request.

## Data and integration

ReviewSession contains immutable saved ReviewItem values, kind, and origin. ReviewItem retains saved ID, original date, headword, reading, meanings, level, and kanji-specific fields. Do not reconstruct saved kanji through regenerated bundle UUIDs.

DomainKit's pure PracticeQueue deduplicates IDs preserving order, rotates Again to the tail, removes Got it, and records repeat attempts. ReviewViewModel follows @Observable / state / send and maps the current queue ID to saved content. Reveal, rate, and restart are in-memory actions; AppComposer supplies the VM. Presentation revision resets scroll even when the next item has the same ID.

Today and Collection practice do not write schedules or WordsProgress. Backgrounding retains the active in-memory queue; termination ends it. Starting anew takes a fresh snapshot. Midnight and collection changes affect the next session, not active content.

## Due sessions

Today has a separate Due for review section for the selected study kind. Due snapshots order oldest due dates first with saved ID as a tie-break. Unrated items are immediately due even when the device clock is earlier than their added date.

Only due sessions persist ratings. Save the rating before mutating PracticeQueue; a save error keeps the revealed item, remaining count and repeat attempts unchanged. Retry uses the pending rating and the same session UUID. Exit uses native back without consuming the queue. Again resets the schedule to one calendar day; successful reviews advance through 1, 3, 7, 14 and 30 days. Existing collection counts and Add next indexes are unaffected.

Due completion offers Back to Today. It cannot restart its stale snapshot: the next due session must load today's current schedule. Today / Collection practice retains Review again without scheduling writes.

Approved word examples appear only after reveal. Match the original headword, furigana and level even when a kana-only word has no displayed reading annotation. Missing optional data leaves review usable. The shipped approved bundle is currently empty.

## States and edge cases

- Empty input: StateMessage plus an origin-specific return action and next step; no array indexing.
- Missing reading: omit it. Kana-only words need no repeated reading annotation.
- Missing meanings: explain that none is available and still allow ratings after reveal.
- One item: Again reoffers it; Got it completes.
- Repeated taps: a rating hides the answer immediately, so another hidden-answer rating is ignored.
- Repeat: restore original unique order, hide the answer, and reset repeat attempts.
- Failed loading: preserve cause-specific retries and do not offer review from incomplete data.

## Acceptance checks

- Both entry points practice real saved content and retain native back/swipe-back behavior.
- Reveal precedes ratings; Again rotates and Got it consumes safely for empty, duplicate, and single-item inputs.
- Distinct count and attempts describe different things; no rating changes collection counts or indexes.
- Verify light/dark/accessibility text, safe-area actions, long definitions, and one-item scroll reset before calling UI verification complete.

Queue and VM tests protect repeat, deduplication, reveal guards, restart, empty input, and saved-content mapping. Runtime UI checks are recorded separately from test results.
