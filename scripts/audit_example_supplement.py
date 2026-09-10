#!/usr/bin/env python3
"""Extract example/pronunciation/definition candidates from every English Anki deck."""
from __future__ import annotations
import argparse, gzip, html, json, re, sqlite3, zipfile
from collections import Counter
from pathlib import Path

SEP='\x1f'
TAG_RE=re.compile(r'<[^>]+>')
WORD_RE=re.compile(r"[A-Za-z][A-Za-z'-]{1,}")

def clean(value):
    value=html.unescape(value or '').replace('<br />','\n').replace('<br/>','\n').replace('<br>','\n')
    value=TAG_RE.sub('',value).replace('\xa0',' ')
    return re.sub(r'\s+',' ',value).strip()

def first(fields,*names):
    for n in names:
        v=clean(fields.get(n,''))
        if v:return v
    return ''

def word(value):
    value=clean(value).lower().strip()
    return value if re.fullmatch(r'[a-z]+',value) else ''

def pron(value):
    value=clean(value)
    uk=us=''
    m=re.search(r'(?:英|UK|英式)[^\[]*\[([^\]]+)\]',value)
    n=re.search(r'(?:美|US|美式)[^\[]*\[([^\]]+)\]',value)
    if m: uk=m.group(1).strip()
    if n: us=n.group(1).strip()
    if not m and not n and value: us=value.strip('[] ')
    return uk,us

def notes(path):
    with zipfile.ZipFile(path) as z:
        dbname=next(n for n in z.namelist() if n.endswith('collection.anki2'))
        blob=z.read(dbname)
    tmp=path.with_suffix('.example.audit.anki2'); tmp.write_bytes(blob)
    try:
        db=sqlite3.connect(tmp)
        models=json.loads(db.execute('select models from col').fetchone()[0])
        flds={int(k):[f['name'] for f in v['flds']] for k,v in models.items()}
        for nid,mid,raw in db.execute('select id,mid,flds from notes'):
            yield nid,dict(zip(flds.get(mid,[]),raw.split(SEP)))
    finally:
        try:tmp.unlink()
        except OSError:pass

def card(path,source):
    for nid,f in notes(path):
        w=word(first(f,'单词','word','Word','英语单词'))
        if not w:continue
        uk,us=pron(first(f,'英美音标','发音','音标'))
        en=first(f,'例句','英语例句','example_en','真题原句')
        cn=first(f,'例句翻译','中文例句','example_zh')
        definition=first(f,'释义1','中文释义','解释','definition')
        if not definition:
            definition=' '.join(filter(None,[clean(f.get('词性1','')),clean(f.get('释义1','')),clean(f.get('词性2','')),clean(f.get('释义2',''))]))
        yield {'source':source,'note_id':nid,'word':w,'uk_pron':uk,'us_pron':us,'interpret':definition,'example_en':en,'example_cn':cn}

def coca(path,source):
    for nid,f in notes(path):
        w=word(first(f,'单词'))
        if not w:continue
        _,us=pron(first(f,'音标'))
        yield {'source':source,'note_id':nid,'word':w,'uk_pron':'','us_pron':us,'interpret':first(f,'解释'),'example_en':first(f,'例句'),'example_cn':''}

def sentence(path,source,existing):
    # A sentence card has no target field. Match words occurring in the sentence
    # against the real dictionary, retaining the longest useful first example.
    emitted={}
    for nid,f in notes(path):
        en=first(f,'Front'); cn=first(f,'Back')
        if not en:continue
        for token in WORD_RE.findall(en.lower()):
            if token in existing and token not in emitted:
                emitted[token]={'source':source,'note_id':nid,'word':token,'uk_pron':'','us_pron':'','interpret':'','example_en':en,'example_cn':cn}
    return list(emitted.values())

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--db',type=Path,required=True); ap.add_argument('--anki-dir',type=Path,required=True); ap.add_argument('--out',type=Path,required=True); args=ap.parse_args(); args.out.mkdir(parents=True,exist_ok=True)
    dbraw=args.out/'_audit.db'
    with gzip.open(args.db,'rb') as s,dbraw.open('wb') as d:d.write(s.read())
    db=sqlite3.connect(dbraw)
    existing={r[0].lower():r for r in db.execute('select word,uk_pron,us_pron,interpret,example from words')}
    decks=[('5500.apkg','anki:5500.apkg',card),('TOEFL__.apkg','anki:TOEFL__.apkg',card),('Anki.apkg','anki:Anki.apkg',card),('blank.apkg','anki:blank.apkg',card),('blank (1).apkg','anki:blank (1).apkg',card),('blank (2).apkg','anki:blank (2).apkg',card),('COCAEnglish10000.apkg','anki:COCAEnglish10000.apkg',coca),('COCA_words_16000_COCA.apkg','anki:COCA_words_16000_COCA.apkg',coca)]
    candidates=[]
    for fn,src,parser in decks:
        p=args.anki_dir/fn
        if p.exists(): candidates.extend(parser(p,src))
    sentence_rows=[]
    sp=args.anki_dir/'167000.apkg'
    if sp.exists(): sentence_rows=sentence(sp,'anki:167000.apkg',existing)
    # Prefer candidates with actual examples; preserve first source for each word/field.
    by_word={}
    for item in candidates+sentence_rows:
        old=by_word.get(item['word'])
        if old is None or (not old['example_en'] and item['example_en']): by_word[item['word']]=item
    rows=[]; stats=Counter(); by_source=Counter()
    for item in by_word.values():
        row=existing.get(item['word']); item['matched']=bool(row)
        if not row:stats['new_candidate']+=1; rows.append(item); continue
        stats['matched']+=1
        item['fill_interpret']=bool(not row[3] and item['interpret'])
        item['fill_example']=bool(not row[4] and item['example_en'])
        item['fill_uk']=bool(not row[1] and item['uk_pron'])
        item['fill_us']=bool(not row[2] and item['us_pron'])
        for k in ('fill_interpret','fill_example','fill_uk','fill_us'): stats[k]+=int(item[k])
        if item['fill_example']:by_source[item['source']]+=1
        rows.append(item)
    def dump(name,data):
        with (args.out/name).open('w',encoding='utf-8') as f:
            for x in data:f.write(json.dumps(x,ensure_ascii=False)+'\n')
    dump('example_fill.jsonl',rows); dump('sentence_deck_matches.jsonl',sentence_rows)
    report={'database_words':len(existing),'unique_candidates':len(rows),'matched':stats['matched'],'new_candidates':stats['new_candidate'],'fill_interpret':stats['fill_interpret'],'fill_example':stats['fill_example'],'fill_uk':stats['fill_uk'],'fill_us':stats['fill_us'],'fill_example_by_source':dict(by_source),'sentence_deck_raw_notes':784,'policy':'non_destructive_accept_all_sources'}
    (args.out/'example_audit_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8'); print(json.dumps(report,ensure_ascii=False,indent=2)); db.close(); dbraw.unlink(missing_ok=True)
if __name__=='__main__':main()
