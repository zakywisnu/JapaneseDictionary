# Vocabulary refresh Implementation Plan

> For agentic workers: use scoped subagent-driven development for independent builder, catalog and UI tasks; the root owns integration, migration, Tuist and Xcode. Do not commit or deliver Git changes without a later user request.

**Goal:** Refresh offline vocabulary and expose full, sense-aware dictionary information without losing learner data.
**Architecture:** Build a pinned JMdict subset with reviewed community JLPT tags and legacy mappings. Immutable JSON catalog metadata stays separate from SwiftData saved study content; an atomic version migration remaps catalog anchors and old backups.
**Tech Stack:** Python standard library, Swift 5, SwiftData, SwiftUI, Tuist; iOS 18.
**Spec:** ../specs/2026-10-07-vocabulary-refresh-design.md

## Global constraints
- Local only; no app network calls, accounts or sync.
- All dictionary information visible immediately; no collapsed detail sections.
- Preserve saved IDs, dates, study content, schedules and AI advice during migration.
- JMdict facts and community JLPT estimates remain distinct.
- Forest tokens, native navigation and system text styles.
- Existing examples approval gate; no OpenJLPT sentence import.
- User approved the written design and said do it. Execute continuously; the prior preference permits orchestration.

## Review focus
- Homographs must not link by kana alone.
- A retired word must not reset the cursor to an unrelated slot on deletion.
- Old backup validation precedes conversion and restore.
- Empty/completed migration must still offer newly introduced items.
- Rich dictionary details cannot silently replace saved study meanings or AI context.

## Shared contracts

DataKit DictionaryCatalog.swift contains Codable/Equatable/Sendable structs:
DictionaryForm(text:String,notes:[String],common:Bool).
DictionaryReading(text:String,spellings:[String],notes:[String],common:Bool,kanaOnly:Bool).
DictionarySense(meanings:[String],pos:[String],labels:[String],notes:[String],spellings:[String],readings:[String]).
DictionaryWord(id:String,jmdictID:Int,headword:String,reading:String,level:String,studyMeanings:[String],forms:[DictionaryForm],readings:[DictionaryReading],senses:[DictionarySense]).
DictionaryCatalog(version:Int,created:String,jmdictCreated:String,entries:[DictionaryWord],legacyMap:[String?]).
JSON field names equal Swift properties; all fields emitted. Entries sorted N5 to N1, deterministic within levels. Legacy map order is original CSV stable level sort (N5 to N1), including duplicate rows.

VocabularyCatalogRepository exposes catalog, init(catalog:) throws, static bundled() throws, word(id:) -> DictionaryWord?, word(headword:reading:meanings:) -> DictionaryWord?.
KotobaDataModel gets optional catalogID; WordsProgressModel optional catalogVersion, nil legacy. Initializer parameters default nil.
Saved learner IDs remain distinct from catalog IDs.
Vocabulary lookup must validate forms/readings and avoid ambiguous homographs.

## Task 1 — dataset builder (worker)
Files tools/data/build_vocabulary.py, test_vocabulary.py, data/vocabulary overrides/provenance/report, DataKit/Resources/vocabulary-v2.json and vocabulary-attribution.txt.
- [x] Write tests for restricted readings, inherited POS, homograph ambiguity, explicit overrides, duplicate collapse and stable legacy map.
- [x] Run RED before implementation; implement XML parsing and candidate/meaning matching.
- [x] Archive snapshots with hashes locally; resolve analyzed defects explicitly. Emit current catalog JSON and report, no examples.
- [x] Verify GREEN and repeat build byte-for-byte. Report excluded/ambiguous candidates honestly.

## Task 2 — catalog API (worker)
Files DataKit/Sources/Vocabulary, model optional fields, VocabRepository, DataKit/Tests/DictionaryCatalogTests.swift.
- [x] Test malformed/duplicate/missing IDs, aliases, homograph refusal and selected readings.
- [x] Implement shared contracts, cached bundle loader, legacy CSV accessor and metadata lookup.
- [x] fetchKotobaData uses new entries, stable catalog IDs and primary study content.
- [x] Preserve original CSV resource unchanged for migration/fingerprint.
- [x] Cover optional model defaults. Root runs Tuist and Swift tests.

