# Kana, exercises, reading and daily guidance

User authorized all four suggested features for implementation. Keep the existing Forest visual language and offline architecture. No new account, network dependency or model requirement.

## Design

A pushed Learning practice screen links Kana, Grammar exercises, Reading practice and Daily study plan. Today offers the daily plan; Collection offers Learning practice. Native lists and menus keep the root headers compact. Existing stored content, indexes and backups remain compatible.

Kana covers modern basic hiragana and katakana, voiced/semi-voiced kana and contracted sounds. Cards explain romanization and contextual pronunciation. Save selected kana as category kana custom cards with stable duplicate matching; practice through the existing persisted review queue. No new saved-study kind or schema.

Grammar exercises are an original, labeled beginner starter set with multiple choices, one correct answer, a concrete explanation and an optional related bundled pattern. Selecting an answer locks it, reveals feedback, and requires Next. Completion reports this session only; exercises do not silently alter due schedules or mastery statistics.

Reading is an original, labeled beginner starter set. Each short passage includes supplied reading, English translation shown on request, tappable vocabulary linked to bundled dictionary search/detail and passage-specific comprehension questions. Questions use the same explicit answer/next interaction as grammar. No exam coverage claims.

Daily guidance loads all saved study kinds, real schedules, difficulty records and today's completed activity. Choose a manageable maximum of ten items, prioritize due, then difficult excluding due duplicates, then saved unreviewed items; distinguish schedule-changing due review from practice. Show counts/reasons and route each batch through the correct existing review mode. First reviews initialize schedules, matching the existing unrated-item due behavior; difficult practice preserves schedules. New learners get a kana/lesson next step. Errors offer retry; reload on appearance.

## Ownership and implementation

1. Kana worker owns new DataKit KanaCatalog and tests and new SwiftUIApps Presentations/Learning/Kana* files. Exposes AppComposer.makeKanaPracticeView(). No shared route/root edits.
2. Exercise/reading worker owns new SwiftUIApps Presentations/Learning/Exercise* and Reading* plus tests. Exposes AppComposer.makeGrammarExercisesView() and makeReadingPracticeView(). No shared route/root edits. Dictionary lookup must use existing bundled API with real empty/error states.
3. Root owns daily guidance, Learning hub, routes/root links, DESIGN.md and integration.
4. Root regenerates Tuist, runs all tests and Release build; independent review and fixes; light/dark/large-text runtime checks.

## Rulings

Proceed with implementation under the user's explicit "do all of them" instruction and existing preference for immediate implementation. Original starter learning content is visibly labeled; it must never imply imported, official or independently reviewed content. No push or merge is part of this request.

## Verification, 2026-10-10

Implemented all four features on codex/learning-practice. The starter set contains 213 kana entries, 18 grammar exercises and six reading passages with 12 comprehension questions. Kana cards use existing custom-card storage and backups. Exercise scores are session-only.

- Final workspace tests: 219 passed, zero failures, one existing Foundation Models API test skipped.
- Python importer tests: 45 passed.
- Release simulator build succeeded with no reported warnings/errors.
- Runtime checks on iPhone 17 Pro, iOS 26.4: reading list, passage, reading toggle, Vocabulary menu, local dictionary result/detail and Back through search to the same passage; comprehension answers locked, Next, Finish and score 2/2; kana selection and script change retain selected cards; grammar incorrect answer explanation and explicit advance; real daily plan opens shared review and returns without rating.
- Dark mode at maximum accessibility text size checked on kana, grammar, hub and daily plan. Kana list scroll accessibility action works; persistent Save and practice wraps within its width after shortening the label. Light reading and daily plan checked. Simulator appearance/text size restored. No synthetic study data added or learner records rated.
- Independent review fixed reading navigation by moving passage, vocabulary and questions into shared AppRoutes. Scoped rereview found no remaining P1/P2 findings. Guidance review fixed latest-miss tie ordering and accurate return labels.
- Temporary QA startup route removed before final tests and Release build.

Design gate evidence: Forest tokens/system styles and practice squares retained; named loading/empty/retry states implemented; actual stored counts and session scores only; all actions have concrete selection/navigation/save/review behavior. Native Vocabulary menu supplies a 44pt alternative to inline passage links. No runtime network added. Detailed input tests cover kana partial-save retry/deduplication and failure preventing phantom review queues.

Ruling: beginner original content is deliberately a starter set, not comprehensive grammar or JLPT coverage. Independent human linguistic review is not claimed. VoiceOver and TestFlight remain deferred. Implementation remains local; no push or merge requested for this addition.
