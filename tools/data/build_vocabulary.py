#!/usr/bin/env python3
"""Build the offline catalog from pinned JMdict and reviewed community lists."""
import argparse
from collections import Counter, defaultdict
import csv
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import unicodedata
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1']
DATE = '2026-10-07'
STOPWORDS = set('a an the to of in on at for and or with by as be is it that this one something someone do get have make take etc'.split())


class Dictionary(dict):
    def __init__(self):
        super().__init__()
        self.pairs = defaultdict(set)


def texts(element, path):
    return [node.text or '' for node in element.findall(path)]


COMMON_PRIORITIES = {'news1', 'ichi1', 'spec1', 'spec2', 'gai1'}


def priority_notes(markers):
    labels = {
        'news1':'Newspaper priority: higher group', 'news2':'Newspaper priority: lower group',
        'ichi1':'Common-word dictionary priority: higher group', 'ichi2':'Common-word dictionary priority: lower group',
        'spec1':'JMdict special priority: higher group', 'spec2':'JMdict special priority: lower group',
        'gai1':'Loanword dictionary priority: higher group', 'gai2':'Loanword dictionary priority: lower group'
    }
    return [labels.get(marker, 'Newspaper frequency group: ' + marker[2:] if marker.startswith('nf') else 'Dictionary priority: ' + marker) for marker in markers]


def parse_dictionary(stream):
    dictionary = Dictionary()
    for _, node in ET.iterparse(stream, events=('end',)):
        if node.tag != 'entry':
            continue
        entry_id = int(node.findtext('ent_seq'))
        forms = [dict(text=k.findtext('keb'), notes=texts(k, 'ke_inf') + priority_notes(texts(k, 'ke_pri')), common=bool(set(texts(k, 'ke_pri')) & COMMON_PRIORITIES)) for k in node.findall('k_ele')]
        readings = [dict(text=r.findtext('reb'), spellings=texts(r, 're_restr'), notes=texts(r, 're_inf') + priority_notes(texts(r, 're_pri')), common=bool(set(texts(r, 're_pri')) & COMMON_PRIORITIES), kanaOnly=r.find('re_nokanji') is not None) for r in node.findall('r_ele')]
        senses = []
        inherited_pos = []
        for s in node.findall('sense'):
            inherited_pos = texts(s, 'pos') or inherited_pos
            meanings = [g.text or '' for g in s.findall('gloss') if g.get('{http://www.w3.org/XML/1998/namespace}lang', 'eng') == 'eng']
            notes = texts(s, 's_inf')
            for gloss in s.findall('gloss'):
                for attribute in ('g_type', 'g_gend'):
                    if gloss.get(attribute):
                        notes.append(('Gloss type: ' if attribute == 'g_type' else 'Grammatical gender: ') + gloss.get(attribute) + ' (' + (gloss.text or '') + ')')
            notes += ['See also: ' + x for x in texts(s, 'xref')]
            notes += ['Antonym: ' + x for x in texts(s, 'ant')]
            for loan in s.findall('lsource'):
                language = loan.get('{http://www.w3.org/XML/1998/namespace}lang', 'eng')
                notes.append('Source language: ' + language + (': ' + loan.text if loan.text else ''))
            senses.append(dict(meanings=meanings, pos=list(inherited_pos), labels=texts(s, 'misc') + texts(s, 'field') + texts(s, 'dial'), notes=notes, spellings=texts(s, 'stagk'), readings=texts(s, 'stagr')))
        dictionary[entry_id] = dict(jmdictID=entry_id, forms=forms, readings=readings, senses=senses)
        for r in readings:
            words = r['spellings'] or [k['text'] for k in forms]
            if not r['kanaOnly']:
                for word in words:
                    dictionary.pairs[(word, r['text'])].add(entry_id)
            dictionary.pairs[(r['text'], r['text'])].add(entry_id)
        node.clear()
    return dictionary


def applicable_senses(entry, word, reading):
    reading_record = next((r for r in entry['readings'] if r['text'] == reading), None)
    if reading_record is None:
        return []
    eligible = reading_record['spellings'] or [k['text'] for k in entry['forms']]
    if reading_record['kanaOnly']:
        eligible = []
    if word != reading and word not in eligible:
        return []
    selected_forms = eligible if word == reading else [word]
    return [s for s in entry['senses'] if (not s['readings'] or reading in s['readings']) and (not s['spellings'] or any(k in s['spellings'] for k in selected_forms))]