## Task 3 — UI/domain (worker)
Files SwiftUIApps Models/Kotoba, Presentations/Details, HomeKotoba VM, collection search, Sources, DomainKit KotobaParam, DESIGN.
- [x] Propagate optional catalogID with defaults.
- [x] Build full visible dictionary sections and concrete metadata load/ambiguity fallback.
- [x] Retain separate Study meaning and AI grounding; explicit previewed Update study word uses existing update use case, preserves identity/date/index/reviews and clears stale AI advice.
- [x] Search confident alternate forms/readings; keep review answer hidden until reveal.
- [x] Ensure new Add next skips all already saved catalog identities, not only today's regenerated UUIDs.
- [x] Update source credits and progress copy without invalid subset claims.
- [x] Update DESIGN before UI changes; no raw colors or decorative AI icons. Root owns AppComposer integration.

## Task 4 — migration/backup (root)
Files DataKit/Sources/Vocabulary/CatalogMigration.swift, Backup*, Repository progress/word/mutation, Composer, migration tests.
- [x] Add injected pre-mutation migration hook and catalog loader; migration failure must propagate to retryable view state.
- [x] Recovery export under legacy contract before mutation; fresh-context single save with rollback and idempotent catalogVersion.
- [x] Map saved anchors/IDs without altering study content; remap cursor to first eligible new item, preserve counters/dates/reviews/advice.
- [x] Retired deletion preserves cursor. Repository update preserves catalogID and invalidates advice only on context changes.
- [x] Current backup version/identity validation; accept known legacy only after original fingerprint/order validation. Migrate preview in memory and restore same contract.
- [x] Tests for failure/restart/completed/duplicate/retired/unknown versions and old restore.

## Task 5 — integration, review and verification (root)
- [x] Run Tuist after new source files; workspace tests and Python data tests.
- [x] Independent review of builder, catalog/migration and UI; resolve material findings.
- [x] Verify actual existing disk store, Add next, rich long detail, update study word, AI context, kanji exclusion and legacy restore.
- [x] Light/dark and accessibility-large UI; production build.
- [x] Record real counts, exclusions, licenses, checksums, migration and limitations. No VoiceOver/TestFlight work.

## Execution ledger
Plan self-review: contracts cover source restrictions, inherited POS, legacy ordering, saved-content separation and backup conversion. User's explicit implementation instruction takes precedence over another generic plan approval prompt.


## Completion evidence — 2026-10-08

Builder: 14 Python tests pass; pinned-input repeat build is byte-identical. Final catalog: 7,986 entries (N5 690, N4 634, N3 1,710, N2 1,809, N1 3,143). Legacy map: 7,393 mapped slots, 737 retired; original CSV unchanged. Study identities include canonical form and selected sense; ambiguous mixed homographs are excluded. Full bundle load test guards Swift canonical Unicode equivalence.

Integration: Tuist generated projects; final workspace suite passes 105 tests. Debug app build/run and Release simulator build pass with zero reported warnings/errors. Independent reviews corrected selected-sense matching, stale update anchors, deletion levels, and removal/coverage copy. A parser-order review finding was retracted after tracing the actual quote-aware reader.

Actual-store smoke: three legacy words, two kanji, one progress row and one review row upgraded on the existing iPhone 17 Pro simulator. Comparing SQLite snapshots confirmed all prior study fields, IDs, dates, counters, review state and saved AI advice preserved; only word anchors and current cursor/level/version changed. The version-1 recovery export is valid and contains the original three words. Add next skips those identities and adds 青い with a separate learner UUID. Full 青い detail was inspected in light/dark and accessibility XXXL text, including visible sense groups, restrictions, readings and written forms; appearance restored afterward.

Explicit-update and legacy-restore success/failure/restart paths are covered by repository/domain/view-model tests. They were not additionally driven through the simulator confirmation sheets: this simulator's native UI bridge did not expose navigation controls reliably. No VoiceOver, TestFlight or device-release claim is made.

See docs/data/vocabulary-refresh-verification-2026-10-08.md for checks and limits. Git delivery was authorized on 2026-10-08: commit, push, pull request and merge.
