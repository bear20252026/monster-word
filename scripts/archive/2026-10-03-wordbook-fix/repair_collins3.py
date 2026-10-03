# -*- coding: utf-8 -*-
"""R10c：英文槽中文残留终轮修复。
规则（判据：切分点必须为 中文/）→大写英文 边界）：
  g1: 纯英文释义 + 尾挂 例：...
  g2: 前缀词义碎片（含中文、≤40字符）+ 大写英文释义 (+ 例：)
  g3: 词性缩写前缀 + 中文占优串 → p/c
  g4: 中文占优串 → 挪 c
只动确有中文且可安全切分的；其余保留并汇总打印人工复核。
用法: python repair_collins3.py [--apply]
"""
import sqlite3
import json
import re
import sys
from collections import Counter

DB = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\wordbook.db"
APPLY = "--apply" in sys.argv
CJK = re.compile(r"[\u4e00-\u9fff]")
EN_DEF = re.compile(r"[A-Z][a-z]+(?:'[a-z]+)?\s+(?:[A-Za-z'’,\(\)\-]+\s+){2,}[A-Za-z'’,\(\)\-]+")
EX_MARK = re.compile(r"例[：:]")

stats = Counter()
samples = {}

def cjk_count(s): return len(CJK.findall(s))
def latin_count(s): return len(re.findall(r"[A-Za-z]", s))

def split_sentences(tail):
    out = []
    for ex in EX_MARK.split(tail)[1:]:
        ex = ex.strip()
        if not ex:
            continue
        cut = None
        for i, ch in enumerate(ex):
            if CJK.match(ch):
                cut = i
                break
        en_s, cn_s = (ex, "") if cut is None else (ex[:cut].strip(), ex[cut:].strip())
        en_s = re.sub(r"\s+", " ", en_s)
        if en_s:
            out.append({"e": en_s, "c": cn_s, "b": ""})
    return out

def repair_text(e):
    """返回 (kind, p, c, endef, sentences) 或 None"""
    t = e.strip()
    if not CJK.search(t) or "<b>" in t:
        return None
    starts_latin = bool(re.match(r"^[A-Za-z]", t))
    latin_dom = latin_count(t) > cjk_count(t) * 2

    # g1: 英文起头 + 例：尾挂
    if starts_latin and EX_MARK.search(t):
        parts = EX_MARK.split(t)
        endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
        if endef and not CJK.search(endef):
            return ("g1", "", "", endef, split_sentences(t))

    # g2: 词义碎片 + 大写英文释义（边界：前一字符为中文或）或行首）
    m = None
    for cand in EN_DEF.finditer(t):
        pre = t[cand.start() - 1] if cand.start() > 0 else ""
        if cand.start() == 0 or CJK.match(pre) or pre in "）)":
            m = cand
            break
    if m:
        gloss = t[:m.start()].strip()
        rest = t[m.start():].strip()
        if gloss and CJK.search(gloss) and len(gloss) <= 40 and "<b>" not in gloss:
            parts = EX_MARK.split(rest)
            endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
            if endef and latin_count(endef) > cjk_count(endef) * 2:
                return ("g2", "", gloss, endef, split_sentences(rest))

    # g3: 词性缩写 + 中文占优
    m3 = re.match(r"^([a-z]{1,6}\.\s+)(.*)$", t, re.S)
    if m3 and cjk_count(m3.group(2)) > latin_count(m3.group(2)) and latin_count(m3.group(2)) <= 12:
        return ("g3", m3.group(1).strip(), m3.group(2).strip(), "", [])

    # g4: 中文占优（latin ≤ 12）
    if not starts_latin and cjk_count(t) > latin_count(t) and latin_count(t) <= 12:
        return ("g4", "", t, "", [])

    return None

