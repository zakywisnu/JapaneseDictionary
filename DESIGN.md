# DESIGN.md: 言葉の森 (Kotoba no Mori)

Design direction and system for the app. Read this before any UI work, then apply the antislop filter on top. Tokens and components live in `Frameworks/SwiftUIApps/Sources/DesignSystem/`. When a value changes, change it here first, then in `Forest.swift`.

## Identity

- **Product:** a Japanese study app for vocabulary, kanji, grammar, sentences and learner-created cards that runs entirely on the phone. No account, no sync, no network.
- **Audience:** self-studying learners who open the app for a few minutes a day.
- **Personality:** Forest (言葉の森, "forest of words"). Calm, gentle, encouraging. Words are added one at a time and grow into a collection.
- **Dial:** ENERGY 2 / RHYTHM 2 / MOTION 1
- **Design Read:** a local-only JLPT trainer for self-study learners, in a calm forest-green study style with Mincho headwords.

## App icon

An ivory 森 (forest) in a square writing cell on moss green carries the Forest identity onto the Home Screen. Use a flat opaque square master; iOS supplies the outer corner mask. The brand field applies to the app icon only; screen accent rules remain unchanged. Generated source: docs/design/assets/app-icon-source-v1.png. App asset: AppIcon.appiconset/AppIcon.png, exported at 1024×1024 without alpha.

## Principles

1. **One focal action per screen.** Today's focus is "Continue learning". Detail's focus is the headword. Everything else defers.
2. **Real data only.** Counts, levels, and dates come from the bundled lists and the learner's saved progress. No invented stats, streaks, or placeholder people.
3. **Honest about being local.** Copy never implies accounts, sync, or online features.
4. **The character is the hero.** Japanese text is set large, in Mincho, inside a practice square. Chrome stays quiet.
5. **Comfort over cleverness.** System controls (tab bar, segmented picker, swipe actions, confirmation dialogs), no artificial delays, no auto-advancing tours.

## Color

One accent (moss), warm paper neutrals, one destructive color. Every text pair passes WCAG AA in both modes.

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F1EFE3` | `#141813` | Screen background |
| `surface` | `#FDFCF8` | `#1D231C` | Cards, list rows, search field |
| `sunken` | `#E4E8D8` | `#263025` | Practice squares, level tags, progress track |
| `ink` | `#22281F` | `#ECEEE4` | Primary text, headwords |
| `inkMuted` | `#5B6356` | `#A6AE9E` | Readings, captions, section headers, placeholders |
| `line` | `#DAD8C6` | `#2F382D` | Hairlines, square borders and guides, inactive page dots |
| `moss` | `#45694D` | `#8DB592` | The accent |
| `onMoss` | `#FFFFFF` | `#10170F` | Text on moss |
| `danger` | `#A8402F` | `#E0806E` | Remove and backup replacement actions only |

Checked contrast ratios:

| Pair | Light | Dark |
|---|---|---|
| `inkMuted` on `canvas` / `surface` | 5.4:1 | 7.0:1 |
| `inkMuted` on `sunken` | 5.0:1 | 6.0:1 |
| `moss` text on `canvas` | 5.4:1 | 7.8:1 |
| `onMoss` on `moss` | 6.2:1 | 7.9:1 |
| `danger` on `surface` | 6.0:1 | 5.7:1 |

Moss is the brand color carried over from ZeroDesignKit (`#537D5D`), darkened to `#45694D` because the original measured 4.1:1 on `canvas`.

**Accent rule:** moss appears only on the primary action button, progress fills, the selected tab, the active page dot, and system tint (back button, bordered retry buttons). Never on row icons, backgrounds, or decoration.

**Don't use** ZeroDesignKit's `DefaultColors`, raw `Color.red/.green/.blue`, or hex literals in views.

## Typography

| Role | Face | Style |
|---|---|---|
| Headword (Japanese being studied) | Hiragino Mincho ProN W6 (`Font.headwordFace`) | Sized to its practice square: glyph is 62% of the square side |
| Screen title | System | `.largeTitle.bold()` |
| Card title | System | `.headline` |
| Big count | System rounded | `.largeTitle`, semibold |
| Body, English meaning | System | `.body` |
| Reading, caption | System | `.subheadline` in `inkMuted` |
| Section header | System | `.subheadline.weight(.semibold)`, sentence case, `inkMuted` |
| Level tag | System | `.caption.weight(.semibold).monospacedDigit()` |

