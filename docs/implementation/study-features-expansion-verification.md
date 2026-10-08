# Study features expansion verification

Implemented on `codex/study-features-expansion`, based on main f276c15. All app behavior remains local to the device.

## Delivered

- Saved-word lists: create, rename, delete with confirmation, multi-list membership, list-only removal, member review with level/session-size selection and list return context. Word Detail opens membership editing; Collection opens Study lists.
- Pronunciation: installed Japanese system voice, supplied kana only, individual kanji readings, inflection-marker normalization, synthesized-speech labeling, voice-unavailable and retry states. Review controls appear only after Reveal. Navigation/background/queue transitions stop playback; identity guards reject late callbacks/timeouts.
- Daily goal: Off/5/10/20/30 (default 10), Today summary, Progress settings. Distinct saved word/kanji Got it completions count once per captured local Gregorian day across Today/Collection/List/Due. Again does not count. Due schedule/activity share one save; practice preserves scheduling. Failed save holds answer and retries the original timestamp across midnight. Off and learner deletion retain history.
- Backup format 3: lists, memberships, explicit nullable target and activities included. Required format-3 fields reject incomplete backups. Legacy formats default new content safely; format-1 migration remains supported. Restore replaces all models atomically and preserves the recovery backup.
- Sentence preparation: 30 unique pending N5 current-catalog identities, reconciled source/context hashes, auditable unresolved reasons and strict publication tooling. Original human approval ledger and released example bundle remain unchanged.

## Automated checks

- Complete `JapaneseDictionary-Workspace` simulator suite: 169 passed, 0 failed, 0 skipped.
- Expanded disk preservation test: old four-model store opens with additive schema; word/kanji values, saved advice, original review and cursors remain unchanged after membership, practice and due activity writes. Format-3 restore to another disk store, followed by reopen, matches every exported study/list/goal/activity value.
- Tests cover transactional failures, membership rollback, historical deleted identities, old backup defaults, invalid/future input, daily deduplication/timezone/DST, midnight retries and pronunciation lifecycle/reveal gating.
- Python data regressions: 37 passed (`python3 -m unittest discover -s tools/data -p 'test_*.py'`).
- App Debug simulator build/run and Release simulator build passed. Tuist regenerated committed projects for new files. Existing cache-auth skip/static ZeroNet warning remains unchanged.
- `git diff --check` passed.

## Runtime and visual checks

On iPhone 17 Pro / iOS 27 simulator: created Travel, assigned existing kana-only saved word, restarted/reinstalled app and confirmed one member. Started list review; Listen absent before Reveal and present afterward; Got it completed with list context. After restart Today showed 1 of 10 practiced, confirming persisted recording.

Inspected light/default list and Today; dark/accessibility XXXL list, goal choices, pronunciation/detail and membership sheet. Large text wraps, settings and sheet content scroll, persistent Save stays reachable. Native back/Create/actions/Cancel visibility corrected after independent review. Simulator restored to light/default text; temporary startup routing removed.

Xcode 27 simulator input limits: native tab/back and keyboard typing do not reliably activate via bundled automation. Semantic snapshots plus macOS accessibility presses handled SwiftUI buttons; accessibility setValue handled the list field. Temporary local startup routing was used only for screen inspection and restored before final builds. Speech voice/control availability was confirmed and Listen invoked; audible pronunciation quality still requires device listening.

## External dependency

The pending worksheet is `data/tatoeba/current-n5-review-sheet.csv`; reconciliation report is `data/tatoeba/current-reconciliation.json`. Sentence publication requires fluent human review of sense, Japanese/English correctness and any reading, tied to current catalog/source hashes. No human decisions arrived during implementation. Zero new sentences have been published; the tooling and review batch are delivered.

VoiceOver and TestFlight checks remain deferred. GitHub delivery follows the user’s subsequent commit/push/PR/merge request.

## Pronunciation silence follow-up

Runtime regression test confirmed the original engine left the session at soloAmbient/default, which obeys Silent mode. Explicit Listen now activates playback/spokenAudio with duckOthers; finish/cancel/stop releases the session and notifies other audio. Activation failures become visible Retry states. Regression tests failed on the old configuration, then all 10 pronunciation tests and the full 172-test workspace suite passed. Debug app rebuilt and installed. Device/host output volume and audible quality remain external checks.

Further runtime investigation: the voice generated samples, while actual playback timed out with CoreAudio `Could not find default device for dOut` and `ID = 0`. macOS separately detected MacBook Pro Speakers as its default output. Restarting the simulator (shutdown/boot, no erase) restored real speech completion in 1.8 seconds. Real-engine playback and synthesis regression checks now cover this gap; state-only tests had not validated audible output.

Final delivery verification: full workspace 174 passed, 0 failed/skipped; Python data regressions 37 passed; Release build successful. Real speech playback and sample generation included.
