"""Normalize the pinned MIT community grammar snapshot without altering raw inputs."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMIT = 'ec0ba4a0ce1611c568b0e4f8a223eb8029249a25'
SNAPSHOT = '2026-10-08'
BASE = f'https://github.com/stndaru/nihongo-mono/blob/{COMMIT}/'
NOTICE = 'Community material from nihongo mono; MIT licensed. Not official JLPT coverage or human-verified content.'

RAW = ROOT / 'data/lessons/raw'
LICENSE_TEXT = (RAW / 'LICENSE').read_text()
DATA_LICENSE_TEXT = (RAW / 'LICENSE-DATA.md').read_text()
GRAMMAR_LICENSE = next(line for line in DATA_LICENSE_TEXT.splitlines()
                       if line.startswith('| `src/data/grammar/`'))
MATERIAL_NOTICE = (NOTICE + '\nProvider: nihongo mono\nRepository: https://github.com/stndaru/nihongo-mono'
                   + '\nPinned commit: ' + COMMIT + '\nSnapshot: ' + SNAPSHOT
                   + '\n\nGrammar data license statement:\n' + GRAMMAR_LICENSE + '\n\n' + LICENSE_TEXT)


def text(value, label):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f'{label}: blank or invalid required text')
    return value


def digest(value):
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


def annotation_reading(japanese, markup):
    if markup is None: return None
    text(markup, 'annotation')
    reconstructed, reading, offset = '', '', 0
    for match in re.finditer(r'｜([^\[\]｜]+)\[([^\[\]｜]+)\]', markup):
        plain = markup[offset:match.start()]
        if any(c in plain for c in '｜[]'): raise ValueError('invalid annotation markup')
        reconstructed += plain + match[1]
        reading += plain + match[2]
        offset = match.end()
    suffix = markup[offset:]
    if any(c in suffix for c in '｜[]'): raise ValueError('invalid annotation markup')
    reconstructed += suffix; reading += suffix
    if reconstructed != japanese: raise ValueError('annotation does not reconstruct Japanese')
    # Remaining kanji or non-kana lexical text cannot be pronounced without guessing.
    if not re.fullmatch(r'[\u3040-\u30ff\s。、！？!?…「」『』（）()・ー〜～,.]+', reading): return None
    return reading


def source(source_id, content, parents=None):
    return dict(provider='nihongo mono', sourceID=source_id, sourceURL=BASE+'src/data/grammar/',
                license='MIT', notice=MATERIAL_NOTICE, snapshot=SNAPSHOT, textSHA256=digest(content), parentIDs=parents or [])


def build_bundle(rows):
    slugs = set(); sentences = {}; materials = []
    for row in rows:
        slug = text(row['slug'], 'slug')
        if slug in slugs: raise ValueError(f'duplicate identity: {slug}')
        slugs.add(slug)
        if type(row['jlpt']) is not int or row['jlpt'] not in range(1, 6): raise ValueError(f'{slug}: invalid level')
    for row in sorted(rows, key=lambda r:r['slug']):
        slug = row['slug']; sid = 'grammar:'+slug
        for field in ['title', 'meaning', 'summary']: text(row[field], f'{slug}.{field}')
        for field in ['structure', 'pitfalls', 'sources']:
            if not isinstance(row[field], list): raise ValueError(f'{slug}.{field}: invalid list')
            for value in row[field]: text(value, f'{slug}.{field}')
        references = []
        for field in ['synonyms', 'antonyms', 'related']:
            for ref in row[field]:
                if ref['slug'] not in slugs: raise ValueError(f'{slug}: missing reference {ref["slug"]}')
                text(ref['note'], f'{slug}.reference note')
                references.append('grammar:'+ref['slug'])
        if not row['examples']: raise ValueError(f'{slug}: missing examples')
        examples = []
        for example in row['examples']:
            ja = text(example['ja'], slug+'.example Japanese'); en = text(example['en'], slug+'.example English')
            reading = annotation_reading(ja, example.get('f'))
            examples.append(dict(japanese=ja, english=en, reading=reading))
            pair = json.dumps([ja, en], ensure_ascii=False, separators=(',', ':'))
            sentence_id = 'sentence:'+digest(pair)
            record = sentences.setdefault(sentence_id, dict(ja=ja,en=en,readings=set(),parents=set(),levels=set(),annotations=set(),pair=pair))
            record['parents'].add(sid); record['levels'].add(row['jlpt'])
            if reading: record['readings'].add(reading)
            if example.get('f'): record['annotations'].add(example['f'])
        notes = list(row['pitfalls'])
        if row.get('levelNote'): notes.append(text(row['levelNote'], slug+'.levelNote'))
        notes += [f'{field.title()}: {ref["slug"]} — {ref["note"]}' for field in ['synonyms','antonyms','related'] for ref in row[field]]
        notes.append('Source references: '+', '.join(row['sources']))
        material = dict(id=sid,kind='grammar',prompt=row['title'],answer=row['meaning']+'\n\n'+row['summary'],reading=(row.get('kana') if row.get('kana') and re.fullmatch(r'[\u3040-\u30ffー]+', row['kana']) else None),level=f'N{row["jlpt"]}',notes='\n\n'.join(notes),category=None,structures=row['structure'],examples=examples,relatedSourceIDs=sorted(set(references)),source=source(sid,json.dumps(row,ensure_ascii=False,sort_keys=True,separators=(',',':'))),createdAt=SNAPSHOT+'T00:00:00Z',updatedAt=SNAPSHOT+'T00:00:00Z')
        materials.append(material)
    for sid, record in sorted(sentences.items()):
        levels = sorted(record['levels'], reverse=True)
        notes = 'From '+', '.join(f'N{n}' for n in levels)+' lessons; sentence level is lesson context.'
        notes += '\n\nSupplied annotations:\n'+'\n'.join(sorted(record['annotations']))
        materials.append(dict(id=sid,kind='sentence',prompt=record['ja'],answer=record['en'],reading=next(iter(record['readings'])) if len(record['readings'])==1 else None,level=f'N{levels[0]}',notes=notes,category=None,structures=[],examples=[],relatedSourceIDs=sorted(record['parents']),source=source(sid,record['pair'],sorted(record['parents'])),createdAt=SNAPSHOT+'T00:00:00Z',updatedAt=SNAPSHOT+'T00:00:00Z'))
    return dict(version=1,snapshot=SNAPSHOT,commit=COMMIT,materials=sorted(materials,key=lambda m:m['id']))


def main():
    raw = ROOT/'data/lessons/raw'; rows = []; files = []
    for path in sorted(raw.iterdir()):
        data = path.read_bytes(); upstream = 'src/data/grammar/'+path.name if path.suffix=='.json' else path.name
        files.append(dict(file='raw/'+path.name,url=BASE+upstream,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
        if path.suffix=='.json':
            records=json.loads(data)
            if any(r['jlpt'] != int(path.stem[1:]) for r in records): raise ValueError(f'{path.name}: level does not match file')
            rows.extend(records)
    bundle = build_bundle(rows)
    (ROOT/'data/lessons/manifest.json').write_text(json.dumps(dict(snapshot=SNAPSHOT,commit=COMMIT,repository='https://github.com/stndaru/nihongo-mono',files=files),indent=2)+'\n')
    (ROOT/'Frameworks/DataKit/Resources/lessons.json').write_text(json.dumps(bundle,ensure_ascii=False,indent=2)+'\n')
    notice=MATERIAL_NOTICE+'\n'+DATA_LICENSE_TEXT
    (ROOT/'Frameworks/DataKit/Resources/lesson-attribution.txt').write_text(notice)
    print(f'{len(rows)} grammar lessons; {len(bundle["materials"])-len(rows)} unique sentences')

if __name__=='__main__': main()