- Mincho is reserved for Japanese headwords. Readings (kana) under a headword use the system font so they read as annotation.
- All system text uses text styles so Dynamic Type works. No uppercase tracked labels.

## Identity motif: the practice square

Detail specimens and short kana study prompts use practice squares (`PracticeCells`): one square per character, with a dashed cross through the center like the 田 grid on kanji writing paper. Adjacent squares share a 1pt border. Collection rows use plain wrapping Mincho so longer headwords remain readable.

- **Colors:** fill `sunken`, border and guides `line` (guides dashed 3/3), glyph `ink`.
- **Corners:** square, on purpose. Practice paper has square cells.
- **Sizes:** row 34pt, detail picks the largest of 120 / 96 / 72 / 56 / 44pt that fits, onboarding 132pt (96pt at accessibility text sizes), splash 64pt.
- **Dynamic Type:** in rows and detail the square scales with `@ScaledMetric(relativeTo: .title2)` and the glyph stays a fixed fraction of it, so characters never spill out. Onboarding and splash art set `scalesWithText: false`.
- **Overflow:** `Headword` falls back to plain Mincho text when a word is too long for squares.

## Space, shape, depth

- **Spacing scale (`Forest.Space`):** `xs 4`, `s 8`, `m 12`, `l 16`, `xl 24`, `xxl 40`. Screen side margins are `l` (16). Spacing varies by level so the screen has rhythm; don't flatten it to one value.
- **Radius:** `12` for cards and primary actions (`Forest.Radius.card`). `8` for secondary controls, selector triggers and answer fields (`Forest.Radius.control`). `6` for level tags. Capsules remain in the unchanged native tab bar and progress tracks. `Forest.Radius.tile` (10) is currently unused.
- **Depth:** no shadows. Separation comes from `surface` on `canvas`, hairlines, and whitespace.
- **Forbidden:** gradients, glass, glow, background patterns, decorative icons.

## Components

| Component | Purpose | Notes |
|---|---|---|
| `ScreenHeader` | Large title with optional caption above | Caption is the date on Today. Marked as a header for VoiceOver |
| `StudyKindPicker` | Words / Kanji switch | System segmented picker. Choice is remembered per screen (`@AppStorage`) |
| `StudyRow` | One word or kanji in a list | Wrapping Mincho headword, reading and meaning (2 lines at standard sizes, unrestricted at accessibility sizes), centered trailing level/chevron group. Combined into one VoiceOver element |
| `LevelTag` | JLPT level | Individual level remains beside the aligned disclosure group; section headers also show level totals. VoiceOver reads "JLPT N5" |
| `PracticeCells` / `Headword` | The motif | See above |
| `PrimaryButtonStyle` | The screen's single focal action | Moss rounded rectangle with 12pt corners, `onMoss` text, min height 52, wrapping label, full width. Disabled uses sunken/inkMuted rather than translucent text. Reduce Motion disables press scaling |
| `ForestNavigationRow` | Neutral navigation or action row | Wrapping title and optional subtitle, disclosure chevron, 16pt horizontal / 12pt vertical padding |
| `ProgressTrack` | Learned vs total | 6pt capsule, `sunken` track, moss fill, minimum visible fill when value > 0. Hidden from VoiceOver; the number beside it is read instead |
| `StateMessage` | Empty, error, and no-results states | Title, explanation, optional bordered moss action |

Study lists use `.plain` with hidden scroll background, custom bounded `surface` row groups, and sentence-case section headers. Settings and system forms retain native grouping.

## Screens

| Screen | Focal point | Structure |
|---|---|---|
| Splash | 言葉の森 in practice squares | Tagline below. Moves on after 0.6s |
| Onboarding | Character in a large square | 3 pages (言, 漢, 森), Skip top right, page dots, Next / Start learning. Finishing saves `isOnboardingComplete` |
| Today | Continue learning | Date, compact goal track, continuation, one daily-plan row, material picker, grouped due review and neutral Add next, then today's items |
| Collection | The list | Scrollable title with Options, material picker beside neutral Review, search, and JLPT sections. Controls stack at accessibility sizes |
| Practice | Starter path and skills | One primary starter-path action, grouped Kana and recall, Grammar, Reading, Listening and Speaking rows, then expandable Practice options |
| Detail | The headword | Specimen card (squares, reading, level), definition card (Meanings, On'yomi, Kun'yomi, Strokes). Native back. Trash in toolbar opens a confirmation anchored to it |
| Progress | This week | Compact practice summary, expandable collection rows, and neutral Weekly recap / Activity details links. Settings opens from the header. Detailed metrics and data controls live on separate native screens |

