# -*- coding: utf-8 -*-
"""OpenSubtitles v2024 (OPUS moses en-zh_CN) matcher for the sentence gap.

Streams the parallel .en/.zh members of the moses zip, filters noisy subtitle
pairs, matches remaining gap words (singles token-exact, phrases token-seq),
keeps <=8 candidates per word, selects <=4 shortest with valid zh.
Output: opensub_candidates.json {lower_word: [[en, zh], ...]}
"""
import json, re, time, zipfile

WORK = "C:/Users/17296/AppData/Local/Temp/mw_sentence_batch"
ZIP = f"{WORK}/opensubtitles_en-zh.zip"
CAP = 8
MIN_EN, MAX_EN = 15, 140
MAX_ZH = 40

remaining = json.load(open(f"{WORK}/remaining_gap.json", encoding="utf-8"))
singles, phrases = set(), {}
for _wid, w, _mw in remaining:
    lw = w.lower().strip()
    if not lw:
        continue
    if re.fullmatch(r"[a-z]+(?:'[a-z]+)*", lw):
        singles.add(lw)
    else:
        toks = tuple(t for t in re.split(r"[^a-z']+", lw) if t)
        if len(toks) >= 2:
            phrases.setdefault(toks, lw)
print(f"[0] singles={len(singles)} phrase_patterns={len(phrases)}", flush=True)

ENT = {"&apos;": "'", "&quot;": '"', "&amp;": "&", "&lt;": "<", "&gt;": ">"}
def unescape(s: str) -> str:
    for k, v in ENT.items():
        s = s.replace(k, v)
    return s

tok_pat = re.compile(r"[a-z]+(?:'[a-z]+)*")
cjk_pat = re.compile(r"[\u4e00-\u9fff]")
latin_pat = re.compile(r"[A-Za-z]")
ascii_ok = re.compile(r"^[\x20-\x7E]+$")
ph_by_first = {}
for toks in phrases:
    ph_by_first.setdefault(toks[0], []).append(toks)

zf = zipfile.ZipFile(ZIP)
en_name = next(n for n in zf.namelist() if n.endswith(".en"))
zh_name = next(n for n in zf.namelist() if n.endswith(".zh_CN"))
print(f"[1] members: {en_name} / {zh_name}", flush=True)

t0 = time.time()
cands = {}
n_pairs = n_kept = 0
with zf.open(en_name) as fe, zf.open(zh_name) as fz:
    for en_raw, zh_raw in zip(fe, fz):
        n_pairs += 1
        if n_pairs % 5000000 == 0:
            print(f"    ...{n_pairs} pairs ({time.time()-t0:.0f}s), words={len(cands)}", flush=True)
        en = unescape(en_raw.decode("utf-8", "ignore").strip())
        zh = unescape(zh_raw.decode("utf-8", "ignore").strip())
        n = len(en)
        if n < MIN_EN or n > MAX_EN or not zh or len(zh) > MAX_ZH:
            continue
        if not ascii_ok.match(en) or not cjk_pat.search(zh):
            continue
        if latin_pat.search(zh):
            continue
        toks = tok_pat.findall(en.lower())
        if len(toks) < 3:
            continue
        hit_words = set(toks) & singles
        for i, tk in enumerate(toks):
            for pt in ph_by_first.get(tk, ()):
                if tuple(toks[i:i + len(pt)]) == pt:
                    hit_words.add(phrases[pt])
                    break
        if not hit_words:
            continue
        n_kept += 1
        for w in hit_words:
            lst = cands.setdefault(w, [])
            if len(lst) < CAP:
                lst.append([en, zh, n])
print(f"[2] pairs={n_pairs} kept={n_kept} words_with_cand={len(cands)} ({time.time()-t0:.0f}s)", flush=True)

out = {}
for w, lst in cands.items():
    rows, seen = [], set()
    for en, zh, n in sorted(lst, key=lambda x: x[2]):
        if en in seen:
            continue
        seen.add(en)
        rows.append([en, zh])
        if len(rows) >= 4:
            break
    if rows:
        out[w] = rows
json.dump(out, open(f"{WORK}/opensub_candidates.json", "w", encoding="utf-8"), ensure_ascii=False)
print(f"[3] words covered={len(out)} -> opensub_candidates.json ({time.time()-t0:.0f}s)", flush=True)
