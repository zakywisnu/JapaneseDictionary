# Vocabulary source comparison — 7 October 2026

Recommendation: use JMdict as the dictionary foundation and a reviewed community JLPT mapping as a separate layer. OpenJLPT is the more convenient downloadable JLPT package, but the inspected snapshot has sense, reading and example defects that prevent recommending an unchanged import. Our existing CSV also needs cleanup. Keep verified existing entries that the replacement omits.

## Snapshots

- Existing bundle: Frameworks/DataKit/Resources/jlpt_vocab.csv. Last Git change June 9, 2025; original source and redistribution license were not found in the inspected repository. File age does not establish the age of its upstream content.
- [OpenJLPT](https://github.com/evanclan/OpenJLPT/tree/0d1d3410bec90bd4098a7c72de820543cb4f707c), commit 0d1d3410bec90bd4098a7c72de820543cb4f707c, October 2, 2026. Downloaded all five JSON vocabulary files. Its metadata reports version 0.3.0 and JMdict upstream dated September 29, 2026.
- [JMdict English XML](https://www.edrdg.org/pub/Nihongo/JMdict_e.gz), internal creation date October 7, 2026. The [official project](https://www.edrdg.org/jmdict/j_jmdict.html) describes daily generation.
- Downloaded files and exploratory scripts are in /private/tmp/kotoba-vocab-comparison. These temporary files are analysis inputs, not a durable release archive. Checksums and aggregate measurements are retained in [the result manifest](vocabulary-comparison-2026-10-07.json). No app resource was replaced.

## Coverage

| Level | Existing rows | OpenJLPT rows | Difference |
|---|---:|---:|---:|
| N5 | 718 | 674 | -44 |
| N4 | 668 | 630 | -38 |
| N3 | 2,139 | 1,659 | -480 |
| N2 | 1,906 | 1,778 | -128 |
| N1 | 2,699 | 3,070 | +371 |
| Total | 8,130 | 7,811 | -319 |

Our CSV has 8,033 unique headword/reading pairs. OpenJLPT has 7,811 unique pairs. Matching NFC-normalized, trimmed spelling and reading gives:

- 7,012 shared pairs.
- 1,021 pairs only in our CSV; 140 match OpenJLPT alternate spellings with the same reading.
- 799 pairs only in OpenJLPT.
- 464 shared pairs with different level sets.
- 2,648 shared pairs with different normalized English text. These are textual differences, not measured corrections.

Counts are exclusive per row's assigned level, not cumulative exam requirements. Different spellings, readings and senses make raw count comparisons imperfect. For example, our お腹 and OpenJLPT おなか can refer to the same word; our 一日 / ついたち and OpenJLPT 一日 / いちにち are different readings/senses.

## Dictionary consistency

The audit indexed JMdict spellings/readings with re_restr and re_nokanji constraints, then allowed kana lookup forms while retaining all matching homographs.

| Metric | Existing CSV | OpenJLPT |
|---|---:|---:|
| Unique pair rows checked | 8,033 | 7,811 |
| Explicit spelling/reading pair found | 7,186 | 7,330 |
| Additional kana lookup pair found | 439 | 460 |
| No pair match | 408 | 21 |
| Total pair match rate | 94.9% | 99.7% |
| Missing readings | 2 | 0 |
| Extra rows repeating a pair | 97 | 0 |

Nonmatches include phrases, annotations and compounds, not only errors. The match rate measures lexical-form compatibility, not definition correctness. 7,800 OpenJLPT rows carry a JMdict ID. Twelve linked rows fail the strict pair-to-ID check; several are legitimate derived compounds such as noun + する, and some may reflect dictionary changes. These are review flags, not twelve proven mistakes.

Our 97 duplicate-pair groups include 96 with conflicting levels and one exact full-row repetition. Distinct senses may justify some repeated forms; a canonical sense-aware representation and documented level rule are needed.

## Concrete findings

### Our CSV

- いただく has 頂く in the reading column. OpenJLPT supplies the kana reading and stores 頂く as another spelling.
- ごらんになる and かまう have empty readings.
- 副 is paired with とりわけ and an “especially” meaning. Current JMdict's 副 entry uses ふく; this row conflates separate words.
- Beginner greetings are assigned advanced levels: ありがとう and こんにちは are N3, おはよう is N2. OpenJLPT places these at N5. For this app's beginner curriculum, the latter is more appropriate; that is a pedagogical judgment, not an official JLPT ruling.
- Bundled fields are only headword, one reading, a comma-containing English string and level. There are no upstream dictionary IDs, part-of-speech tags, sense restrictions, alternate-form fields or source version.

### OpenJLPT

- 中腹 is given ちゅうっぱら and an irritated/offended meaning, while its example is about a house on a hillside. Our ちゅうふく / mountainside entry agrees with JMdict entry 1425440. OpenJLPT has no JMdict ID for this row.
- しいんと is described as quiet/silent, but linked to JMdict 1310740, the 死因 entry. Both examples concern death causes. This is a confirmed sense/link mismatch.
- けがする has an example about 胸やけ, meaning heartburn, rather than an injury. Surface substring matching is insufficient for learner examples.
- N5 せっけん is linked to 節倹, the thrift/economy homophone. Soap appears separately as 石鹸 at N2. Our soap entry is N5. This needs sense-aware level review; the existence of a valid JMdict link does not resolve it.
- 上げる supplies only the giving sense, while examples use raising a hand or speed. Giving is a valid sense, but the examples do not teach the selected gloss; our raising/lifting definition is more useful for those examples.
- ああ changes from our N5 interjection to OpenJLPT's N4 adverb. Both are valid separate JMdict entries, so this cannot be treated as a simple level correction.
- Valid alternate readings are lost by a straight replacement, e.g. our 世論 includes よろん and せろん; OpenJLPT retains せろん.

These targeted cases are enough to reject an unreviewed import. They do not establish an overall error rate for either dataset. OpenJLPT's 7,245 words with examples are coverage, not 7,245 approved teaching examples. Our app's existing human approval gate should remain.

## Which source is better?

| Criterion | Existing CSV | OpenJLPT | JMdict |
|---|---|---|---|
| Ready N5–N1 assignment | Yes, questionable cases | Yes, community mapping | No current N5–N1 field |
| Fresh dictionary content | Upstream date unknown | September 29 snapshot; glosses also derive from Waller | October 7 download; daily upstream |
| Sense/reading detail | Minimal | Simplified selected fields | Rich reading, spelling, POS and sense restrictions |
| Identity | No upstream lexical key | Stable project IDs plus most JMdict IDs | Entry IDs; reading/sense selection still needed |
| Example sentences | No approved bundled examples | Broad coverage, confirmed bad matches | Plain English dictionary dump is not our sentence corpus |
| Integration effort | Already integrated | Lower, but still requires validation/migration | Higher: subset builder and separate level mapping |
| Provenance | Not documented in inspected files | Explicit sources and notices | Primary dictionary project and license |

OpenJLPT is best for a quick structured candidate list. JMdict is best for the canonical dictionary layer. Our list is worth retaining as a comparison input because it preserves correct readings and senses that OpenJLPT changes or omits.

The [OpenJLPT notice](https://github.com/evanclan/OpenJLPT/blob/0d1d3410bec90bd4098a7c72de820543cb4f707c/NOTICE.md) says levels and primary vocabulary glosses originate in Jonathan Waller's lists; JMdict provides linking, POS and repairs. Monthly rebuilding therefore does not mean that every English meaning was refreshed directly from JMdict, or that JLPT levels were officially updated.

The [official JLPT FAQ](https://www.jlpt.jp/e/faq/index.html) explains why vocabulary specifications are not published. No source here can guarantee exact contemporary test coverage.

## Recommended app approach

1. Produce a build-time, sense-aware subset from a pinned JMdict snapshot. Store selected spellings, readings, glosses, POS, upstream IDs and attribution.
2. Import OpenJLPT community levels as candidate tags, with a documented override ledger. Inspect homographs and confirmed anomalies before publication.
3. Merge verified useful entries from our list rather than deleting all unmatched forms.
4. Keep examples behind the existing approval ledger. Review the target sense, not just word occurrence.
5. Migrate saved Add next indexes to a stable catalog identity/order strategy; preserve learner IDs, collections, review schedules and saved suggestions. Define how dictionary content changes invalidate saved AI advice.
6. Handle the changed catalog fingerprint and compatibility with older backups explicitly. Do not silently import new data into the existing fingerprint contract.
7. Bundle the validated output; the learner app stays offline. Refresh snapshots during release preparation.

Both new sources describe CC BY-SA 4.0 data licensing. Retain upstream credit and license information with the derived dataset; EDRDG also specifies an update procedure. See the [EDRDG license statement](https://www.edrdg.org/edrdg/licence.html) and OpenJLPT notice for their exact terms. The existing CSV's licensing remains undocumented in the inspected repository.

No production data or Swift code was changed by this analysis.