def normalize(text):
    return unicodedata.normalize('NFC', text.strip())


def gloss_tokens(text):
    return set(re.findall(r'[a-z0-9]+', text.lower())) - STOPWORDS


def meaning_score(meanings, senses):
    intended = gloss_tokens(' '.join(meanings))
    if not intended:
        return 0
    scores = []
    for s in senses:
        for gloss in s['meanings']:
            actual = gloss_tokens(gloss)
            shared = intended & actual
            scores.append(len(shared) / len(intended) if actual else 0)
    return max(scores, default=0)


def primary_headword(entry, sense, reading):
    reading_record = next(r for r in entry['readings'] if r['text'] == reading)
    if reading_record['kanaOnly'] or 'word usually written using kana alone' in sense['labels']:
        return reading
    forms = [form for form in entry['forms'] if (not reading_record['spellings'] or form['text'] in reading_record['spellings']) and (not sense['spellings'] or form['text'] in sense['spellings'])]
    for note in sense['notes']:
        if note.startswith('esp. '):
            preferred = next((form['text'] for form in forms if form['text'] in note[5:]), None)
            if preferred:
                return preferred
    ordinary = [form for form in forms if 'search-only kanji form' not in form['notes']]
    return (ordinary or forms)[0]['text'] if ordinary else reading


def resolve(candidate, dictionary, overrides=()):
    word, reading = candidate['word'], candidate['reading']
    override = next((o for o in overrides if all(candidate[k] == o[k] for k in ('source', 'word', 'reading'))), None)
    if override:
        if override.get('exclude'):
            return None, override['reason']
        entry = dictionary[override['jmdictID']]
        word, reading = override.get('headword', word), override.get('newReading', reading)
        senses = applicable_senses(entry, word, reading)
        if not senses:
            raise ValueError('Override has incompatible dictionary pair: ' + str(override))
        decision = 'explicit override: ' + override['reason']
    else:
        ids = sorted(dictionary.pairs.get((word, reading), ()))
        ranked = []
        for entry_id in ids:
            entry = dictionary[entry_id]
            senses = applicable_senses(entry, word, reading)
            score = meaning_score(candidate['meanings'], senses)
            if senses and score > 0:
                ranked.append((score, entry_id, senses))
        ranked.sort(reverse=True, key=lambda value: value[0])
        if not ranked:
            return None, 'no compatible spelling/reading with matching intended English sense'
        if len(ranked) != 1:
            return None, 'ambiguous intended sense among JMdict IDs: ' + ', '.join(str(r[1]) for r in ranked)
        chosen = ranked[0]
        decision = 'unique dictionary entry with intended-sense evidence'
        entry = dictionary[chosen[1]]
        senses = chosen[2]
    if override and 'senseIndex' in override:
        sense_index = override['senseIndex']
        selected = entry['senses'][sense_index]
        if selected not in senses:
            raise ValueError('Override selects an incompatible sense: ' + str(override))
    else:
        selected = max(senses, key=lambda sense: meaning_score(candidate['meanings'], [sense]))
        sense_index = entry['senses'].index(selected)
    primary = selected['meanings']
    if not primary:
        return None, 'no applicable English dictionary gloss'
    word = primary_headword(entry, selected, reading)
    identity = f"jmdict:{entry['jmdictID']}:{reading}:{word}:s{sense_index}"
    resolved = dict(id=identity, jmdictID=entry['jmdictID'], headword=word, reading=reading, level=override.get('level', candidate['level']) if override else candidate['level'], studyMeanings=primary, forms=entry['forms'], readings=entry['readings'], senses=entry['senses'])
    return resolved, decision


