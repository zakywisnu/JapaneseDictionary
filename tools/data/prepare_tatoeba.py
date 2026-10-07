"""Build an offline N5 candidate set; no candidate is approved for app display."""
import argparse
import bz2
import csv
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

INDEX = re.compile(r'^([^()[\]{}~|]+)(?:\(([^)]+)\))?(?:\[(\d+)\])?(?:\{([^}]+)\})?(~)?(?:\|\d+)?$')
SOURCES = {
    'wwwjdic.csv': 'https://downloads.tatoeba.org/exports/wwwjdic.csv',
    'jpn_sentences_detailed.tsv.bz2': 'https://downloads.tatoeba.org/exports/per_language/jpn/jpn_sentences_detailed.tsv.bz2',
    'eng_sentences_detailed.tsv.bz2': 'https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences_detailed.tsv.bz2',
}


def matching_words(token, words):
    match = INDEX.fullmatch(token)
    if not match or not match[5]:
        return []
    head, reading = match[1], match[2]
    choices = words.get(head, [])
    if reading:
        choices = [w for w in choices if w['Furigana'] == reading]
    elif len({w['Furigana'] for w in choices}) > 1:
        return []
    return [(w, match[3], match[4] or head) for w in choices]


def load_metadata(path, needed):
    result = {}
    with bz2.open(path, 'rt', encoding='utf-8') as source:
        for line in source:
            row = line.rstrip('\n').split('\t')
            if len(row) == 6 and row[0] in needed:
                result[row[0]] = {'text': row[2], 'owner': None if row[3] == '\\N' else row[3], 'modified': row[5]}
    return result


def prepare(raw, vocab, output):
    with vocab.open(encoding='utf-8-sig', newline='') as source:
        n5 = [w for w in csv.DictReader(source) if w['JLPT Level'] == 'N5']
    words = defaultdict(list)
    for w in n5:
        words[w['Original']].append(w)
    candidates = defaultdict(dict)
    pairs = 0
    with (raw / 'wwwjdic.csv').open(encoding='utf-8') as source:
        for line in source:
            row = line.rstrip('\n').split('\t')
            if len(row) != 5:
                raise ValueError('Expected five fields in wwwjdic.csv')
            pairs += 1
            jp_id, en_id, japanese, english, indices = row
            if len(japanese) > 80 or len(english) > 200:
                continue
            for token in indices.split():
                for w, sense, surface in matching_words(token, words):
                    key = json.dumps([w['Original'], w['Furigana'], w['JLPT Level']], ensure_ascii=False, separators=(',', ':'))
                    candidates[key][(jp_id, en_id)] = {
                        'word': {'headword': w['Original'], 'reading': w['Furigana'], 'level': w['JLPT Level']},
                        'japaneseId': jp_id, 'englishId': en_id,
                        'japanese': japanese, 'english': english,
                        'indexedSense': sense, 'surface': surface,
                        'checkedUsage': True, 'reviewStatus': 'pending',
                        'sentenceReading': None,
                        'license': 'CC BY 2.0 FR',
                        'japaneseSource': f'https://tatoeba.org/en/sentences/show/{jp_id}',
                        'englishSource': f'https://tatoeba.org/en/sentences/show/{en_id}',
                    }
    selected = [c for key in sorted(candidates) for c in sorted(candidates[key].values(), key=lambda c: (len(c['japanese']), int(c['japaneseId']), int(c['englishId'])))[:3]]
    jp = load_metadata(raw / 'jpn_sentences_detailed.tsv.bz2', {c['japaneseId'] for c in selected})
    en = load_metadata(raw / 'eng_sentences_detailed.tsv.bz2', {c['englishId'] for c in selected})
    valid = []
    for c in selected:
        j, e = jp.get(c['japaneseId']), en.get(c['englishId'])
        if not j or not e or j['text'] != c['japanese'] or e['text'] != c['english']:
            continue
        c['japaneseOwner'], c['englishOwner'] = j['owner'], e['owner']
        valid.append(c)
    covered = {(c['word']['headword'], c['word']['reading']) for c in valid}
    all_words = {(w['Original'], w['Furigana']) for w in n5}
    report = {
        'downloadedOn': '2026-10-06', 'sourcePairs': pairs,
        'n5Words': len(all_words), 'matchedN5Words': len(covered),
        'candidates': len(valid), 'approvedExamples': 0,
        'missingN5Words': [{'headword': h, 'reading': r} for h, r in sorted(all_words - covered)],
        'sources': [{'file': name, 'url': url, 'bytes': (raw / name).stat().st_size, 'sha256': hashlib.sha256((raw / name).read_bytes()).hexdigest()} for name, url in SOURCES.items()],
        'vocabularySha256': hashlib.sha256(vocab.read_bytes()).hexdigest(),
    }
    output.mkdir(parents=True, exist_ok=True)
    for name, value in [('n5-candidates.json', valid), ('coverage.json', report)]:
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k not in ('missingN5Words', 'sources')}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--vocab', type=Path, default=Path('Frameworks/DataKit/Resources/jlpt_vocab.csv'))
    parser.add_argument('--output', type=Path, default=Path('data/tatoeba'))
    args = parser.parse_args()
    prepare(args.raw, args.vocab, args.output)
