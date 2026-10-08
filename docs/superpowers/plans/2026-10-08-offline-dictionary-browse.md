# Offline Dictionary Browsing Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task after the proposal is approved. Preserve the user's phase-by-phase preference; delegate independent search/UI review only when helpful.

**Goal:** Browse all bundled study entries and add chosen words without disrupting sequential learning.

**Architecture:** Reuse VocabularyCatalogRepository and DictionaryDetailCard. Build a cached search presentation and native browse route; introduce one transactional word-add repository shared by Today and selected additions. Existing saved-word Detail remains responsible for AI advice and study updates.

**Tech Stack:** Swift 5, SwiftData, SwiftUI, Tuist, iOS 18; bundled version-2 JSON.

**Spec:** ../specs/2026-10-08-offline-dictionary-browse-design.md

## Global Constraints

- Local only; no downloads, accounts, sync or new source ingestion.
- All dictionary information visible immediately; community JLPT estimates labeled.
- Preserve saved study meanings, IDs, dates, schedules and AI advice.
- Forest tokens/components; loading, empty and retryable error states.
- iOS 18, Swift 5; no VoiceOver or TestFlight work.
- Approved by the user’s “go”; implementation and verification are complete; Git delivery follows the user’s “continue”.

## Review Focus

- Duplicate taps for one catalog identity must increment progress only once.
- A failed progress save must not leave a partially inserted word.
- Selecting/deleting a later-level word must not skip earlier sequential words.
- Search must retain distinct sense identities and source reading restrictions.
- Missing catalog data or migration failure must prevent additions while preserving the learner store.

### Task 1: Transactional word addition and cursor-safe removal

**Files:** Create DataKit/Sources/Repository/WordAdditionRepository.swift and Tests/WordAdditionTests.swift; modify DomainKit/Sources/UseCase/Kotoba/AddKotobaUseCase.swift, create AddSelectedWordUseCase.swift alongside it; modify DataKit/Sources/Repository/StudyMutationRepository.swift and SwiftUIApps/Sources/Presentations/Composer/AppComposer.swift.

**Interfaces:** DataKit defines `WordAdditionSource { case next(expectedCursor: Int); case selected }`; `WordAdditionRepository.addWord(catalogID: String, savedID: String, addedAt: Date, source: WordAdditionSource) throws -> StudyProgress`. Standard implementation takes StudyStore, immutable catalog, migration hook and injected save closure. DomainKit selected-add use case calls this API and publishes the returned progress shadow only after success. Today keeps its public AddKotobaUseCase signature; its adapter validates supplied study fields against the selected catalog entry and uses the persisted cursor as its expected sequential cursor.

- [x] Write repository tests with an in-memory StudyStore, a two-entry valid catalog and one progress row. Assert sequential add, selected add, duplicate selected add, stale cursor, missing progress and injected save failure. Reopen a disk fixture to confirm saved IDs and anchors.
- [x] Run DataKitTests/WordAdditionTests and observe failures before implementation.
- [x] Implement prepare → fresh context → fetch progress/membership → validate → insert word/change progress → one save; rollback on failure. Selected add retains cursor/level. Sequential add verifies the first unsaved catalog item at/after the expected cursor, then advances to its index + 1. Throw for stale sequential state; duplicate selected requests return unchanged persisted progress.
- [x] Change deletion to rewind only when `removedIndex < currentCursor`; otherwise retain cursor/level. Tests cover a selected N1 word removed while cursor is still at N5, an earlier sequential removal, and retired legacy removal.
- [x] Run repository/domain addition and deletion tests. Keep the tested atomic behavior reviewable in the working tree.

### Task 2: Searchable dictionary presentation

**Files:** Create SwiftUIApps/Sources/Presentations/Dictionary/DictionarySearchIndex.swift and DictionaryBrowseViewModel.swift; create SwiftUIApps/Tests/DictionaryBrowseTests.swift.

**Interfaces:** `DictionarySearchIndex.init(words: [DictionaryWord])`; `results(query: String, level: String?) -> [DictionaryWord]`. View model follows @Observable/state/send with load, queryChanged(String), levelChanged(String?) and retry actions. State contains query, level, result IDs, saved catalog ID set and loading/loaded/failed state. Loader and membership providers are injected.

- [x] Test primary Japanese/reading, permitted alternate forms, all English sense glosses, whitespace/case normalization, level filtering, blank query ordering and distinct sense IDs. Test resource/membership failure and retry.
- [x] Run DictionaryBrowseTests and observe failures before implementation.
- [x] Cache normalized search fields once per catalog load. Match supplied query case-insensitively against cached Japanese/readings/English; filter level first. Rank exact primary spelling/reading, then primary prefix, then remaining matches; preserve catalog order for ties. Do not add romanization inference, network search or artificial delays.
- [x] Publish saved membership by catalog ID. Loading/failure prohibits add actions; retry reloads both sources.
- [x] Run search/state tests.

### Task 3: Browse screens and selected-add flow

**Files:** Create DictionaryBrowseView.swift, DictionaryBrowseDetailView.swift and DictionaryBrowseComposer.swift in SwiftUIApps/Sources/Presentations/Dictionary; modify Router/AppRoutes.swift, Presentations/WordsCollection/WordsCollectionView.swift, Composer/AppComposer.swift and DESIGN.md. Add tests to DictionaryBrowseTests.swift.

**Interfaces:** New routes `.dictionary` and `.dictionaryEntry(String)` hold an immutable catalog ID. Composer resolves the ID from the current bundle and supplies selected-add use case/membership loader. Full-entry view reuses DictionaryDetailCard. After success, reload persisted membership; “View saved word” routes through existing `.detail` using the saved learner record.

- [x] Update DESIGN.md with the browse entry point, level filter, full-detail actions and concrete states.
- [x] Build native result list with StudyRow and collection membership label; preserve separate saved-word Collection search. Show loading, failed/Try again and empty/Clear filters states.
- [x] Build full dictionary detail with Add to collection/View saved word, using dictionary studyMeanings as the chosen sense. Add failure leaves the entry visible with a retryable error. Avoid adding AI actions before the word is saved.
- [x] Test successful selection, duplicate-tap protection, failure/retry, and returning to Today without cursor movement or duplicate offers. Run `tuist generate --no-open` after creating files, then the framework tests.
- [x] Keep the tested screens and routing reviewable in the working tree.

### Task 4: Integration and delivery gate

- [x] Verify an existing disk store, selected-add/restart, current backup roundtrip, Today skipping selected identities, and both earlier/later deletion cases.
- [x] Inspect browse, long full detail, confirmation/error and no-results states in light/dark/accessibility XXXL. Kanji behavior remains unchanged.
- [x] Run Python builder regressions and the full JapaneseDictionary-Workspace simulator suite. Build the JapaneseDictionary app in Release. Run `git diff --check`.
- [x] Independent review focuses on the five failures above; fix findings before delivery. Record verification in docs/data/offline-dictionary-browse-verification.md. Git delivery proceeds after the user’s “continue”.

## Self-review

All approved spec requirements map to tasks 1–4. Shared signatures and paths are explicit. Duplicate, failure, cursor, sense and resource risks have named tests. No catalog order or backup format change is planned. Implementation and verification are complete. See ../../data/offline-dictionary-browse-verification.md for test results, live-store checks and simulator automation limits.
