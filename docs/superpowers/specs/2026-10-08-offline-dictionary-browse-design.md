# Offline dictionary browsing

Status: approved by the user’s “go” and implemented on `codex/offline-dictionary-browse`. Verification: ../../data/offline-dictionary-browse-verification.md.

The refreshed dictionary is useful beyond the next sequential word. Let learners browse the complete bundled list, inspect full entries, and add a chosen study sense without disrupting their existing sequence.

## User flow

Collection keeps its saved-word search. A “Browse dictionary” button opens a separate screen through AppRouter; no new tab. The browse screen searches Japanese, readings, English meanings and alternate forms, with an All/N5/N4/N3/N2/N1 filter. Blank search shows the selected level in catalog order. Results identify the primary reading, study meaning, community level and whether that exact study identity is already collected. Different selected senses remain distinct rows.

Selecting a result opens full dictionary information immediately, using DictionaryDetailCard. A chosen dictionary entry has “Add to collection”; an existing entry has “View saved word”. Dictionary browsing does not generate AI advice or create a review record. The saved-word screen continues to own AI and study updates. All source information remains available through Sources.

## Data behavior

Use the existing immutable version-2 catalog. No downloads, accounts, sync or new source ingestion. Selected additions create a fresh learner UUID, retain the catalog ID and catalog index, increment the saved-word counter, and update the last-added date. They preserve sequential cursor/current level, kanji progress and every existing schedule. Membership uses catalog identity, allowing different selected senses while preventing duplicate taps for the same sense.

Refactor word addition into one transaction before adding arbitrary selections. The current implementation separately saves the word and progress; the next phase must eliminate partial success in both selected and sequential additions. Missing progress, migration failure, stale sequential cursor or save failure causes no mutation. Duplicate selected additions do not change counters or dates. Returning to Today reloads membership and skips selected words normally.

Deletion must not advance a sequential cursor to a manually selected word farther ahead: rewind only if the removed catalog index is earlier than the cursor. Retired legacy deletion still preserves the cursor. Derive a rewound level from the current catalog, retaining saved study values until explicit update.

## UI and scope

Read DESIGN.md before implementation; document new screen/action copy there first. Use Forest tokens, StudyRow, StateMessage, native lists and system text styles. Dictionary levels are labeled community estimates. Loading, resource failure/retry and no-results/clear-filter states are explicit. Verify light/dark and accessibility XXXL text. iOS 18, Swift 5, local SwiftData remain the floor. No VoiceOver, TestFlight, additional AI features, custom lists, audio or sentence import in this phase.

## Acceptance

A learner can find 青い by 青い, あおい, 蒼い or an English gloss, filter by community level, inspect all supplied metadata, and add that study identity once. A later-level selected addition does not skip earlier sequential words. Restart, export/restore and deletion keep the same identities/counters/cursors. Failure leaves no partial word or progress change.
