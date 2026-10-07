"""Join human decisions to exact source text; never infer approval from matching."""
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path


def text_hash(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def required(record, field):
    value = record.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f'Missing or invalid {field}')
    return value


def word_key(record):
    word = record.get('word')
    if not isinstance(word, dict):
        raise ValueError('Missing word key')
    key = tuple(required(word, field) for field in ('headword', 'reading', 'level'))
    if key[2] != 'N5':
        raise ValueError('Only N5 examples are supported')
    return key


def record_key(record):
    ids = tuple(required(record, field) for field in ('japaneseId', 'englishId'))
    if any(not value.isdecimal() or int(value) <= 0 for value in ids):
        raise ValueError('Invalid sentence source IDs')
    return word_key(record) + ids


def build(candidates, ledger, snapshot):
    if ledger.get('formatVersion') != 1 or not isinstance(ledger.get('reviews'), list):
        raise ValueError('Unsupported approval ledger')
    indexed = {}
    for candidate in candidates:
        key = record_key(candidate)
        if key in indexed:
            raise ValueError('Duplicate candidate')
        indexed[key] = candidate
    approved = []
    seen = set()
    for review in ledger['reviews']:
        key = record_key(review)
        if key in seen:
            raise ValueError('Duplicate review decision')
        seen.add(key)
        status = review.get('status')
        if status not in ('pending', 'rejected', 'approved'):
            raise ValueError('Invalid review status')
        if status != 'approved':
            continue
        candidate = indexed.get(key)
        if candidate is None:
            raise ValueError('Approved candidate absent from snapshot')
        for language in ('japanese', 'english'):
            text = required(candidate, language)
            if required(review, language + 'Sha256') != text_hash(text):
                raise ValueError(f'{language} source text hash changed; new human review required')
            expected_url = f'https://tatoeba.org/en/sentences/show/{candidate[language + "Id"]}'
            if required(candidate, language + 'Source') != expected_url:
                raise ValueError('Source URL does not match sentence ID')
            owner_field = language + 'Owner'
            if owner_field not in candidate or (candidate[owner_field] is not None and not isinstance(candidate[owner_field], str)):
                raise ValueError(f'Missing or invalid {owner_field}; explicit null is allowed')
        license_name = required(candidate, 'license')
        if license_name not in ('CC BY 2.0 FR', 'CC0'):
            raise ValueError('Unsupported source license')
        reviewer = required(review, 'reviewer')
        reviewed_on = required(review, 'reviewedOn')
        if date.fromisoformat(reviewed_on).isoformat() != reviewed_on:
            raise ValueError('Review date must be YYYY-MM-DD')
        sense = required(review, 'verifiedSense')
        reading = review.get('reviewedReading')
        if reading is not None and (not isinstance(reading, str) or not reading.strip()):
            raise ValueError('Invalid reviewedReading')
        approved.append({
            'word': dict(candidate['word']),
            **{field: candidate[field] for field in ('japaneseId', 'englishId', 'japanese', 'english',
                                                     'japaneseSource', 'englishSource', 'japaneseOwner', 'englishOwner', 'license')},
            'sentenceReading': reading,
            'review': {'reviewer': reviewer, 'reviewedOn': reviewed_on, 'verifiedSense': sense,
                       'japaneseSha256': review['japaneseSha256'], 'englishSha256': review['englishSha256'],
                       'changes': ['Verified reading added'] if reading is not None else []},
        })
    # Multiple human-approved candidates use the lowest source ID, independent of ledger order.
    chosen = {}
    for example in sorted(approved, key=lambda e: (word_key(e), int(e['japaneseId']), int(e['englishId']))):
        chosen.setdefault(word_key(example), example)
    return {'formatVersion': 1,
            'sourceSnapshot': {field: snapshot[field] for field in ('downloadedOn', 'sources', 'vocabularySha256')},
            'examples': list(chosen.values())}


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', type=Path, default=Path('data/tatoeba'))
    args = parser.parse_args()
    read = lambda name: json.loads((args.data / name).read_text(encoding='utf-8'))
    candidates, ledger, snapshot = read('n5-candidates.json'), read('approvals.json'), read('coverage.json')
    bundle = build(candidates, ledger, snapshot)
    report = {'candidateRecords': len(candidates), 'reviewDecisions': len(ledger['reviews']),
              'approvedWords': len(bundle['examples']), 'n5Words': snapshot['n5Words'],
              'publicationReady': bool(bundle['examples'])}
    write_json(args.data / 'approved-examples.json', bundle)
    write_json(args.data / 'approved-coverage.json', report)
    print(json.dumps(report))


if __name__ == '__main__':
    main()