Tabs are the unchanged system `TabView`: **Today** (`leaf`), **Collection** (`books.vertical`), **Practice** (`square.grid.2x2`), **Progress** (`chart.bar`).

## States

Every list screen has all three. Each says why and what to do next.

| State | Pattern | Example |
|---|---|---|
| Loading | `ProgressView` with what is loading | "Loading today's words" |
| Empty | `StateMessage` with the action that fills it | "No words yet" + Go to Today |
| Error | `StateMessage` with a working retry | "Couldn't open your word list" + Try again |
| No results | `StateMessage`, no action | "No matches for "meetx"" |
| Action failed | Alert naming the item | "青 couldn't be removed. Try again." |
| Finished list | Disabled add button with caption | "You've added every word in the list." |

## Interaction

- Add is instant; the new row appears at the top of Today.
- Remove: swipe action or long-press menu in lists, toolbar trash in Detail. Every entry point asks for confirmation, naming the headword and explaining removal from the collection and progress. Kanji confirmation also explains that it becomes the next item offered. Full-swipe removal is disabled.
- Screens reload on appear. No "pull to refresh" or "please refresh" messages.
- Search dismisses the keyboard on scroll and has a clear button.
- Clear search has its own 44pt touch target. Onboarding pages scroll at accessibility text sizes, with smaller fixed artwork and persistent Next / Start learning controls.

## Motion

MOTION 1. System push/pop and tab transitions, button press scale, list insert/remove animation, numeric count transition, and a 0.2s ease when switching Words and Kanji. Nothing loops or plays on its own.

## Accessibility

- Verify light, dark, and an accessibility text size before calling UI done.
- Touch targets are at least 44pt.
- Rows are single VoiceOver elements reading headword, reading, meaning, level.
- Decorative art (onboarding squares, progress track) is hidden from VoiceOver.
- Icon-only buttons have text labels (for example "Remove from collection", "Clear search").

## Review flow

Today offers a neutral Review today's words / kanji action when the selected list has loaded with at least one item. Continue learning remains the moss primary action. Review snapshots the saved items in their current order and does not change collection progress.

Collection offers a neutral Review words / kanji action after successful loading with saved items, including when browsing search has no matches. Its setup sheet independently selects All levels or N5–N1 and 10, 20 (default), or All items. Show the selected count; disable Start review for empty selections and explain how to choose another level. Start snapshots saved content, newest first with saved ID as the date tie-break. Search never silently filters review. Cancel returns without starting a session.

The pushed review screen hides the tab bar. Show the headword and level first, then reveal stored readings and meanings on request. Keep the headword stable during reveal, honor Reduce Motion, and reset scroll position when changing items. The bottom safe-area action remains reachable while long answers scroll. After reveal, Got it removes the item and Again returns it to the end of the in-memory queue, hiding the answer even when only one item remains. Got it is moss; Again is neutral with a 44pt target. Explain that Again repeats this session. Show remaining items rather than a fixed position; omit Previous because ratings have already consumed queue entries.

Completion says how many distinct items were practiced, reports repeat attempts separately, and says whether they were added today or came from the collection, with Back to Today / Back to Collection and a neutral Review again action. Empty sessions use StateMessage with a next step. The full interaction and edge cases are in `docs/design/review-flow.md`.

## Due review and optional examples

Today separates Due for review from Added today for the selected Words / Kanji kind. Its neutral action shows the due count; Continue learning remains the moss primary action. Loading names the due list, empty explains adding or returning later, and failures name the saved collection or schedule with Try again. Ratings in this mode save before changing the queue. A save failure keeps the revealed item and offers Retry / Exit review. Retry preserves the pending rating and session identity. Successful reviews use 1, 3, 7, 14 and 30 calendar-day intervals; Again resets to 1 day. Today and Collection practice leave schedules unchanged. Completion says these items were due for review without claiming mastery. Completed due sessions offer only Back to Today; the next session must load a fresh due list rather than repeat the stale snapshot.