def apply_to_example(raw):
    if not raw:
        return raw, False
    try:
        v = json.loads(raw)
    except Exception:
        return raw, False
    if isinstance(v, str):
        return raw, False
    items = v.get("data") if isinstance(v, dict) else v
    if not isinstance(items, list):
        return raw, False
    new_items = []
    changed = False
    for it in items:
        if not isinstance(it, dict):
            new_items.append(it)
            continue
        i = it.get("i")
        g = it.get("g")
        repaired_as_sense = None

        # i.e 修复
        if isinstance(i, dict):
            ie = (i.get("e") or "").strip()
            if ie and CJK.search(ie):
                r = repair_text(ie)
                if r:
                    kind, p, c, endef, sents = r
                    stats["i_" + kind] += 1
                    if endef:
                        repaired_as_sense = (p, c, endef, sents, True)
                    else:
                        i2 = dict(i)
                        i2["e"] = ""
                        i2["c"] = c or (i2.get("c") or "")
                        i2["p"] = p or (i2.get("p") or "")
                        it = {**it, "i": i2}
                        changed = True

        # s.e 修复
        if isinstance(g, list):
            new_g = []
            g_changed = False
            promote = None
            for grp in g:
                if not isinstance(grp, dict):
                    new_g.append(grp)
                    continue
                new_s = []
                for s_ in grp.get("s") or []:
                    if not isinstance(s_, dict):
                        new_s.append(s_)
                        continue
                    e = (s_.get("e") or "").strip()
                    r = repair_text(e) if (e and CJK.search(e)) else None
                    if not r:
                        new_s.append(s_)
                        continue
                    kind, p, c, endef, sents = r
                    stats["s_" + kind] += 1
                    g_changed = True
                    if endef:
                        promote = (p, c, endef, sents)
                    else:
                        s2 = dict(s_)
                        s2["c"] = (s2.get("c") or "") or c
                        s2["e"] = ""
                        if s2["c"]:
                            new_s.append(s2)
                if new_s or promote is None:
                    new_g.append({**grp, "s": new_s})
                else:
                    new_g.append({**grp, "s": new_s})
            if g_changed:
                it = {**it, "g": new_g}
                changed = True
                if promote:
                    p, c, endef, sents = promote
                    i2 = it.get("i") or {}
                    if not any((i2.get(k) or "").strip() for k in ("e", "c", "p")):
                        # 保留原句（除被修复者）
                        keep_s = [s_ for grp in new_g if isinstance(grp, dict) for s_ in grp.get("s") or [] if isinstance(s_, dict) and (s_.get("e") or "").strip()]
                        it = {**it, "i": {"e": endef, "c": c, "p": p},
                              "g": ([{"uid": 0, "u": "", "s": sents + keep_s}] if (sents or keep_s) else [])}
        new_items.append(it)
    if not changed:
        return raw, False
    if not new_items:
        return None, True
    if isinstance(v, dict):
        v["data"] = new_items
        out = v
    else:
        out = new_items
    return json.dumps(out, ensure_ascii=False, separators=(",", ":")), True

def main():
    con = sqlite3.connect(DB)
    cur = con.cursor()
    updates = []
    shown = 0
    residual = []
    cur.execute("SELECT id, word, example FROM words WHERE example IS NOT NULL")
    while True:
        rows = cur.fetchmany(20000)
        if not rows:
            break
        for rid, word, ex in rows:
            new, changed = apply_to_example(ex)
            if changed:
                updates.append((new, rid))
                if shown < 5:
                    samples[word] = (ex[:260], (new or "")[:260])
                    shown += 1
    print(f"entries repaired: {len(updates)}")
    for k, v in sorted(stats.items()):
        print(f"  {k}: {v}")
    for w, (a, b) in samples.items():
        print(f"\n[{w}] BEFORE: {a}\n[{w}] AFTER : {b}")
    if APPLY:
        con.execute("BEGIN")
        cur.executemany("UPDATE words SET example=? WHERE id=?", updates)
        con.commit()
        print("APPLIED & COMMITTED")
    else:
        print("DRY RUN")
    con.close()

if __name__ == "__main__":
    main()
