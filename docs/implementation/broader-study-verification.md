# Broader study verification

Verified 2026-10-10 on iPhone 17 Pro simulator, iOS 26.4.

## Delivered

- Offline custom cards, 1,031 grammar lessons and 2,056 deduplicated sentence cards.
- Shared reveal/rating flow for five study kinds; persistent difficulty with later clean-session clearance.
- Mixed study lists, additive SwiftData models, legacy membership migration and version 4 backup/recovery.
- Pinned community-source provenance and full license notices retained in saved lessons and backups.
- Existing vocabulary order, progress indexes and pending Tatoeba approvals preserved.

## Validation

- Workspace simulator tests: 201 passed, zero failed, one skipped. The existing Foundation Models refusal test requires an API unavailable in this test environment.
- Python data suite: 45 passed, zero failed.
- Release simulator build succeeded with no reported warnings or errors.
- Normal Debug startup restored and app launched after visual checks; temporary navigation hooks removed.
- Independent review identified missing kanji list organization and incomplete saved license notices. Both were fixed; scoped re-review found no remaining P1/P2 issues.
- Visual checks covered the light lesson list and custom-card editor, plus dark lesson browsing, difficult-item setup and lesson detail at maximum accessibility text size. Native simulator automation prevented a complete interactive custom-card save roundtrip; persistence and failure behavior are covered by repository and presentation tests.

## Content limits

Grammar and sentences retain community-source attribution; they are not represented as individually human-reviewed. Sentence levels describe their parent lesson. Readings are omitted when source annotations cannot establish the complete pronunciation. VoiceOver and TestFlight remain deferred as requested.

## Delivery

Delivery authorized by the user on 2026-10-10: commit, push, create a pull request and merge into main. The full test suites were rerun before committing with the same passing results.
