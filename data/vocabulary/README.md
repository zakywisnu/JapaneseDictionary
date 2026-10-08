# Offline vocabulary catalog v2

Run `python3 tools/data/build_vocabulary.py` using locally archived snapshots.
For the first local archive, add `--archive-from /path/to/downloaded/sources`.
The raw snapshots are ignored by Git. `sources.json` pins their hashes and the
unchanged original CSV hash; changed inputs fail before output is written.
Run `python3 -m unittest discover -s tools/data -p test_vocabulary.py`.

`vocabulary-v2.json` contains one identity per JMdict entry ID, selected
reading, canonical primary headword and selected sense index. Different study
senses (such as 開ける/open and 明ける/dawn) remain separate. Aliases of the same
selected sense collapse to its canonical primary form. All dictionary forms, readings,
English senses, restrictions, inherited parts of speech, labels and notes
remain available. The primary study gloss is the English sense with the strongest intended-gloss
evidence among senses compatible with the selected form/reading. Equal matches
within one dictionary entry select the first supported sense. Reviewed overrides
name a specific sense index. All glosses in that selected sense remain together.

Candidates require a supported spelling/reading pair (kana lookup is allowed)
and English intended-sense evidence. The matcher compares normalized English
content tokens against applicable glosses. Any competing dictionary entries with positive intended-gloss evidence are
excluded; an upstream ID cannot break semantic ambiguity. Coverage uses the
intended tokens as denominator, avoiding a perfect score for a single token
from a mixed teaching gloss. This is conservative automated
matching, not a claim that every source gloss has been manually reviewed.
`overrides.json` records reviewed exceptions; replacement pairs are validated.

OpenJLPT placements take precedence over legacy placements when the identity
is present in both lists. Reviewed overrides take precedence over both.
Duplicate OpenJLPT placements use the earlier beginner level. A legacy-only
identity uses its first slot in the stable N5-to-N1 legacy order. Original CSV
rows, including duplicates and retired rows, each retain a `legacyMap` slot.
Within each current level, order is reading, headword, then JMdict ID.

`report.json` lists all excluded source rows, with causes; their learner records
must remain usable during app migration. It also records every included source
row's decision and original level. No candidate examples are imported.
The original CSV's undocumented licence is explicitly acknowledged in notices.
The new shipped English definitions are exclusively dictionary-derived.

The original `DefaultCSVReader.read(from: URL)` calls its own quote-aware
string reader. A full-file compatibility check found 8,131 rows including the
header and identical headwords, readings, levels and row order to Python CSV.
Two English fields differ only because the Swift reader discards escaped literal
quotes; those quotes do not affect the matching tokens or legacy slot identity.
The unrelated naive `CSVParser` is not used to reproduce legacy slots.