def build_catalog(dictionary, legacy, community, overrides=()):
    entries, provenance, exclusions = {}, defaultdict(list), []
    legacy_map = []
    ordered_legacy = sorted(legacy, key=lambda r: LEVELS.index(r['level']))
    for source_rows in (community, ordered_legacy):
        for index, candidate in enumerate(source_rows):
            resolved, decision = resolve(candidate, dictionary, overrides)
            if source_rows is ordered_legacy:
                legacy_map.append(resolved['id'] if resolved else None)
            if resolved is None:
                exclusions.append(dict(source=candidate['source'], sourceIndex=index, word=candidate['word'], reading=candidate['reading'], meanings=candidate['meanings'], level=candidate['level'], reason=decision))
                continue
            identity = resolved['id']
            provenance[identity].append(dict(source=candidate['source'], sourceIndex=index, word=candidate['word'], reading=candidate['reading'], level=candidate['level'], decision=decision))
            previous = entries.get(identity)
            if previous is None or decision.startswith('explicit override:'):
                entries[identity] = resolved
            elif candidate['source'] == 'open' and LEVELS.index(resolved['level']) < LEVELS.index(previous['level']):
                entries[identity] = resolved
    ordered_entries = sorted(entries.values(), key=lambda e: (LEVELS.index(e['level']), e['reading'], e['headword'], e['jmdictID']))
    catalog = dict(version=2, created=DATE, jmdictCreated=DATE, entries=ordered_entries, legacyMap=legacy_map)
    report = dict(countsByLevel=dict(Counter(e['level'] for e in ordered_entries)), entries=len(ordered_entries), legacySlots=len(legacy_map), mappedLegacySlots=sum(x is not None for x in legacy_map), retiredLegacySlots=sum(x is None for x in legacy_map), sourceCandidates=dict(legacy=len(legacy), open=len(community)), exclusions=exclusions, provenance=dict(sorted(provenance.items())))
    return catalog, report


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshots', type=Path, default=ROOT / 'data/vocabulary/raw-snapshots')
    parser.add_argument('--archive-from', type=Path, help='Copy downloaded sources into ignored local snapshots')
    args = parser.parse_args()
    snapshots = args.snapshots
    source_names = ['JMdict_e.gz', 'n1.json', 'n2.json', 'n3.json', 'n4.json', 'n5.json', 'NOTICE.md', 'meta.json']
    snapshots.mkdir(parents=True, exist_ok=True)
    if args.archive_from:
        for name in source_names:
            shutil.copyfile(args.archive_from / name, snapshots / name)
    hashes = {name: hashlib.sha256((snapshots / name).read_bytes()).hexdigest() for name in source_names}
    legacy_path = ROOT / 'Frameworks/DataKit/Resources/jlpt_vocab.csv'
    hashes['jlpt_vocab.csv'] = hashlib.sha256(legacy_path.read_bytes()).hexdigest()
    pin_path = ROOT / 'data/vocabulary/sources.json'
    if pin_path.exists():
        pinned = json.loads(pin_path.read_text())['sha256']
        if pinned != hashes:
            raise ValueError('Source snapshot hashes differ from pinned sources.json')
    else:
        dump(pin_path, dict(created=DATE, openJLPTCommit='0d1d3410bec90bd4098a7c72de820543cb4f707c', jmdictCreated=DATE, sha256=hashes))
    with gzip.open(snapshots / 'JMdict_e.gz', 'rb') as stream:
        dictionary = parse_dictionary(stream)
    with legacy_path.open() as stream:
        legacy = [dict(word=normalize(r['Original']), reading=normalize(r['Furigana']), meanings=[r['English']], level=r['JLPT Level'], source='legacy', upstream=None) for r in csv.DictReader(stream)]
    community = []
    for level in LEVELS:
        for r in json.loads((snapshots / (level.lower() + '.json')).read_text()):
            community.append(dict(word=normalize(r['word']), reading=normalize(r['reading']), meanings=r['meanings'], level=level, source='open', upstream=r.get('jmdict_id')))
    overrides = json.loads((ROOT / 'data/vocabulary/overrides.json').read_text())
    catalog, report = build_catalog(dictionary, legacy, community, overrides)
    output = ROOT / 'Frameworks/DataKit/Resources/vocabulary-v2.json'
    dump(output, catalog)
    report['catalogSHA256'] = hashlib.sha256(output.read_bytes()).hexdigest()
    report['validation'] = dict(uniqueIdentities=len(set(e['id'] for e in catalog['entries'])) == len(catalog['entries']), everyLegacyTargetExists=all(x is None or x in report['provenance'] for x in catalog['legacyMap']), importedExamples=0)
    dump(ROOT / 'data/vocabulary/report.json', report)
    attribution = (ROOT / 'data/vocabulary/attribution-header.txt').read_text() + (ROOT / 'data/vocabulary/LICENSE-CC-BY-SA-4.0.txt').read_text()
    (ROOT / 'Frameworks/DataKit/Resources/vocabulary-attribution.txt').write_text(attribution, encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('entries', 'countsByLevel', 'mappedLegacySlots', 'retiredLegacySlots', 'catalogSHA256')}, ensure_ascii=False))

if __name__ == '__main__':
    main()