Approved vocabulary examples appear as an optional answer card only after reveal, matched by the original headword, reading and level. Kana-only words retain their original reading for matching while omitting its duplicate display. Missing or unreadable optional examples do not interrupt review. Sources is a pushed screen with native back navigation. The current release has zero approved examples, so no example cards appear.

## Local backup

Progress offers Backup and restore as a neutral action. The pushed screen explains that a backup contains the collection, progress and review dates. Export uses the system file picker so the learner chooses where to keep a JSON file. Import accepts a chosen JSON file, validates it before offering any replacement, and shows its date and word / kanji counts. Cancel leaves current data untouched. Replace current collection is an explicit destructive confirmation; it replaces rather than merges the selected backup.

Before replacement, save a recovery backup of the current collection locally. Failed validation or saving gives a concrete next action and keeps current data available. Success returns to Progress, clears active review routes and offers Share recovery backup so the learner can keep the prior collection's file. All backup processing works offline; choosing a system Files destination does not add accounts or sync to the app.

## Word memory helper

Word Detail offers a neutral Help me remember action after the saved study meaning, bundled dictionary details and optional reviewed example. The headword remains the focal point. Generation produces a short Explanation and Memory tip card, with the caption "AI-generated suggestion. Check it against your study meaning." It never replaces dictionary content or presents a mnemonic as a kanji's historical origin. Kanji Detail has no helper.

Generate only on request. Show a named loading indicator and Cancel while generating. Regenerate keeps the previous suggestion visible; failure keeps it available and offers retry. Save suggestion is explicit; success says Saved on this iPhone. Unsaved results say Not saved. Persisted advice remains readable when the model is unavailable. Unsupported OS/device, disabled Apple Intelligence, preparing model and unsupported language each explain why generation is unavailable, with Check availability where useful. Native back cancels pending work without saving. Use existing Forest colors/spacing/card radius and system text styles; no decorative AI icon or badge.

## Voice and copy

- Short, plain, encouraging. Say what happened and what to do next.
- Sentence case everywhere. No em dashes, no emoji, no exclamation-heavy cheerleading.
- "word" and "kanji" are the nouns. "kanji" has no plural "s".
- Errors name the item and the next step: "The next word couldn't be added. Try again."

## Full vocabulary dictionary

Word Detail keeps the saved headword, reading and Study meaning first. Dictionary meanings follow as numbered sense groups, with part of speech, usage labels, source notes and spelling/reading restrictions attached to each affected sense. All readings and written forms are visible immediately, including their restrictions, common-word markers and source notes; no disclosure controls hide dictionary content. JLPT vocabulary levels are community estimates, not official exam coverage. Kanji Detail keeps its existing layout.

Saved study meanings continue to ground review and the memory helper. A uniquely linked current entry may offer a neutral Update study word action. Its confirmation previews the current dictionary headword, reading, level and study meanings, explains that existing AI advice will be cleared if its context changes, and preserves the learner's identity, date and review schedule. Failed or ambiguous dictionary lookup leaves saved study content usable with a concrete explanation; failed resource loading offers retry. Sources opens offline dictionary attribution and license notices.

Collection search includes alternate dictionary forms and readings only for confidently linked entries. Progress distinguishes Words in collection from Current study list size, because preserved legacy words may lie outside the refreshed catalog. Words have no coverage bar; the collection count can include duplicates and retired entries. Kanji retains its progress track.

## Offline dictionary browsing

Collection's Words view offers Browse dictionary in Options. It opens a separate native Dictionary screen; Collection search still searches saved items. Dictionary search covers supplied Japanese forms, readings and English meanings, with a native menu for All levels or community N5–N1. Blank search shows catalog order. Results use StudyRow with level and a neutral In collection caption for the exact study identity. Distinct study senses remain separate rows. Loading names the dictionary; resource or saved-collection errors offer Try again. No matches explains the search and offers Clear filters.

Dictionary entry detail shows the headword, primary reading, community level and the chosen Study meaning, followed by all DictionaryDetailCard sections and Sources. Add to collection is the single moss action in the bottom safe area. After saving, View saved word opens the existing saved detail; saved meanings and AI advice remain there. Failed addition keeps the entry and permits retry. Selecting a word leaves the next sequential word on Today unchanged. Dictionary browsing has no trash, review rating or AI action before saving.

