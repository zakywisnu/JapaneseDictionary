# Offline dictionary browsing verification

Date: 2026-10-08. Branch: `codex/offline-dictionary-browse`, based on `b8e1f6f`.

## Implemented

Collection Words opens a separate offline dictionary route. All 7,986 bundled entries are searchable by supplied Japanese forms, readings and English glosses, with All/N5–N1 filtering. Exact primary matches rank first; blank queries retain catalog order. Full entries expose dictionary information immediately and use exact catalog identity for Add to collection / View saved word.

Today and selected additions share one atomic SwiftData transaction. Selected additions preserve the sequential cursor and level; duplicates do not save or change counters/dates. Deleting a later selected word does not advance the cursor. Study meanings, learner identities, schedules and saved AI advice are preserved.

## Automated verification

- Tuist regenerated the committed projects after new source/test files were added.
- Final JapaneseDictionary-Workspace simulator run: **129 passed, 0 failed, 0 skipped**, with no compiler warnings or errors.
- Vocabulary builder: **14 Python regression tests passed** (`python3 -m unittest discover -s tools/data -p 'test_vocabulary.py'`).
- Final JapaneseDictionary **Release** build, install and launch succeeded on iPhone 17 Pro, iOS 27 simulator, using the restored production startup.
- Repository tests cover sequential/selected saves, duplicate idempotence, stale or incorrect offers, invalid input, migration preparation failure, save rollback, disk restart, later deletion and current backup export/validate/restore.
- Backup integration preserves the selected learner ID/catalog anchor/slot/date and unrelated saved meanings, AI advice, kanji, reviews and progress. Existing regression tests cover earlier and retired deletions.
- Presentation tests cover supplied search fields/ranking/filtering/distinct senses, membership caching/retry, empty-resource failure, successful add/reload, committed-add reload failure and duplicate taps.
- A navigation regression initially failed for both new routes; adding them to AppNavigationStack’s pushed-route filter made it pass.
- Independent storage and UI reviews completed. Empty-catalog handling and committed-add reload copy were improved, and the final focused UI review found no actionable issues.

## Existing simulator store

Before testing: four saved words, two kanji, one review record; version-2 word cursor 4 / N5.

Added あくどい (N1, catalog slot 4863) through the dictionary detail’s real Add to collection action. The action changed to View saved word, which opened the learner record with the saved study meaning. A SQLite snapshot comparison confirmed every pre-existing word field (including AI advice), kanji and review record stayed exactly equal. Word count increased from 4 to 5; cursor remained 4 / N5. Only the word counter, last-word-added date and SQLite revision changed on progress.

After restart, Today’s real Add next action added 赤 at N5 catalog slot 4. The persisted cursor advanced to 5 and word count to 6. The selected N1 word remained saved once. The test additions remain in this simulator collection.

## Visual verification and limits

Inspected dictionary list and full entry in light/dark mode, plus accessibility XXXL. Checked add, saved membership/confirmation, no-results and failure guidance. Found and fixed the community-level note’s truncation and shared StateMessage title/body truncation. Empty/error guidance now wraps and scrolls so its recovery action remains reachable.

The Xcode beta’s input automation was inconsistent: semantic tap tools reported success without activating controls, and native tab/back targets were intermittently missing from macOS accessibility. Temporary startup pushes and injected query/error states were used to inspect those screens; macOS accessibility successfully activated the real Add to collection, View saved word and Today Add next controls. Search/filter logic and retry/error transitions were verified through injected unit tests rather than claiming a complete automated navigation walkthrough.

All temporary startup/state hooks were removed. The final installed Release app starts normally on Today; simulator appearance/text size were restored to light/large. No VoiceOver or TestFlight work was performed. Implementation was verified before Git delivery; the user subsequently requested continuation of the delivery workflow.
