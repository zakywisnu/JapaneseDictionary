import unittest
from prepare_lessons import build_bundle, annotation_reading, COMMIT, SNAPSHOT, ROOT


def lesson(slug='sample', level=5):
    return dict(slug=slug, title='見る', kana='みる', romaji='miru', meaning='see', jlpt=level,
                summary='An explanation.', structure=['Verb'], pitfalls=[], examples=[dict(ja='見る。', en='See.', f='｜見[み]る。')], synonyms=[], antonyms=[], related=[], sources=['community'])


class LessonsTests(unittest.TestCase):
    def test_each_material_preserves_pinned_copyright_and_permission_notice(self):
        license_text = (ROOT / 'data/lessons/raw/LICENSE').read_text()
        grammar_statement = next(line for line in (ROOT / 'data/lessons/raw/LICENSE-DATA.md').read_text().splitlines()
                                 if line.startswith('| `src/data/grammar/`'))
        materials = build_bundle([lesson()])['materials']
        self.assertEqual({material['kind'] for material in materials}, {'grammar', 'sentence'})
        for material in materials:
            notice = material['source']['notice']
            self.assertIn(license_text, notice)
            self.assertIn('Copyright (c) 2026 Stefanus Ndaru Wedhatama', notice)
            self.assertIn('Permission is hereby granted, free of charge', notice)
            self.assertIn(grammar_statement, notice)
            self.assertIn(COMMIT, notice)
            self.assertIn(SNAPSHOT, notice)
            self.assertIn('https://github.com/stndaru/nihongo-mono', notice)

    def test_duplicate_identity_fails(self):
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            build_bundle([lesson(), lesson()])

    def test_invalid_level_fails(self):
        for level in [0, 6, True, '5']:
            with self.assertRaisesRegex(ValueError, 'level'):
                build_bundle([lesson(level=level)])

    def test_blank_required_fails(self):
        for field in ['slug', 'title', 'meaning', 'summary']:
            row = lesson(); row[field] = ' '
            with self.assertRaises(ValueError): build_bundle([row])
        row = lesson(); row['examples'][0]['en'] = ''
        with self.assertRaises(ValueError): build_bundle([row])

    def test_invalid_annotation_fails(self):
        for markup in ['｜見[み', '｜聞[み]る。', '｜見[]る。']:
            with self.assertRaises(ValueError): annotation_reading('見る。', markup)

    def test_deterministic_order_and_sentence_parents(self):
        a, b = lesson('a'), lesson('b', 4)
        first = build_bundle([a, b]); second = build_bundle([b, a])
        self.assertEqual(first, second)
        sentences = [x for x in first['materials'] if x['kind'] == 'sentence']
        self.assertEqual(len(sentences), 1)
        self.assertEqual(sentences[0]['source']['parentIDs'], ['grammar:a', 'grammar:b'])

    def test_reading_only_uses_supplied_markup(self):
        self.assertEqual(annotation_reading('見る。', '｜見[み]る。'), 'みる。')
        self.assertIsNone(annotation_reading('見る。', None))
        self.assertIsNone(annotation_reading('山を見る。', '山を｜見[み]る。'))

    def test_missing_reference_fails(self):
        row = lesson(); row['related'] = [dict(slug='missing', note='Related')]
        with self.assertRaisesRegex(ValueError, 'reference'): build_bundle([row])

if __name__ == '__main__': unittest.main()
