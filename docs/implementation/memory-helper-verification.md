# Memory helper verification

Verified on 7 October 2026, iPhone 17 Pro Simulator, iOS 27, Xcode 27 beta.

## Delivered behavior

Word Detail now offers Help me remember below the authoritative dictionary meanings. Apple's on-device model produces a short explanation and mnemonic. Learners explicitly save a suggestion; regeneration never automatically overwrites the stored one. The card retains saved content when generation is unavailable. The app still targets iOS 18; generation requires iOS 26 or later and a ready, eligible Apple Intelligence model supporting Japanese and English.

Optional saved fields round-trip through version-1 backups. Catalog fingerprints exclude these learner fields. Repository saves reject missing or changed words and do not alter study counters, reviews, dates or dictionary content.

## Automated and build evidence

- Final JapaneseDictionary-Workspace run: 75 passed, zero failed or skipped. DataKit 28, DomainKit 16, SwiftUIApps 29, CoreKit 1, app 1.
- Tests cover input validation and JSON data isolation; saved reload and rollback; stale or deleted words; legacy backup decode, restore and fingerprint compatibility; generation without autosave; save retries; regeneration failure; duplicate requests; cancellation and late completion races; unavailable generation with readable saved content; Foundation Models failure mapping for both iOS 26 and iOS 27 APIs.
- RED was observed before adding the new domain, repository and view-model types. The iOS 27 error-mapping regression failed assertions before the adapter fix.
- Final production JapaneseDictionary Simulator build and launch succeeded with zero reported build warnings or errors.
- The built SwiftUIApps framework weak-links FoundationModels. Deployment remains iOS 18.
- git diff --check passes. Tuist generation includes the new source and test files.

The final full test run completed at 12:42 UTC; the production build completed at 12:42 UTC.

## Existing-store upgrade

Before installing the new app, the Simulator's existing four-model SQLite store had 3 words, 2 kanji, 1 progress row and 1 review row, with no memory columns. A consistent SQLite backup and all original column values were captured in temporary files. After installing and launching, every original row and column matched. The new optional explanation and mnemonic columns existed and were nil. This checks an actual pre-change store, rather than only creating a store from the new schema.

## Runtime checks

Live generation in the app for 青 / あお / blue returned:

> あお means blue, a color often seen in the sky or sea.

> Think of a bright blue crayon—it’s the same shade as あお.

Both fields were grounded in the supplied blue meaning and contained no new reading, historical origin or kanji etymology. Saving displayed Saved on this iPhone. A later regeneration produced a different unsaved suggestion; relaunch restored the original explicitly saved text, confirming that regeneration did not overwrite it.

A second live generation returned:

> あお means blue, the color of a clear sky.

> Think of a bright blue balloon floating in the air.

This is a small smoke sample, not a general accuracy evaluation across the vocabulary dataset. The product labels every result AI-generated and asks learners to check the meanings.

A command-line model probe failed with a model-service error even though availability reported ready. Actual app generation succeeded, so that probe was not used as evidence of app failure.

Temporary generator substitutions exercised unavailable-model and generation-error screens. Existing saved text stayed visible; unavailable generation was disabled with Check availability; failure exposed Try generating again. These substitutions and the temporary collection-first launch change were removed before the final test/build.

Light mode and dark mode were visually inspected. At the largest accessibility text size, the title, explanation, mnemonic, disclaimer, saved status and action wrapped within the scrollable card without horizontal truncation. Simulator appearance and text size were restored to light / large afterward. Kanji Detail retained its existing content and did not show the helper. The optional @State injection issue found during visual testing was fixed using State(initialValue:).

Cancellation and stale-request behavior have deterministic view-model tests; the Cancel control was also exercised during live regeneration. No claim is made that UI timing alone proves the cancellation race guarantees.

## Design review

The card reuses Forest surfaces, spacing, radius and primary button style. Save is the moss primary action; generation and availability controls are neutral. System text styles handle Dynamic Type. The Japanese specimen remains the screen's focal point. No decorative AI icon, additional accent color or chat surface was introduced. Independent review covered storage/backup integrity, API availability and the detail flow.

VoiceOver and TestFlight checks were excluded at the user's request. The user subsequently authorized committing, pushing and opening a pull request. Merge is a separate delivery step.