Empty and error messages wrap at large text sizes. Dictionary browsing puts long state guidance and its recovery action in a scrollable area.

## Study lists

Collection Words offers neutral Study lists and Browse dictionary actions. Lists reference saved words; assigning a word to multiple lists never copies it. Native list/detail routes show loading, empty and retry states. Create/rename sheets retain input after failure and allow Cancel. Word Detail opens an Organize in lists sheet with independent choices and explicit Save. Remove from this list retains the saved word, progress and schedules. Deleting a list asks for confirmation and explains that words stay in Collection. Review list reuses level/limit setup and the practice queue, returns to its list and leaves due dates unchanged.

## Pronunciation

Listen is a neutral action near supplied readings in Word and Dictionary detail. Kanji detail plays individual supplied kana readings; it never guesses a character reading. Synthesized speech is labeled plainly. Explicit Listen playback remains audible in Silent mode, ducks other audio while speaking, and releases its audio session when stopped or finished. Review shows Listen only after Reveal answer. Stop on hiding the answer, changing items, leaving the screen or backgrounding. Missing Japanese voice explains availability with Check again; failures offer retry. Controls use system text styles, Forest colors and 44pt targets.

## Daily practice goal

Today shows a compact X of Y items practiced today summary; default target is 10. Progress offers Off, 5, 10, 20 or 30 through a native settings screen with Save/Cancel. Count each saved word or kanji marked Got it once per local day across all practice and due modes. Again, adding, browsing and listening do not count. Goal reached permits continued study and claims no mastery. Save failure retains the revealed item and offers Retry/Exit. Off hides the summary while keeping activity. No streak pressure or reminders.

## Expanded backup

Backups include study lists, memberships, daily goal and practice activity alongside existing collection/progress/reviews/advice. Format 3 separates backup compatibility from dictionary catalog version. Restore previews lists and practice data as well as saved items; confirmation explains replacement and recovery. Older supported backups supply empty lists/activity and the default goal.

## Broader study material

Today and Collection select Words, Kanji, Grammar, Sentences or Your cards through a native menu, preserving the existing remembered Words/Kanji values. Study lists accept mixed saved items. Collection offers Lessons for the bundled grammar/sentence catalog, and Create card for Your cards. Bundled browsing never counts as saved study or daily practice. Saving a lesson stores its content and source locally; updates never silently change saved answers.

Grammar detail shows meaning, formation, explanation, examples and usage notes immediately. Sentence detail shows its translation and parent lesson references; its level caption says From an N5 lesson rather than independently grading the whole sentence. Community source information and license notices are readable offline. Related lessons use native navigation. The existing pending Tatoeba word examples remain unpublished.

Custom cards have a required prompt/answer, optional supplied kana reading, notes, optional JLPT level and Grammar/Sentence/Kana/Other category. Native Save/Cancel retains the draft on failure. A meaningful prompt/answer/reading edit asks before resetting that card's review dates and difficult status. Notes/category/level edits retain them. Long Japanese prompts use wrapping Mincho text; other prompts use system text styles, without forcing prose into practice squares.

Review preserves the reveal/Again/Got it interaction for every saved kind and mixed lists. Answers and answer-bearing lesson metadata appear only after reveal. Mixed counts say items. Again repeats and also saves the item for difficult practice; Got it after a miss in the same session does not clear that status. First-try Got it in a later session clears it. Save failures retain the revealed item and stable pending action/date for Retry/Exit. Daily goals count each composite saved identity once per local day.

Practice difficult items is a neutral entry in Today and Collection. Its native setup filters material type, JLPT level including Unspecified, list, and 10/20/All. Show the matching count and disable Start for an empty selection. Most-missed items come first, then latest miss, then stable identity. Empty guidance explains using Again during review; no matching filters offers Clear filters. Extra practice preserves due dates and claims no mastery.

Format 4 adds custom cards, saved lesson snapshots, mixed memberships and difficult records. Backup previews name counts by kind and replace all learner data only after validation and recovery export. Older supported backups migrate word memberships explicitly and supply empty new material/difficulty arrays.

## Learning practice and daily guidance

