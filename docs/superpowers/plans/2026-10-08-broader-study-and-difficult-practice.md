# Broader study and difficult practice implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for owned components, with integration and a final independent review in this session.

**Goal:** Add offline custom cards, bundled grammar/sentence lessons, mixed study lists, and persistent difficult-item practice.

**Architecture:** Add material and difficulty models without altering bundled vocabulary ordering. Composite SavedStudyID is shared by all ratings, memberships, queues and backups. Each rating transaction saves difficulty, optional schedule and daily activity together.

**Tech Stack:** Swift 5, iOS 18, SwiftUI, SwiftData, Tuist, Python standard library importer.

**Spec:** docs/superpowers/specs/2026-10-08-broader-study-and-difficult-practice-design.md

## Global constraints

- Local only: no runtime network, accounts or sync.
- Preserve word/kanji indexes, saved content and old backups.
- Use Forest tokens and update DESIGN.md before UI changes.
- Pending Tatoeba examples remain pending; no fabricated review metadata.
- Custom field bounds: prompt/reading 500, answer/notes 4,000; required trimmed prompt/answer.
- Verify light, dark and accessibility text size; VoiceOver/TestFlight remain deferred.
- Execution authorized immediately by the user; proceed without another planning approval.

## Review focus

- Same raw ID in two kinds: queue/membership/goal identities remain distinct (tasks 1, 3, 4).
- Save failure after midnight: queue stays revealed; retry retains action/date (tasks 1, 3).
- Changed custom answer: confirm schedule/difficulty reset, retain historical activity (tasks 1, 3).
- Old store with word memberships: migrate idempotently without modifying existing indexes (task 4).
- Damaged lesson record or backup: reject with a cause before replacing existing learner data (tasks 2, 4).

### Task 1: Material and rating storage

**Ownership:** DataKit new Materials/Difficulty source and tests, SavedStudyKind/ReviewRepository, StudyStore; DomainKit new RecordStudyRatingUseCase. No backup/list/UI edits.

**Interfaces:** Public Codable/Hashable StudyMaterial has id:String, kind:SavedStudyKind, prompt/answer:String, reading/level/notes/category:String?, structures:[String], examples:[LessonExample], relatedSourceIDs:[String], source:MaterialSource?, createdAt/updatedAt:Date. LessonExample has japanese/english:String, reading:String?; MaterialSource retains provider/sourceID/sourceURL/license/notice/snapshot/textSHA256:String and parentIDs:[String]. Models expose value and init(value:). StandardStudyMaterialRepository(store:) exposes materials(kind:SavedStudyKind? = nil), save(StudyMaterial)->StudyMaterial, delete(SavedStudyID). Save enforces bounds/kinds, source identity uniqueness, meaningful edit reset and rollback.

DifficultyRecord is Codable/Equatable with id:SavedStudyID, missCount:Int, lastMissDate:Date?, lastSessionID:UUID, sessionHadAgain:Bool, lastActionID:UUID. StandardStudyRatingRepository exposes records()->[DifficultyRecord] and record(id:sessionID:actionID:again:now:review:activity:) with optional ReviewRecord and PracticeActivity. Duplicate action is no-op; Again increments; later clean-session Got it clears miss count; same-session Got it retains difficulty. Save all effects atomically.

DefaultRecordStudyRatingUseCase(reviewRepository:ratingRepository:calendar:) exposes execute(id:sessionID:actionID:rating:now:isDue:). Calculate the current existing scheduler result only for due ratings, then atomically save through rating repository. Add SavedStudyKind grammar/sentence/customCard and map materials into SavedStudyItem with optional material payload. Existing initializers remain compatible.

- [x] Write repository tests: same-session Again/Got it stays difficult; new-session Got it clears; duplicate action does not add misses; failed save rolls back schedule/activity/difficulty; custom meaningful edit resets while notes do not; missing/deleted item rejected.
- [x] Run focused tests before implementation (root coordinates Swift test runs after Tuist registration).
- [x] Add models/repositories/use case and additive schema registration; preserve existing methods for old tests.
- [x] Run focused tests and inspect real disk reopen persistence.

### Task 2: Pinned offline lesson corpus

**Ownership:** tools/data/prepare_lessons.py, test_prepare_lessons.py, data/lessons/, DataKit Resources/lessons.json and lesson notices, DataKit LessonCatalogRepository.swift and tests. No material-model edits.

