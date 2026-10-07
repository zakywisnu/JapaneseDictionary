import copy
import unittest

from build_approved_examples import build, text_hash


class ApprovedExamplesTests(unittest.TestCase):
    def setUp(self):
        self.candidate = {'word': {'headword': 'ああ', 'reading': 'ああ', 'level': 'N5'},
                          'japaneseId': '229847', 'englishId': '67211',
                          'japanese': 'ある人はああだと言う。', 'english': 'Another says that.',
                          'japaneseSource': 'https://tatoeba.org/en/sentences/show/229847',
                          'englishSource': 'https://tatoeba.org/en/sentences/show/67211',
                          'japaneseOwner': None, 'englishOwner': 'translator',
                          'license': 'CC BY 2.0 FR'}
        self.approval = {'word': self.candidate['word'], 'japaneseId': '229847', 'englishId': '67211',
                         'japaneseSha256': text_hash(self.candidate['japanese']),
                         'englishSha256': text_hash(self.candidate['english']),
                         'status': 'approved', 'reviewer': 'human-fixture', 'reviewedOn': '2026-10-06',
                         'verifiedSense': 'Fixture only', 'reviewedReading': None}
        self.snapshot = {'downloadedOn': '2026-10-06', 'sources': [], 'vocabularySha256': 'fixture'}

    def run_build(self, candidates=None, approvals=None):
        return build(candidates or [self.candidate], {'formatVersion': 1, 'reviews': approvals if approvals is not None else [self.approval]}, self.snapshot)

    def test_pending_and_rejected_are_omitted_including_wrong_interjection(self):
        for status in ['pending', 'rejected']:
            approval = dict(self.approval, status=status, verifiedSense='Wrong sense: that way, not Ah!')
            self.assertEqual(self.run_build(approvals=[approval])['examples'], [])
        self.assertEqual(self.run_build(approvals=[])['examples'], [])

    def test_changed_text_invalidates_approval(self):
        for field in ['japanese', 'english']:
            candidate = dict(self.candidate)
            candidate[field] += '!'
            with self.assertRaisesRegex(ValueError, 'hash'):
                self.run_build(candidates=[candidate])

    def test_missing_publication_metadata_fails(self):
        for field in ['reviewer', 'reviewedOn', 'verifiedSense', 'japaneseId', 'englishId']:
            approval = dict(self.approval)
            del approval[field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_build(approvals=[approval])
        for field in ['license', 'japaneseSource', 'englishSource', 'japaneseId', 'englishId', 'japaneseOwner']:
            candidate = dict(self.candidate)
            del candidate[field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_build(candidates=[candidate])

    def test_null_owner_and_verified_reading_preserved(self):
        approval = dict(self.approval, reviewedReading='あるひとはああだという。')
        example = self.run_build(approvals=[approval])['examples'][0]
        self.assertIsNone(example['japaneseOwner'])
        self.assertEqual(example['sentenceReading'], approval['reviewedReading'])
        self.assertEqual(example['review']['reviewer'], 'human-fixture')

    def test_one_per_word_and_order_are_deterministic(self):
        second = dict(self.candidate, japaneseId='2', japaneseSource='https://tatoeba.org/en/sentences/show/2')
        approval = dict(self.approval, japaneseId='2')
        other = copy.deepcopy(self.candidate)
        other['word']['headword'] = '猫'
        other['word']['reading'] = 'ねこ'
        other_approval = dict(self.approval, word=other['word'])
        candidates = [self.candidate, second, other]
        reviews = [self.approval, approval, other_approval]
        output = self.run_build(candidates=candidates, approvals=reviews)
        self.assertEqual(len(output['examples']), 2)
        self.assertEqual(output['examples'][0]['japaneseId'], '2')
        self.assertEqual(output, self.run_build(candidates=list(reversed(candidates)), approvals=list(reversed(reviews))))

    def test_duplicate_and_unknown_ledger_records_fail(self):
        with self.assertRaises(ValueError):
            self.run_build(approvals=[self.approval, self.approval])
        with self.assertRaises(ValueError):
            self.run_build(approvals=[dict(self.approval, japaneseId='999')])
        with self.assertRaises(ValueError):
            self.run_build(approvals=[dict(self.approval, status='automatic')])

    def test_invalid_date_and_unverified_reading_fail(self):
        for change in [{'reviewedOn': '2026-02-30'}, {'reviewedReading': ''}]:
            with self.assertRaises(ValueError):
                self.run_build(approvals=[dict(self.approval, **change)])


if __name__ == '__main__':
    unittest.main()