Learning practice is a native pushed list of Kana, Grammar exercises and Reading practice. Today offers a neutral Daily study plan action. Collection uses a native Study options menu to avoid a tall fixed header. All screens retain Forest ENERGY 2 / RHYTHM 2 / MOTION 1, moss only for the current primary action, system text styles and scrollable content.

Kana uses practice cells, native script/group filters, supplied pronunciation and explicit Save and practice; saving creates ordinary local kana-category cards, preserving existing review and backup behavior. Exercises show choices, then an explanation after answering, followed by Next. Answers never auto-advance. Reading keeps the passage first, with optional reading/translation, tappable vocabulary and comprehension questions. Starter exercises and passages are labeled original beginner practice, without JLPT coverage claims.

Daily guidance shows actual due, difficult and unreviewed saved-item counts, limited batches and reasons. Due reviews retain scheduling semantics; other practice leaves schedules unchanged. Empty guidance offers kana or lessons, and load failures name the collection or schedules and offer retry. No invented achievement counts or estimated mastery.

## Persistent learning and speaking

Exercises persist submitted answers and revealed checkpoints before advancing. Save failure keeps the chosen answer or typed draft visible with Retry and Exit; retry keeps the same action identity. History shows actual submitted outcomes, and Mistakes uses the latest objectively incorrect response per content revision. Continue learning opens the latest valid unfinished activity or next beginner path step. Today guidance belongs in scrollable content, with a single primary Continue action and neutral daily-plan support.

Listening hides answer content until explicit reveal; typed answers use supplied readings and explicit accepted variants. Keep vowels, small kana and voicing distinct. Progress separates checked quiz answers from self-rated recall and collection counts, with denominators and time range. Passage vocabulary saving is explicit, names the passage list and preserves learner identity.

Speaking is Listen, Record, Stop, Replay, Compare and Try again. Only supported on-device recognition is used; no asset downloads or server fallback. Matching copy says what the recognizer heard rather than declaring pronunciation correct. Unknown readings, silence and isolated sounds offer inconclusive feedback. No pitch or percentage grade. Optional Explain this result is a neutral action; the model selects reviewed transcript explanations and listening/replay tips, labeled "AI-selected suggestion. Based only on transcript evidence." Invalid selections retain the basic result. Recordings are temporary and cleared on exit/retry; cancelling recognition retains replay. System permission prompts preserve their pending Record action. All controls use Forest tokens and native navigation, with scrolling at accessibility sizes.

Connected learning follow-through: sentence and personal-card details offer speaking only with a valid supplied Japanese reading. Starter steps show Current, Attempted, Completed or Skipped, and completing all required answers then Finish advances the path atomically. Progress shows remaining reviews due now and mistakes by answer type, separately from the selected history period. Today shows a neutral daily-plan summary with actual recommended batch counts and Open plan.


## Applied practice and navigation

Native tabs are Today, Collection, Practice and Progress. Practice is a first-class scrollable activity hub; Today keeps continuation and daily guidance. Progress holds the weekly recap. Existing Learning practice routes still work. No fifth tab is required for this release.

Conjugation shows a supplied dictionary form and requested target, then explicit Check and a reviewed answer explanation. Sentence building uses wrapping token buttons, a selected sequence, Undo/Clear and Check; duplicate token labels retain separate identities. Contextual word reviews are optional and hide full sentences, translations and audio until Reveal. Listening comprehension hides transcripts until explicit reveal; revealing a transcript makes remaining questions assisted, with no checked score. Weekly recap shows exact local date ranges, retained-history limits, separate checked/self-rated counts and a reason for the next focus. New modes use original beginner content with transparent model-check provenance; human language review must never be implied.

## Progress hierarchy

Keep the existing native tab bar unchanged. Progress starts with This week, using real practice history and a Choose practice action when empty. Collection counts share one grouped surface; current list size and last-added dates expand on request. Weekly recap and Activity details are neutral navigation rows. Settings holds daily goal, optional sentence context, backup/recovery and sources. Activity details shows the selected period, nonempty graded and self-rated results separately, current due reviews and starter path. Hide zero-result breakdowns; explain counting and retained-history limits in a disclosure. Weekly recap keeps the date range and next focus prominent, with comparison methodology behind a disclosure. All content scrolls at accessibility sizes.

## Shared tab spacing

