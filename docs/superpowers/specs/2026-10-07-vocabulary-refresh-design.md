# Vocabulary refresh and full Word Detail

## Intended outcome

Upgrade the offline study vocabulary using JMdict as the dictionary foundation and reviewed community JLPT assignments. Expand Word Detail beyond the current headword/reading/gloss fields. The user selected **show all dictionary information immediately**, rather than expandable sections.

The app remains an iOS 18, local-only JLPT trainer. Apple Intelligence remains optional. No network calls, account, sync, VoiceOver project or TestFlight check is added. Sources are downloaded during dataset preparation and a validated snapshot ships in the app bundle.

## Approaches considered

1. Import OpenJLPT unchanged. Lowest initial effort, rejected because analysis found concrete homograph, reading and example mismatches.
2. Enrich our CSV in place without changing study membership or levels. Lower migration cost, but retains duplicate/conflicting level assignments and limits the requested content update.
3. **Recommended: build a versioned JMdict subset, with reviewed community level tags and a legacy migration map.** More implementation work, but separates lexical facts from exam-level estimates and supports future releases.

The comparison and snapshot hashes are in docs/data/vocabulary-comparison-2026-10-07.md and its JSON manifest.

## Dataset construction

Inputs are pinned OpenJLPT commit 0d1d3410bec90bd4098a7c72de820543cb4f707c, JMdict English XML created 2026-10-07, and the unchanged legacy CSV. Archive the source snapshots with checksums locally before building; they do not need to become app resources or Git blobs.

Join using JMdict entry ID, compatible spelling and reading, and intended sense. Preserve JMdict reading/spelling restrictions and inherited part-of-speech information. Never choose a homograph merely because it shares kana. A valid entry ID does not prove that its sense matches a teaching list.

Start with both lists' lexical candidates:
- Resolve unambiguous dictionary matches automatically.
- Use a small explicit override ledger for ambiguous mappings and corrections. Confirmed cases include 中腹, しいんと, せっけん, ああ, いただく and 副; do not silently carry the analyzed mismatches into the bundle.
- Retain useful, verified readings and senses unique to our list.
- Exclude unresolved candidates from the *new study catalog*, preserving their original saved learner items and documenting the exclusions.
- Collapse genuinely duplicate lexical candidates; keep different words/senses distinguishable.
- Tag levels as community estimates. Prefer reviewed beginner placements for greetings. Record each assignment's source and overrides; do not claim official 2026 exam coverage.
- Do not import OpenJLPT examples. The existing sentence approval ledger remains the only publication path.

The builder emits:
1. A versioned vocabulary JSON resource.
2. A deterministic legacy-to-current mapping and catalog version metadata.
3. An exclusion/ambiguity report, counts by level and validation results.
4. Bundled source notices and license text.

Counts are measured outputs, never predetermined targets.

## Dictionary schema

Separate immutable bundled dictionary entries from SwiftData learner records. Each entry contains:
- Stable catalog identity and upstream JMdict entry ID.
- Written forms with spelling-specific labels and dictionary priority markers.
- Readings with eligible written forms, kana-only restrictions and reading-specific labels.
- English sense groups: glosses, part of speech, field/register/usage labels, restrictions and source-provided notes.
- Community JLPT assignment and provenance.
- A selected primary study form/reading and concise dictionary-derived study glosses.
- Snapshot/catalog version.

Do not manufacture pitch accent, audio, etymology, frequency ranks, JLPT certainty, examples, synonyms or antonyms absent from the actual source. JMdict priority markers may support a dictionary-defined common-word label; they are not a measured frequency rank.

Lookups for saved words require compatible spelling, reading and sense context. Ambiguous lookup must return a review-needed state, not the first matching homograph.

## Full Word Detail design

Keep Forest's existing visual direction: ENERGY 2 / RHYTHM 2 / MOTION 1. The Mincho practice-square headword remains the focal point. System text styles, Forest tokens, native navigation and scrolling remain.

All supplied learner-facing information is visible without disclosure taps:
1. **Specimen:** saved/study headword, primary reading and community JLPT tag. A short note explains that JLPT levels are estimates.
2. **Study meaning:** concise meanings used by the learner's saved item and review.
3. **Dictionary meanings:** numbered, separate sense groups with plain-language part of speech and applicable usage/field labels. Show restrictions beside the affected sense.
4. **Readings and written forms:** all supported alternatives for the linked dictionary entry, preserving compatibility restrictions. Omit exact duplicates of the primary form/reading.
5. **Usage notes:** only source-provided notes not already displayed with a sense. Omit the section if empty.
6. **Approved example:** existing optional human-reviewed example, if available.
7. **Help me remember:** stays grounded in the clearly labeled study meaning, not a mixture of unrelated dictionary senses.
8. **Sources:** neutral navigation to offline vocabulary credits, licenses, snapshot date and the level-estimate explanation.

Part-of-speech codes become understandable labels, e.g. Ichidan verb, transitive verb, noun, adverb. Avoid decorative badge piles or raw XML tags. Rare, archaic, colloquial and usually-written-in-kana labels remain attached to their source form/sense.

