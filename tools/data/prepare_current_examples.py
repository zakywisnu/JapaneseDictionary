"""Bind immutable corpus candidates to explicit current catalog migration slots."""
import argparse
import copy
import csv
import hashlib
import json
from pathlib import Path

LEVELS = ('N5', 'N4', 'N3', 'N2', 'N1')
CONTEXT_FIELDS = ('id', 'headword', 'reading', 'level', 'studyMeanings')


def context_hash(word):
    payload = {key: word[key] for key in CONTEXT_FIELDS}
    return hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode('utf-8')).hexdigest()


def legacy_slots(rows, identities):
    rows = sorted(rows, key=lambda row: LEVELS.index(row['JLPT Level']))
    if len(rows) != len(identities):
        raise ValueError('Legacy slot count differs from current catalog mapping')
    return [(dict(headword=row['Original'], reading=row['Furigana'], level=row['JLPT Level']), identity)
            for row, identity in zip(rows, identities)]


def reconcile(candidates, catalog, legacy_map):
    entries = catalog['entries'] if isinstance(catalog, dict) else catalog
    indexed = {word['id']: (position, word) for position, word in enumerate(entries)}
    if len(indexed) != len(entries):
        raise ValueError('Duplicate catalog identity')
    mappings = {}
    for word, identity in legacy_map:
        key = tuple(word[field] for field in ('headword', 'reading', 'level'))
        mappings.setdefault(key, set()).add(identity)
    result = []
    for source in candidates:
        row = copy.deepcopy(source)
        key = tuple(row['word'][field] for field in ('headword', 'reading', 'level'))
        targets = mappings.get(key, set())
        cause = ('No explicit legacy mapping' if not targets else
                 'Multiple legacy sense identities' if len(targets) != 1 else
                 'Retired legacy mapping' if None in targets else
                 'Legacy target absent from current catalog' if next(iter(targets)) not in indexed else None)
        row.update(catalogID=None, selectedStudyMeanings=[], contextSha256=None,
                   catalogPosition=None, currentWord=None, senseNotes=[], reviewStatus='unresolved', unresolvedCause=cause)
        if cause is None:
            position, word = indexed[next(iter(targets))]
            if word['level'] != 'N5':
                row['unresolvedCause'] = 'Current catalog target is not N5'
            else:
                row.update(catalogID=word['id'], selectedStudyMeanings=copy.deepcopy(word['studyMeanings']),
                           contextSha256=context_hash(word), catalogPosition=position,
                           currentWord={field:copy.deepcopy(word[field]) for field in CONTEXT_FIELDS},
                           senseNotes=copy.deepcopy(word.get('senses', [])), reviewStatus='pending', unresolvedCause=None)
        result.append(row)
    return sorted(result, key=lambda row:(row['catalogPosition'] if row['catalogPosition'] is not None else len(entries),
                                          tuple(row['word'][field] for field in ('headword', 'reading', 'level')), int(row['japaneseId']), int(row['englishId'])))


def select_batch(rows, limit=30):
    chosen = {}
    for row in sorted(rows, key=lambda row:(row['catalogPosition'] if row['catalogPosition'] is not None else float('inf'), int(row['japaneseId']), int(row['englishId']))):
        if row['reviewStatus'] == 'pending':
            chosen.setdefault(row['catalogID'], row)
    return list(chosen.values())[:limit]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--catalog', type=Path, default=Path('Frameworks/DataKit/Resources/vocabulary-v2.json'))
    parser.add_argument('--legacy', type=Path, default=Path('Frameworks/DataKit/Resources/jlpt_vocab.csv'))
    parser.add_argument('--data', type=Path, default=Path('data/tatoeba'))
    args=parser.parse_args()
    catalog=json.loads(args.catalog.read_text())
    with args.legacy.open(encoding='utf-8-sig',newline='') as stream:
        mappings=legacy_slots(list(csv.DictReader(stream)),catalog['legacyMap'])
    rows=reconcile(json.loads((args.data/'n5-candidates.json').read_text()),catalog,mappings)
    batch=select_batch(rows)
    report=dict(formatVersion=2, catalogSha256=hashlib.sha256(args.catalog.read_bytes()).hexdigest(),
                candidateRecords=len(rows), mappedCandidates=sum(row['reviewStatus']=='pending' for row in rows),
                unresolvedCandidates=sum(row['reviewStatus']=='unresolved' for row in rows), batchIdentities=len(batch), candidates=rows)
    (args.data/'current-reconciliation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    from export_review_sheet import current_review_sheet
    (args.data/'current-n5-review-sheet.csv').write_text(current_review_sheet(batch),encoding='utf-8')
    print(json.dumps({key:value for key,value in report.items() if key!='candidates'}))

if __name__=='__main__': main()
