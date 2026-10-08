import copy
import unittest
import hashlib
import json
from pathlib import Path
from prepare_current_examples import reconcile, context_hash, select_batch, legacy_slots

class CurrentExamplesTests(unittest.TestCase):
    def setUp(self):
        self.word = dict(id='sense1', headword='ああ', reading='ああ', level='N5', studyMeanings=['ah!', 'oh!'], senses=[{'notes':['interjection']}])
        self.candidate = dict(word={k:self.word[k] for k in ('headword','reading','level')}, japaneseId='2', englishId='3', japanese='ああ。', english='Ah!')
        self.mapping = [(self.candidate['word'], 'sense1')]
    def test_exact_mapping_and_pending_multiple_meanings(self):
        row = reconcile([self.candidate], [self.word], self.mapping)[0]
        self.assertEqual(row['catalogID'], 'sense1')
        self.assertEqual(row['selectedStudyMeanings'], ['ah!', 'oh!'])
        self.assertEqual(row['reviewStatus'], 'pending')
        self.assertEqual(row['contextSha256'], context_hash(self.word))
    def test_retired_ambiguous_and_absent_mapping(self):
        for mapping in [[], [(self.candidate['word'], None)], self.mapping+[(self.candidate['word'],'sense2')]]:
            row = reconcile([self.candidate], [self.word], mapping)[0]
            self.assertEqual(row['reviewStatus'], 'unresolved')
            self.assertTrue(row['unresolvedCause'])
    def test_production_candidates_remain_pending_and_bundle_empty(self):
        root=Path(__file__).resolve().parents[2]
        raw=(root/'data/tatoeba/n5-candidates.json').read_bytes()
        candidates=json.loads(raw)
        catalog=json.loads((root/'Frameworks/DataKit/Resources/vocabulary-v2.json').read_text())
        import csv
        with (root/'Frameworks/DataKit/Resources/jlpt_vocab.csv').open(newline='') as source:
            mappings=legacy_slots(list(csv.DictReader(source)),catalog['legacyMap'])
        rows=reconcile(candidates,catalog,mappings)
        self.assertTrue(all(row['reviewStatus'] in ('pending','unresolved') for row in rows))
        self.assertEqual(hashlib.sha256(raw).digest(),hashlib.sha256((root/'data/tatoeba/n5-candidates.json').read_bytes()).digest())
        self.assertEqual(len(select_batch(rows)),30)
        self.assertEqual(len({row['catalogID'] for row in select_batch(rows)}),30)
        self.assertEqual(next(row for row in rows if row['word']['headword']=='ああ')['reviewStatus'],'pending')
        self.assertEqual(json.loads((root/'data/tatoeba/approvals.json').read_text())['reviews'],[])
        self.assertEqual(json.loads((root/'Frameworks/DataKit/Resources/examples-n5.json').read_text())['examples'],[])

    def test_legacy_slots_follow_level_stable_order(self):
        rows=[{'Original':'上','Furigana':'うえ','JLPT Level':'N4'}, {'Original':'ああ','Furigana':'ああ','JLPT Level':'N5'}]
        self.assertEqual(legacy_slots(rows,['sense1','sense2'])[0],self.mapping[0])
        with self.assertRaises(ValueError): legacy_slots(rows,['sense1'])

    def test_hash_covers_exact_context(self):
        for field in ('id','headword','reading','level','studyMeanings'):
            word=copy.deepcopy(self.word)
            word[field] = ['changed'] if field=='studyMeanings' else 'changed'
            self.assertNotEqual(context_hash(word), context_hash(self.word))
    def test_stable_unique_selection_and_no_mutation(self):
        original=copy.deepcopy(self.candidate)
        candidates=[dict(self.candidate,japaneseId='10'),self.candidate]
        rows=reconcile(candidates,[self.word],self.mapping)
        self.assertEqual(select_batch(rows)[0]['japaneseId'],'2')
        self.assertEqual(select_batch(rows),select_batch(list(reversed(rows))))
        self.assertEqual(self.candidate,original)
        self.assertEqual(len(select_batch(rows)),1)

if __name__=='__main__': unittest.main()
