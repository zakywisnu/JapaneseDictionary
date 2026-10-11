import copy
import json
import unittest
from prepare_practice import DRAFT, EVIDENCE, OUTPUT, digest, export

class PracticeExportTests(unittest.TestCase):
    def setUp(self):
        self.draft = json.loads(DRAFT.read_text())
        self.evidence = json.loads(EVIDENCE.read_text())
    def refresh(self):
        self.evidence['draftHash'] = digest(self.draft)
    def test_regeneration_is_identical_and_reviews_bind_metadata(self):
        result = export(self.draft, self.evidence)
        self.assertEqual(result, json.loads(OUTPUT.read_text()))
        for activity in result['activities']:
            for question in activity['questions']:
                reviewed = copy.deepcopy(question)
                review = reviewed['metadata'].pop('review')
                reviewed['fingerprint'] = ''
                self.assertEqual(review['contentHash'], digest(reviewed))
                fingerprint = question['fingerprint']
                question['fingerprint'] = ''
                self.assertEqual(fingerprint, digest(question))
    def test_changed_answers_require_new_review(self):
        self.draft['activities'][0]['questions'][0]['acceptedAnswers'] = ['wrong']
        with self.assertRaisesRegex(ValueError, 'stale'):
            export(self.draft, self.evidence)
    def test_missing_review_is_rejected(self):
        self.evidence.pop('reviewer')
        with self.assertRaisesRegex(ValueError, 'missing'):
            export(self.draft, self.evidence)
    def test_exception_cannot_pass_rule_check(self):
        item = next(a for a in self.draft['activities'] if a.get('formID') == 'te' and a['questions'][0]['metadata']['stimulus'] == '行く')
        item['questions'][0]['acceptedAnswers'] = ['行いて']
        self.refresh()
        with self.assertRaisesRegex(ValueError, 'exception'):
            export(self.draft, self.evidence)
    def test_duplicate_and_missing_token_ids_rejected(self):
        item = next(a for a in self.draft['activities'] if a['kind'] == 'sentenceOrder')
        item['questions'][0]['metadata']['acceptedOrders'][0][0] = 'unknown'
        self.refresh()
        with self.assertRaisesRegex(ValueError, 'token order'):
            export(self.draft, self.evidence)
    def test_duplicate_activity_rejected(self):
        self.draft['activities'].append(copy.deepcopy(self.draft['activities'][0]))
        self.refresh()
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            export(self.draft, self.evidence)
    def test_cloze_answer_leak_rejected(self):
        self.draft['contexts'][0]['cloze'] += '学校'
        self.refresh()
        with self.assertRaisesRegex(ValueError, 'answer-bearing'):
            export(self.draft, self.evidence)
    def test_corpus_coverage(self):
        conjugation = [a for a in self.draft['activities'] if a['kind'] == 'conjugation']
        lemmas = {a['questions'][0]['metadata']['stimulus'] for a in conjugation}
        self.assertEqual(len(lemmas),24)
        self.assertEqual(len([a for a in self.draft['activities'] if a['kind'] == 'listeningComprehension']),6)
        self.assertGreaterEqual(len(self.draft['contexts']),20)
        sentences = [a for a in self.draft['activities'] if a['kind'] == 'sentenceOrder']
        self.assertGreaterEqual(len(sentences),20)
        self.assertTrue(any(len(a['questions'][0]['metadata']['acceptedOrders']) > 1 for a in sentences))
        self.assertTrue(any(len({t['text'] for t in a['questions'][0]['metadata']['tokens']}) < len(a['questions'][0]['metadata']['tokens']) for a in sentences))

if __name__ == '__main__':
    unittest.main()
