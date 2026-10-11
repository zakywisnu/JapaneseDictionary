"""Validate the byte-bound model-check evidence and deterministically export practice.

This gate establishes model/rule checking, not independent human language review.
"""
import argparse
import copy
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAFT = ROOT / 'data/practice/authored-drafts.json'
EVIDENCE = ROOT / 'data/practice/validation-evidence.json'
OUTPUT = ROOT / 'Frameworks/DataKit/Resources/applied-practice.json'

def digest(value):
    # JSONEncoder sortedKeys escapes slash; UTF-8 Japanese remains unescaped.
    data = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).replace('/', '\\/')
    return hashlib.sha256(data.encode()).hexdigest()

def require(condition, message):
    if not condition:
        raise ValueError(message)

def expected_kana(lemma, reading, class_id, form):
    if class_id == 'godan':
        stem, end = reading[:-1], reading[-1]
        i = dict(zip('うつるむぶぬくぐす', 'いちりみびにきぎし'))[end]
        a = dict(zip('うつるむぶぬくぐす', 'わたらまばなかがさ'))[end]
        te = 'って' if end in 'うつる' else 'んで' if end in 'むぶぬ' else {'く':'いて','ぐ':'いで','す':'して'}[end]
        if lemma == '行く': te = 'って'
        past = te[:-1] + ('だ' if te.endswith('で') else 'た')
        return {'polite':stem+i+'ます','politeNegative':stem+i+'ません','plainNegative':'ない' if lemma == 'ある' else stem+a+'ない','plainPast':stem+past,'te':stem+te}[form]
    if class_id == 'ichidan':
        return reading[:-1] + {'polite':'ます','politeNegative':'ません','plainNegative':'ない','plainPast':'た','te':'て'}[form]
    if class_id == 'irregular':
        return ({'polite':'します','politeNegative':'しません','plainNegative':'しない','plainPast':'した','te':'して'} if lemma == 'する' else {'polite':'きます','politeNegative':'きません','plainNegative':'こない','plainPast':'きた','te':'きて'})[form]
    if class_id == 'iAdjective':
        stem = 'よ' if lemma == 'いい' else reading[:-1]
        return reading+'です' if form == 'polite' else stem + {'plainNegative':'くない','plainPast':'かった','connective':'くて'}[form]
    if class_id == 'naAdjective':
        return reading + {'polite':'です','plainNegative':'ではない','plainPast':'だった','connective':'で'}[form]
    raise ValueError('unknown lemma class')

def validate(draft, evidence):
    require(draft.get('formatVersion') == 1, 'unsupported format')
    require(evidence.get('draftHash') == digest(draft), 'stale draft review hash')
    require(evidence.get('reviewer') and evidence.get('date') and evidence.get('method') == 'model-and-rule-check', 'missing model review')
    require(evidence.get('independentLanguageReview') == 'pending', 'do not imply independent review')
    seen = set()
    question_ids = set()
    for activity in draft['activities']:
        require(activity['id'] not in seen, 'duplicate activity ID')
        seen.add(activity['id'])
        for question in activity['questions']:
            require(question['id'] not in question_ids, 'duplicate question ID')
            question_ids.add(question['id'])
            require(question['revision'] > 0, 'bad revision')
            meta = question['metadata']
            require(meta['activityKind'] == activity['kind'] == question['questionKind'], 'kind mismatch')
            require(meta.get('source') and question.get('explanation'), 'missing provenance or explanation')
            if activity['kind'] == 'conjugation':
                require(question['acceptedAnswers'] and all(question['acceptedAnswers']), 'missing forms')
                require(expected_kana(meta['stimulus'], meta['suppliedReading'], activity['classID'], activity['formID']) in question['acceptedAnswers'], 'incorrect explicit form or exception')
                if meta['stimulus'] == '行く' and activity['formID'] == 'te':
                    require(question['acceptedAnswers'] == ['行って', 'いって'], 'incorrect 行く exception')
                if meta['stimulus'] == 'ある' and activity['formID'] == 'plainNegative':
                    require(question['acceptedAnswers'] == ['ない'], 'incorrect ある negative')
                if meta['stimulus'] == 'いい' and activity['formID'] == 'plainPast':
                    require(question['acceptedAnswers'] == ['よかった'], 'incorrect いい exception')
            elif activity['kind'] == 'sentenceOrder':
                ids = [t['id'] for t in meta['tokens']]
                require(len(ids) == len(set(ids)) and all(t['text'] for t in meta['tokens']), 'duplicate or empty token')
                require(meta['acceptedOrders'], 'missing accepted orders')
                for order in meta['acceptedOrders']:
                    require(len(order) == len(ids) and set(order) == set(ids), 'invalid accepted token order')
            elif activity['kind'] == 'listeningComprehension':
                choices = question['choices']
                require(len(choices) >= 2 and len(set(choices)) == len(choices), 'ambiguous choices')
                require(0 <= question['correctIndex'] < len(choices), 'bad correct choice')
                require(meta.get('suppliedReading') and meta.get('translation'), 'missing listening reading')
            else:
                raise ValueError('unsupported activity')
    with (ROOT / 'Frameworks/DataKit/Resources/jlpt_vocab.csv').open() as stream:
        vocabulary = {(r['Original'], r['Furigana'], r['JLPT Level'], r['English']) for r in csv.DictReader(stream)}
    context_ids = set()
    for item in draft['contexts']:
        require(item['stableID'] not in context_ids, 'duplicate context ID')
        context_ids.add(item['stableID'])
        require(item['verifiedMeanings'] and item['word']['reading'], 'missing exact word evidence')
        for meaning in item['verifiedMeanings']:
            require((item['word']['headword'], item['word']['reading'], item['word']['level'], meaning) in vocabulary, 'selected meaning differs from bundled vocabulary')
        require(item['cloze'].count('＿＿') == 1 and item['word']['headword'] not in item['cloze'], 'answer-bearing cloze')
        require(item['japanese'].replace(item['word']['headword'], '＿＿', 1) == item['cloze'], 'cloze mismatch')
    return draft

def export(draft, evidence):
    validate(draft, evidence)
    result = copy.deepcopy(draft)
    def review(value):
        return dict(reviewer=evidence['reviewer'], date=evidence['date'], method=evidence['method'], contentHash=digest(value))
    for activity in result['activities']:
        for question in activity['questions']:
            question['metadata']['review'] = review(question)
            question['fingerprint'] = digest(question)
    for item in result['contexts']:
        item['review'] = review(item)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = export(json.loads(DRAFT.read_text()), json.loads(EVIDENCE.read_text()))
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        require(OUTPUT.read_text() == encoded, 'bundle is stale; regenerate')
    else:
        OUTPUT.write_text(encoded)
    print(f"Validated {len(result['activities'])} activities and {len(result['contexts'])} contexts; independent language review pending.")

if __name__ == '__main__':
    main()
