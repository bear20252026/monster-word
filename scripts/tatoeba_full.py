# -*- coding: utf-8 -*-
"""Full-Tatoeba matcher: bidirectional en<->cmn pairs from links.csv + full sentences dump.

Pass1: sentences.tar.bz2 -> eng_ids, cmn_ids (int sets)
Pass2: links.csv         -> en2cmn (both directions, dedup)
Pass3: sentences.tar.bz2 -> match remaining gap words, select <=4/word
Output: tatoeba_full_candidates.json {lower_word: [[en, zh], ...]}
"""
import bz2, json, re, tarfile, time

BASE = "D:/claude/work/cn_com_lange/wordlists"
WORK = "C:/Users/17296/AppData/Local/Temp/mw_sentence_batch"
DUMP = f"{WORK}/sentences.tar.bz2"
CAP = 8

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

t0 = time.time()

# ---- pass 1: language id sets ----
eng_ids, cmn_ids = set(), set()
with tarfile.open(DUMP, "r:bz2") as tf:
    inner = tf.extractfile(tf.getmembers()[0])
    for raw in inner:
        p = raw.decode("utf-8").rstrip("\n").split("\t")
        if len(p) < 3:
            continue
        try:
            sid = int(p[0])
        except ValueError:
            continue
        if p[1] == "eng":
            eng_ids.add(sid)
        elif p[1] == "cmn":
            cmn_ids.add(sid)
print(f"[1] eng={len(eng_ids)} cmn={len(cmn_ids)} ({time.time()-t0:.0f}s)", flush=True)

# ---- pass 2: links scan ----
en2cmn = {}
with open(f"{BASE}/links.csv", encoding="utf-8") as f:
    for raw in f:
        p = raw.rstrip("\n").split("\t")
        if len(p) < 2:
            continue
        try:
            a, b = int(p[0]), int(p[1])
        except ValueError:
            continue
        if a in eng_ids and b in cmn_ids:
            en2cmn.setdefault(a, b)
        elif a in cmn_ids and b in eng_ids:
            en2cmn.setdefault(b, a)
print(f"[2] en2cmn pairs={len(en2cmn)} ({time.time()-t0:.0f}s)", flush=True)

# ---- pass 3: match ----
ph_by_first = {}
for toks in phrases:
    ph_by_first.setdefault(toks[0], []).append(toks)
tok_pat = re.compile(r"[a-z]+(?:'[a-z]+)*")
cjk_pat = re.compile(r"[\u4e00-\u9fff]")

cands = {}        # word -> list[[en, cmn_id, len]]
need_cmn = set()  # cmn ids required
CMN_TEXT = {}     # cmn id -> text
kept = 0
with tarfile.open(DUMP, "r:bz2") as tf:
    inner = tf.extractfile(tf.getmembers()[0])
    for raw in inner:
        p = raw.decode("utf-8").rstrip("\n").split("\t")
        if len(p) < 3:
            continue
        try:
            sid = int(p[0])
        except ValueError:
            continue
        if p[1] == "eng":
            cid = en2cmn.get(sid)
            if cid is None:
                continue
            en = p[2].strip()
            n = len(en)
            if n < 15 or n > 140:
                continue
            toks = tok_pat.findall(en.lower())
            if not toks:
                continue
            hit_words = set(toks) & singles
            for i, tk in enumerate(toks):
                for pt in ph_by_first.get(tk, ()):
                    if tuple(toks[i:i + len(pt)]) == pt:
                        hit_words.add(phrases[pt])
                        break
            if not hit_words:
                continue
            kept += 1
            need_cmn.add(cid)
            for w in hit_words:
                lst = cands.setdefault(w, [])
                if len(lst) < CAP:
                    lst.append([en, cid, n])
        elif p[1] == "cmn":
            if sid in need_cmn:
                need_cmn.discard(sid)
                CMN_TEXT[sid] = p[2].strip()
print(f"[3] kept sentences={kept} words_with_cand={len(cands)} ({time.time()-t0:.0f}s)", flush=True)

# cmn text may still be incomplete if eng rows appeared after their cmn rows;
# do a dedicated cmn-only sweep for anything missing
missing = need_cmn
if missing:
    with tarfile.open(DUMP, "r:bz2") as tf:
        inner = tf.extractfile(tf.getmembers()[0])
        for raw in inner:
            p = raw.decode("utf-8").rstrip("\n").split("\t")
            if len(p) < 3 or p[1] != "cmn":
                continue
            try:
                sid = int(p[0])
            except ValueError:
                continue
            if sid in missing:
                missing.discard(sid)
                CMN_TEXT[sid] = p[2].strip()
                if not missing:
                    break
    print(f"[3b] cmn text total={len(CMN_TEXT)} still_missing={len(missing)}", flush=True)

# ---- select ----
out = {}
for w, lst in cands.items():
    rows, seen = [], set()
    for en, cid, n in sorted(lst, key=lambda x: x[2]):
        zh = CMN_TEXT.get(cid, "")
        if not zh or not cjk_pat.search(zh) or en in seen:
            continue
        seen.add(en)
        rows.append([en, zh])
        if len(rows) >= 4:
            break
    if rows:
        out[w] = rows
json.dump(out, open(f"{WORK}/tatoeba_full_candidates.json", "w", encoding="utf-8"), ensure_ascii=False)
print(f"[4] words covered={len(out)} -> tatoeba_full_candidates.json ({time.time()-t0:.0f}s)", flush=True)
