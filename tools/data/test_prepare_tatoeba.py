import unittest
from prepare_tatoeba import matching_words


class IndexMatchingTests(unittest.TestCase):
    def setUp(self):
        self.words = {'生': [
            {'Original': '生', 'Furigana': 'なま', 'JLPT Level': 'N5'},
            {'Original': '生', 'Furigana': 'せい', 'JLPT Level': 'N5'},
        ]}

    def test_ambiguous_headword_requires_reading(self):
        self.assertEqual(matching_words('生~', self.words), [])

    def test_checked_reading_preserves_sense_and_surface(self):
        result = matching_words('生(なま)[01]{生の}~', self.words)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0][0]['Furigana'], 'なま')
        self.assertEqual(result[0][1:], ('01', '生の'))

    def test_unchecked_or_unresolved_dictionary_id_is_not_selected(self):
        self.assertEqual(matching_words('生(なま)[01]', self.words), [])
        self.assertEqual(matching_words('生(#1234)~', self.words), [])


if __name__ == '__main__':
    unittest.main()
