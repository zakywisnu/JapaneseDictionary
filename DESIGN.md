# DESIGN.md: 言葉の森 (Kotoba no Mori)

Design direction and system for the app. Read this before any UI work, then apply the antislop filter on top. Tokens and components live in `Frameworks/SwiftUIApps/Sources/DesignSystem/`. When a value changes, change it here first, then in `Forest.swift`.

## Identity

- **Product:** a JLPT vocabulary and kanji trainer that runs entirely on the phone. No account, no sync, no network.
- **Audience:** self-studying learners who open the app for a few minutes a day.
- **Personality:** Forest (言葉の森, "forest of words"). Calm, gentle, encouraging. Words are added one at a time and grow into a collection.
- **Dial:** ENERGY 2 / RHYTHM 2 / MOTION 1
- **Design Read:** a local-only JLPT trainer for self-study learners, in a calm forest-green study style with Mincho headwords.

## Principles

1. **One focal action per screen.** Today's focus is "Add next word/kanji". Detail's focus is the headword. Everything else defers.
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
| `danger` | `#A8402F` | `#E0806E` | Remove actions only |

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

Every headword sits in practice squares (`PracticeCells`): one square per character, with a dashed cross through the center like the 田 grid on kanji writing paper. Adjacent squares share a 1pt border.

- **Colors:** fill `sunken`, border and guides `line` (guides dashed 3/3), glyph `ink`.
- **Corners:** square, on purpose. Practice paper has square cells.
- **Sizes:** row 34pt, detail picks the largest of 120 / 96 / 72 / 56 / 44pt that fits, onboarding 132pt, splash 64pt.
- **Dynamic Type:** in rows and detail the square scales with `@ScaledMetric(relativeTo: .title2)` and the glyph stays a fixed fraction of it, so characters never spill out. Onboarding and splash art set `scalesWithText: false`.
- **Overflow:** `Headword` falls back to plain Mincho text when a word is too long for squares.

## Space, shape, depth

- **Spacing scale (`Forest.Space`):** `xs 4`, `s 8`, `m 12`, `l 16`, `xl 24`, `xxl 40`. Screen side margins are `l` (16). Spacing varies by level so the screen has rhythm; don't flatten it to one value.
- **Radius:** `12` for cards, rows, and the search field (`Forest.Radius.card`). `6` for level tags. Capsule only for the primary button and page dots. `Forest.Radius.tile` (10) is currently unused.
- **Depth:** no shadows. Separation comes from `surface` on `canvas`, hairlines, and whitespace.
- **Forbidden:** gradients, glass, glow, background patterns, decorative icons.

## Components

| Component | Purpose | Notes |
|---|---|---|
| `ScreenHeader` | Large title with optional caption above | Caption is the date on Today. Marked as a header for VoiceOver |
| `StudyKindPicker` | Words / Kanji switch | System segmented picker. Choice is remembered per screen (`@AppStorage`) |
| `StudyRow` | One word or kanji in a list | Practice squares, reading, meaning (2 lines max), optional `LevelTag`. Combined into one VoiceOver element |
| `LevelTag` | JLPT level | Hidden inside Collection, where the section header already says the level. VoiceOver reads "JLPT N5" |
| `PracticeCells` / `Headword` | The motif | See above |
| `PrimaryButtonStyle` | The screen's single focal action | Moss capsule, `onMoss` text, min height 50, full width, 0.98 press scale, 50% opacity when disabled |
| `ProgressTrack` | Learned vs total | 6pt capsule, `sunken` track, moss fill, minimum visible fill when value > 0. Hidden from VoiceOver; the number beside it is read instead |
| `StateMessage` | Empty, error, and no-results states | Title, explanation, optional bordered moss action |

Lists use `.insetGrouped` with hidden scroll background, `surface` row backgrounds, and sentence-case section headers.

## Screens

| Screen | Focal point | Structure |
|---|---|---|
| Splash | 言葉の森 in practice squares | Tagline below. Moves on after 0.6s |
| Onboarding | Character in a large square | 3 pages (言, 漢, 森), Skip top right, page dots, Next / Start learning. Finishing saves `isOnboardingComplete` |
| Today | Add next word/kanji | Date caption, picker, count card ("3 words added today", next JLPT level), list of today's items, newest first |
| Collection | The list | Search field (Japanese, reading, or English), picker, sections by JLPT level N5 → N1 with counts |
| Detail | The headword | Specimen card (squares, reading, level), definition card (Meanings, On'yomi, Kun'yomi, Strokes). Native back. Trash in toolbar opens a confirmation anchored to it |
| Progress | Words and Kanji cards | Learned "of" total, progress track, Studying level, Last added. Footnote that progress lives only on this iPhone |

Tabs are the system `TabView`: **Today** (`leaf`, the daily word grows the forest), **Collection** (`books.vertical`), **Progress** (`chart.bar`).

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
- Remove: swipe action or long-press menu in lists, toolbar trash plus confirmation in Detail. Removing decrements progress, so the confirmation says it becomes the next item offered.
- Screens reload on appear. No "pull to refresh" or "please refresh" messages.
- Search dismisses the keyboard on scroll and has a clear button.

## Motion

MOTION 1. System push/pop and tab transitions, button press scale, list insert/remove animation, numeric count transition, and a 0.2s ease when switching Words and Kanji. Nothing loops or plays on its own.

## Accessibility

- Verify light, dark, and an accessibility text size before calling UI done.
- Touch targets are at least 44pt.
- Rows are single VoiceOver elements reading headword, reading, meaning, level.
- Decorative art (onboarding squares, progress track) is hidden from VoiceOver.
- Icon-only buttons have text labels (for example "Remove from collection", "Clear search").

## Voice and copy

- Short, plain, encouraging. Say what happened and what to do next.
- Sentence case everywhere. No em dashes, no emoji, no exclamation-heavy cheerleading.
- "word" and "kanji" are the nouns. "kanji" has no plural "s".
- Errors name the item and the next step: "The next word couldn't be added. Try again."