**Interface:** LessonCatalogRepository.materials()->[StudyMaterial] loads a versioned bundle with materials and snapshot. Normalized material fields exactly match Task 1; source IDs grammar:<slug>, sentence:<sha256 exact Japanese/English pair>. Sentence sources retain all parent grammar IDs. Dates use a fixed snapshot date, not current time. Bundle grammar levels N5–N1 and source examples separately; preserve explicit community-source attribution, no claim of human approval. Validate furigana text reconstruction before constructing a reading; otherwise omit reading.

- [x] Write Python tests showing duplicate identity, malformed level, blank required text and invalid annotation fail; ordering/deduplication is deterministic and sentence parents are retained.
- [x] Pin upstream Git commit, download five grammar files and license notices, record bytes/hash/URLs in manifest.
- [x] Build deterministic importer preserving raw text/notices. Audit actual counts and cross-reference integrity; report upstream deficiencies rather than silently dropping content.
- [x] Generate bundle and offline attribution; implement runtime typed decoder and failure tests.
- [x] Run Python suite; root runs Swift runtime tests after integration.

### Task 3: Material screens and shared review integration

**Ownership:** Worker: new SwiftUIApps Presentations/Materials screens/view models/tests only. Root: Review files, existing Home/Collection/Composer/Router, Forest selector, sources and DESIGN.md.

**Worker interface:** MaterialLibraryViewModel(repository:StandardStudyMaterialRepository,catalog:LessonCatalogRepository) state/send pattern; MaterialLibraryView supports saved kind (.grammar/.sentence/.customCard) and bundled browsing, uses closures for open detail/review. MaterialDetailView takes StudyMaterial, repository/catalog and review/organize closures; CustomCardEditorView edits optional StudyMaterial and persists via repository. Native screens expose loading/empty/retry, prompt/answer/note bounds, edit reset confirmation, Save/Cancel retaining draft on failure, delete confirmation, supplied-reading pronunciation and offline source notices.

- [x] Write tests for failed-save draft retention, empty filters, supplied content and meaningful edit confirmation.
- [x] Implement readable long prompts/answers, source details, browse-save-view behavior, related lesson links and custom forms with Forest tokens.
- [x] Root updates ReviewItem to carry composite identity and material; ReviewSession/ReviewSetup handle mixed sessions and absent levels.
- [x] Root adds one atomic recordAction callback with stable action UUID/date across Retry; adapt old callbacks compatibly.
- [x] Root adds difficult setup with kind/level/list/size intersections, deterministic miss ordering and explicit empty/error states.
- [x] Root wires Today, Collection, native material menu and all routes; update DESIGN.md before code.

### Task 4: Mixed lists, backups, integration verification

**Ownership:** Root: StudyItemMembershipModel, StudyListRepository and list UI, all Backup files/validator/preferences and tests, cleanup in word/kanji delete use cases.

**Interfaces:** StudyItemMembershipModel stores listID/kind/savedID and unique composite key. StudyListRepository adds items(listID:), listIDs(id:), setLists(id:listIDs:), removeItem(listID:id:); word-only wrappers remain compatible. Convert legacy rows atomically on repository access/export; duplicates do not grow on repeated migration. Expose itemCount while preserving wordCount compatibility.

- [x] Write mixed identity/migration/rollback tests first.
- [x] Add format 4 materials:[StudyMaterial], difficulties:[DifficultyRecord], itemMemberships with composite ID. Older formats continue to decode and convert with empty new arrays.
- [x] Validate all references/limits/dates/identities, version-specific fields and notices before recovery/replace; preserve catalog conversions. Test roundtrip, older backup restore, corrupt orphan records and failed restore/recovery.
- [x] Wire mixed-list rows/review/organize and removal cleanup across all kinds.
- [x] Regenerate projects, run workspace tests and Python suite, fix failures, build Release.
- [x] Run simulator smoke checks in light/dark/accessibility size; independent review of storage and UI integration; fix material findings and record evidence.

## Execution record

Ruling: proceed now without additional plan approval, as explicitly instructed by the user. Preserve uncommitted icon assets and do not push, create a PR or merge during this implementation request.

Verification completed 2026-10-10: 201 Swift tests passed, one existing Foundation Models API test skipped; 45 Python tests passed; Release build succeeded. Independent review findings were fixed and re-reviewed. See docs/implementation/broader-study-verification.md for visual-check scope.