Layout reasons:
- Specimen first: preserves the study word as the focal point.
- Sense groups rather than one comma-separated string: preserves meaning and grammatical distinctions.
- All sections visible: the user's chosen presentation, with scrolling for long entries.
- Forest surface grouping and existing spacing: organizes dense real content without introducing a new visual system.
- Neutral labels and source action: information does not compete with the primary learning action.
- System text styles and flexible vertical layout: remain readable at large text sizes.
- Moss stays on the explicit primary action: keeps the established accent rule.

Collection and Today remain compact; they show primary study reading/meaning. Collection search additionally matches dictionary alternate readings/forms only when a confident dictionary link exists. Review hides all rich answer information until reveal. Kanji Detail is unchanged.

Missing metadata, ambiguous links or unreadable optional detail data must keep the saved study word usable. Explain the cause and provide retry where it can resolve a load failure; do not present a fabricated dictionary entry.

## Existing saved content

Preserve saved IDs, dates, study content, review schedules and AI suggestions during catalog migration. Resolve and attach dictionary metadata separately.

If current dictionary facts differ from a saved study meaning/reading, show both clearly as Study meaning and Dictionary meanings. Do not silently change what a learner rehearses or invalidate their mnemonic.

Offer an explicit Update study word action only when a unique reviewed replacement exists. Show the new primary reading/meaning before applying it. Retain learner identity, dates, schedule and catalog anchor; clear AI advice only when the fields it was based on change, as the current repository already does. Ambiguous replacements require reopening a resolved entry rather than guessing.

## Catalog and progress migration

The current Add next sequence is stable by level and original CSV order. Replacing its content/order without mapping would corrupt saved indexes. Treat this as a versioned catalog migration, not a resource-file swap.

- Keep enough of the original catalog to reproduce its exact ordering and fingerprint.
- Add optional catalog identity/version fields with backward-compatible nil defaults.
- Nil catalog version on existing progress means the legacy catalog; new stores use the current version.
- Map each original slot to a reviewed current catalog identity or an explicit retired marker.
- Before mutation, write a recovery backup of the original collection/progress/reviews using its original catalog contract.
- Perform migration in one fresh context and save once. Mark the new version only in that transaction. On any failure, roll back; expose a retryable error instead of proceeding with wrong indexes.
- Preserve cumulative progress counters and last-added dates. Recompute the next cursor/level using the mapping and saved membership, offering newly introduced entries rather than treating them as already collected.
- Map saved addedIndex anchors for resolved entries. Retired/unresolved saved words retain their saved content; deleting one does not reset the current catalog cursor to an unrelated word.
- Ensure migration completes before any Add next, progress mutation, deletion or backup write using the new catalog.
- Keep subsequent Add next order deterministic, with explicit catalog identities. Future updates must extend the migration mechanism rather than reinterpret stored offsets.
- Collection totals include preserved legacy items. Progress copy must avoid claiming that a collection larger than the new catalog is a subset of it; distinguish collected items from current study-list size.

## Backup compatibility

Introduce a current catalog-aware backup contract; retain version-1 decoding and validation against the exact legacy fingerprint/order.

For a legacy import, first validate against the legacy catalog, then prepare a migrated preview in memory. Preserve learner IDs and content, remap progress/anchors and identify legacy items. Apply only through the existing replacement confirmation/recovery flow. Unknown catalog fingerprints fail with a specific explanation; no permissive bypass.

Current backups preserve catalog version/identity and saved optional AI advice. The prepared preview and restore transaction must use the same catalog contract. Recovery files must retain the original catalog/version needed to reopen them.

## Verification and implementation order

1. Implement the reproducible data builder and override ledger. Verify determinism, restrictions, homographs, empty fields, duplicate identities and the analyzed defect cases.
2. Add bundled DTO/loading/lookup APIs and tests. Cache decoded resources. Verify malformed/missing resources, unmatched saved words, legacy dictionary lookup and sense-compatible links.
3. Implement atomic catalog migration and backup compatibility before switching Add next to the new catalog. Test real pre-update disk data, empty/completed/partial progress, duplicate saved forms, retired entries, rollback, restart idempotence and legacy restore.
4. Switch the bundled study catalog and wire metadata through composer/presentation models. Keep @Observable/state/send conventions.
5. Implement the full detail layout, source credits and explicit study-word update. Test study/AI preservation and update invalidation.
6. Tuist generation, full workspace/Python tests, production build, and Simulator checks in light/dark and large accessibility text. Verify existing collections, Add next/deletion, review reveal, rich long entries, source navigation and backup restore.

Use scoped workers for independent data preparation and UI work after the shared data contracts are fixed; the root owns migration integration, Tuist and all Xcode execution. Do not commit, push, merge or modify the existing AI PR as part of this design preparation.

## Scope boundary and review state

This artifact is a proposed design, not an implemented update. It deliberately includes data migration and backup compatibility because these are necessary to safely deliver the requested refresh. The full-information layout reflects the user's explicit choice. Design review is pending before product code changes.
