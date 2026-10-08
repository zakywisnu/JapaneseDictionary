import io
import csv
from pathlib import Path
import unittest
import build_vocabulary as builder

XML = '''<JMdict><entry><ent_seq>1</ent_seq>
<k_ele><keb>表</keb></k_ele><k_ele><keb>面</keb></k_ele>
<r_ele><reb>おもて</reb><re_restr>表</re_restr></r_ele>
<r_ele><reb>めん</reb><re_restr>面</re_restr></r_ele>
<sense><pos>noun</pos><stagk>表</stagk><gloss>front</gloss></sense>
<sense><stagr>おもて</stagr><gloss>surface</gloss></sense>
<sense><stagk>面</stagk><stagr>めん</stagr><pos>noun</pos><gloss>mask</gloss></sense>
</entry><entry><ent_seq>2</ent_seq><k_ele><keb>橋</keb></k_ele><r_ele><reb>はし</reb></r_ele><sense><pos>noun</pos><gloss>bridge</gloss></sense></entry>
<entry><ent_seq>3</ent_seq><k_ele><keb>箸</keb></k_ele><r_ele><reb>はし</reb></r_ele><sense><pos>noun</pos><gloss>chopsticks</gloss></sense></entry></JMdict>'''


def row(word, reading, meaning, level='N5', source='legacy', upstream=None):
    return dict(word=word, reading=reading, meanings=[meaning], level=level, source=source, upstream=upstream)


class VocabularyTests(unittest.TestCase):
    def setUp(self):
        self.dictionary = builder.parse_dictionary(io.BytesIO(XML.encode()))

    def test_reading_restrictions_and_inherited_pos(self):
        entry = self.dictionary[1]
        self.assertEqual(entry['readings'][0]['spellings'], ['表'])
        self.assertEqual(entry['senses'][1]['pos'], ['noun'])
        self.assertIsNone(builder.resolve(row('表', 'めん', 'mask'), self.dictionary)[0])
        catalog, _ = builder.build_catalog(self.dictionary, [row('面', 'めん', 'mask')], [])
        self.assertEqual(catalog['entries'][0]['studyMeanings'], ['mask'])
        self.assertEqual(len(catalog['entries'][0]['senses']), 3)

    def test_dictionary_priority_markers_survive_without_inflating_common(self):
        xml = XML.replace('<keb>表</keb>', '<keb>表</keb><ke_pri>news2</ke_pri><ke_pri>nf37</ke_pri>')
        dictionary = builder.parse_dictionary(io.BytesIO(xml.encode()))
        form = dictionary[1]['forms'][0]
        self.assertFalse(form['common'])
        self.assertTrue(any('newspaper' in note.lower() for note in form['notes']))
        self.assertTrue(any('37' in note for note in form['notes']))

    def test_meaning_disambiguates_kana_homographs(self):
        resolved, _ = builder.resolve(row('はし', 'はし', 'chopsticks'), self.dictionary)
        self.assertEqual(resolved['jmdictID'], 3)
        self.assertIsNone(builder.resolve(row('はし', 'はし', 'bridge, chopsticks'), self.dictionary)[0])
        self.assertIsNone(builder.resolve(row('はし', 'はし', 'unrelated'), self.dictionary)[0])

    def test_bad_upstream_link_does_not_override_meaning(self):
        resolved, _ = builder.resolve(row('はし', 'はし', 'chopsticks', source='open', upstream=2), self.dictionary)
        self.assertEqual(resolved['jmdictID'], 3)

    def test_explicit_override_validates_replacement_pair(self):
        candidate = row('mistyped', 'はし', 'bridge')
        overrides = [{'source':'legacy', 'word':'mistyped', 'reading':'はし', 'jmdictID':2, 'headword':'橋', 'newReading':'はし', 'reason':'reviewed typo'}]
        resolved, _ = builder.resolve(candidate, self.dictionary, overrides)
        self.assertEqual(resolved['id'], 'jmdict:2:はし:橋:s0')
        overrides[0]['newReading'] = 'おもて'
        with self.assertRaises(ValueError):
            builder.resolve(candidate, self.dictionary, overrides)

    def test_duplicates_collapse_and_legacy_order_is_stable(self):
        legacy = [row('橋', 'はし', 'bridge', 'N1'), row('箸', 'はし', 'chopsticks'), row('橋', 'はし', 'bridge', 'N1')]
        catalog, report = builder.build_catalog(self.dictionary, legacy, [row('橋', 'はし', 'bridge', 'N4', source='open', upstream=2)])
        self.assertEqual(len(catalog['entries']), 2)
        self.assertEqual(catalog['legacyMap'], ['jmdict:3:はし:箸:s0', 'jmdict:2:はし:橋:s0', 'jmdict:2:はし:橋:s0'])
        self.assertEqual([e['level'] for e in catalog['entries']], ['N5', 'N4'])

    def test_reviewed_beginner_override_supersedes_community_level(self):
        overrides = [{'source':'legacy', 'word':'橋', 'reading':'はし', 'jmdictID':2, 'level':'N5', 'reason':'reviewed beginner placement'}]
        catalog, _ = builder.build_catalog(self.dictionary, [row('橋','はし','bridge')], [row('橋','はし','bridge','N1',source='open',upstream=2)], overrides)
        self.assertEqual(catalog['entries'][0]['level'], 'N5')

    def test_different_readings_remain_distinct(self):
        catalog, _ = builder.build_catalog(self.dictionary, [row('表','おもて','front'), row('面','めん','mask')], [])
        self.assertEqual(len(catalog['entries']), 2)
        self.assertEqual(len(set(e['id'] for e in catalog['entries'])), 2)

    def test_ambiguous_legacy_slot_is_explicitly_retired(self):
        catalog, report = builder.build_catalog(self.dictionary, [row('はし','はし','bridge, chopsticks')], [])
        self.assertEqual(catalog['legacyMap'], [None])
        self.assertEqual(len(report['exclusions']), 1)

class RealSourceRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dictionary = builder.parse_dictionary(io.BytesIO((builder.ROOT / 'data/vocabulary/test-regressions.xml').read_bytes()))

    def test_mixed_homograph_glosses_are_retired(self):
        for word, meanings in [('グラス', 'glass; grass'), ('ビル', 'building; bill'), ('バット', 'bat, vat')]:
            with self.subTest(word=word):
                resolved, _ = builder.resolve(row(word, word, meanings), self.dictionary)
                self.assertIsNone(resolved)

    def test_upstream_id_cannot_break_semantic_ambiguity(self):
        resolved, _ = builder.resolve(row('グラス', 'グラス', 'glass; grass', source='open', upstream=1046430), self.dictionary)
        self.assertIsNone(resolved)

    def test_primary_gloss_uses_intended_matched_sense(self):
        for word, meaning in [('いっぱい', 'full'), ('いらっしゃい', 'welcome')]:
            with self.subTest(word=word):
                resolved, _ = builder.resolve(row(word, word, meaning), self.dictionary)
                self.assertIn(meaning, resolved['studyMeanings'])
                self.assertNotIn('one cup (of)', resolved['studyMeanings'])
                self.assertNotIn('come', resolved['studyMeanings'])

    def test_distinct_senses_with_same_reading_keep_separate_identities(self):
        catalog, _ = builder.build_catalog(self.dictionary, [row('開ける', 'あける', 'to open'), row('明ける', 'あける', 'to dawn')], [])
        self.assertEqual(len(catalog['entries']), 2)
        self.assertEqual({e['headword'] for e in catalog['entries']}, {'開ける','明ける'})
        self.assertEqual(len(set(catalog['legacyMap'])), 2)
        self.assertTrue(any('to dawn' in e['studyMeanings'] for e in catalog['entries']))

    def test_aliases_of_the_same_selected_sense_collapse(self):
        catalog, _ = builder.build_catalog(self.dictionary, [row('いっぱい', 'いっぱい', 'full'), row('一杯', 'いっぱい', 'full')], [])
        self.assertEqual(len(catalog['entries']), 1)
        self.assertEqual(len(set(catalog['legacyMap'])), 1)

if __name__ == '__main__':
    unittest.main()
