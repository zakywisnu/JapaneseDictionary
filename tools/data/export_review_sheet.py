"""Export pending candidates with catalog glosses for a fluent human reviewer."""
import argparse
import csv
import io
import json
from pathlib import Path

from build_approved_examples import text_hash, word_key

FIELDS = ['headword', 'reading', 'level', 'csvGloss', 'japaneseId', 'englishId',
          'japanese', 'english', 'japaneseSha256', 'englishSha256', 'status',
          'reviewer', 'reviewedOn', 'verifiedSense', 'reviewedReading', 'notes']


def review_sheet(candidates, vocabulary):
    glosses = {}
    for row in vocabulary:
        key = (row['Original'], row['Furigana'], row['JLPT Level'])
        glosses.setdefault(key, []).append(row['English'])
    output = io.StringIO(newline='')
    writer = csv.DictWriter(output, fieldnames=FIELDS, lineterminator='\n')
    writer.writeheader()
    for candidate in sorted(candidates, key=lambda c: (word_key(c), int(c['japaneseId']), int(c['englishId']))):
        key = word_key(candidate)
        if key not in glosses:
            raise ValueError('Candidate word missing from exact vocabulary key')
        writer.writerow({**candidate['word'], 'csvGloss': ' | '.join(dict.fromkeys(glosses[key])),
                         **{field: candidate[field] for field in ('japaneseId', 'englishId', 'japanese', 'english')},
                         'japaneseSha256': text_hash(candidate['japanese']),
                         'englishSha256': text_hash(candidate['english']), 'status': 'pending',
                         'reviewer': '', 'reviewedOn': '', 'verifiedSense': '', 'reviewedReading': '', 'notes': ''})
    return output.getvalue()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--candidates', type=Path, default=Path('data/tatoeba/n5-candidates.json'))
    parser.add_argument('--vocab', type=Path, default=Path('Frameworks/DataKit/Resources/jlpt_vocab.csv'))
    parser.add_argument('--output', type=Path, default=Path('data/tatoeba/n5-review-sheet.csv'))
    args = parser.parse_args()
    candidates = json.loads(args.candidates.read_text(encoding='utf-8'))
    with args.vocab.open(encoding='utf-8-sig', newline='') as source:
        vocabulary = list(csv.DictReader(source))
    args.output.write_text(review_sheet(candidates, vocabulary), encoding='utf-8')
    print(f'Exported {len(candidates)} pending candidate rows to {args.output}')