Use 16pt screen margins, 24pt section gaps and 12pt vertical row padding. Controls have at least 44pt targets. Content determines height; text wraps and horizontal control groups stack at accessibility sizes. Native scroll views clear the unchanged system tab bar and safe areas. Today keeps one primary Continue action; adding and due review are neutral. Collection headers scroll with their lists, including empty and error states.

## Screen refinement

Navigation rows apply their 44pt minimum after 12pt vertical padding, avoiding stacked minimum heights. Collection counts align centrally with disclosure indicators. Progress uses a quiet empty-state sentence and a plain 44pt Settings icon. Today uses muted goal text and a compact material menu beside Your study. Collection shows a compact material menu with an explicit accessibility label. Practice descriptions stay short.

Word Detail places study meaning directly after the specimen, followed by grouped secondary actions and all immediately visible dictionary content. Starter path uses one title/status row per step; Skip and completion from past practice live in the opened step's Options menu. Kana places character and romanization together, with compact audio controls; shared guidance and synthesized-speech attribution appear once per group. Daily plan puts each batch action before expandable item previews. Review setup explains only the selected material, stacks explanatory copy with its associated control and uses a menu at accessibility sizes. Typed practice hides zero exclusions and puts Start practice in the bottom safe area; counting guidance expands on request.

## Session refinement

Questions remain the focal content. Answer feedback uses a leading-aligned surface with wrapping text and neutral labels; it never relies on color alone. Multiple-choice Next and completion actions stay in the bottom safe area. Completion summaries separate checked answers, self-ratings and repeat attempts, hide zero-only details and offer a clear return action. Content provenance appears in a disclosure below the task. New questions reset the scroll position so feedback from the previous answer cannot leave the next prompt offscreen.

## Recall session actions

Typed and listening recall use one bottom safe-area action group: Check answer before submission, Next question after feedback, and Retry saving / Exit practice after a persistence failure. Keyboard submission uses the same eligibility check as the button. The answer field has a visible label and uses the Forest surface. Feedback keeps the learner's answer and supplied answers together, with neutral text rather than color-only grading. Self-rated meaning recall and unchecked reveals remain explicitly distinct. The error state keeps the draft or revealed feedback visible and suppresses advancement until Retry succeeds.

When the keyboard or text size changes the available height, recall sessions scroll the focused answer field into view while keeping the primary action above the keyboard. Opening a session does not focus the field automatically.

## Defined Forest components

Use selective paper surfaces with a 1pt inkMuted boundary for actionable groups, feedback and inputs. Borders identify these regions while warm canvas and open typography carry informational summaries. Shared forestSurface and forestStudyCard treatments propagate to detail, setup, review, recall, speaking, history and recovery screens. Study lists use plain native Lists so system group corner masks cannot clip custom boundaries. Rows retain swipe actions; their boundary follows the first/middle/last row of each group.

Secondary buttons and compact material-selector triggers use 8pt corners, a surface fill and inkMuted outline, with at least 44pt targets. Native menus, input, confirmations, file pickers and the four-tab bar remain native. Audio uses a labeled speaker/stop control. No borders around decorative skill signs: Mincho kana/grammar/reading specimens and neutral listening/speaking symbols identify actual tasks. A whole skill row is one target.

Collection rows use larger wrapping Mincho headwords. The level label and disclosure chevron share a centered trailing group; accessibility sizes stack this group beneath the study content. Group headers remain available for level counts, with the individual level shown beside each word.

Progress shows the actual trailing seven calendar dates and outlined day cells. Cells report retained submitted exercise answers plus review rating events, deduplicated by their existing identities. A checkmark represents older saved-item activity with no retained response count, and a dash means no recorded activity. Label the counting basis and keep these response counts separate from graded results and distinct saved-item counts. No future dates, inferred streaks or invented activity.

## Interaction and long-content polish

Navigation and study rows show a sunken fill while pressed, without changing their size. Exercise choices use the same neutral fill plus a 2pt ink outline when selected, alongside a checkmark. Locked submitted answers retain their selected appearance. Selection never implies correctness and never uses the destructive color. Native navigation, explicit Next and persistence guards remain unchanged.

Long headwords wrap rather than stop at two lines. Saved-material answer previews expand at accessibility sizes. Listening playback controls stack at accessibility sizes. Press feedback requires no animation; primary-button scaling is disabled with Reduce Motion.
