import csv
import io
import unittest

from export_review_sheet import review_sheet


class ReviewSheetTests(unittest.TestCase):
    def test_exact_csv_gloss_and_pending_decisions(self):
        candidates = [{'word': {'headword': 'ああ', 'reading': 'ああ', 'level': 'N5'},
                       'japaneseId': '1', 'englishId': '2', 'japanese': 'ああだ。', 'english': 'That way.'}]
        vocabulary = [{'Original': 'ああ', 'Furigana': 'ああ', 'JLPT Level': 'N5', 'English': 'Ah!, Oh!'}]
        rows = list(csv.DictReader(io.StringIO(review_sheet(candidates, vocabulary))))
        self.assertEqual(rows[0]['csvGloss'], 'Ah!, Oh!')
        self.assertEqual(rows[0]['status'], 'pending')
        self.assertEqual(rows[0]['reviewer'], '')
        self.assertEqual(rows[0]['verifiedSense'], '')
        self.assertEqual(len(rows[0]['japaneseSha256']), 64)

    def test_missing_catalog_match_fails(self):
        candidate = {'word': {'headword': 'a', 'reading': 'a', 'level': 'N5'}, 'japaneseId': '1', 'englishId': '2'}
        with self.assertRaises(ValueError):
            review_sheet([candidate], [])
