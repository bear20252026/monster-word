# -*- coding: utf-8 -*-
"""R10：柯林斯压扁条目结构化复原。
形态：g[].s[].e = "N-VAR中文词义English def.例：English example中文翻译 N-UNCOUNT..."
复原为多个标准 sense：{i:{e,c,p}, g:[{s:[{e,c}]}]}
用法: python repair_collins.py [--apply]
"""
import sqlite3
import json
import re
import sys
from collections import Counter

DB = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\wordbook.db"
APPLY = "--apply" in sys.argv
CJK = re.compile(r"[\u4e00-\u9fff]")
POS_MARK = re.compile(r"(?:^|\s)([A-Z]+(?:-[A-Z]+)*)(?=[\u4e00-\u9fff（(])")
EX_MARK = re.compile(r"例[：:]")

stats = Counter()
samples = {}

def parse_flattened(text):
    """解析压扁串，返回 senses 列表或 None"""
    marks = list(POS_MARK.finditer(text))
    if not marks:
        return None
    senses = []
    for k, m in enumerate(marks):
        pos = m.group(1)
        start = m.end()
        end = marks[k + 1].start() if k + 1 < len(marks) else len(text)
        seg = text[start:end].strip()
        # 英文起点：首个 [A-Za-z]
        en_idx = None
        for i, ch in enumerate(seg):
            if ch.isascii() and ch.isalpha():
                en_idx = i
                break
        if en_idx is None or en_idx == 0:
            # 无中文词义或纯中文——跳过该段
            if en_idx is None:
                continue
        gloss = seg[:en_idx].strip() if en_idx > 0 else ""
        rest = seg[en_idx:].strip()
        parts = EX_MARK.split(rest)
        endef = parts[0].strip()
        endef = re.sub(r"\s+", " ", endef)
        if not endef or not re.search(r"[A-Za-z]", endef):
            continue
        s_list = []
        for ex in parts[1:]:
            ex = ex.strip()
            if not ex:
                continue
            # 英文句 + 粘连中文翻译
            cut = None
            for i, ch in enumerate(ex):
                if CJK.match(ch):
                    cut = i
                    break
            if cut is None:
                en_s, cn_s = ex, ""
            else:
                en_s, cn_s = ex[:cut].strip(), ex[cut:].strip()
            en_s = re.sub(r"\s+", " ", en_s)
            if not en_s:
                continue
            s_list.append({"e": en_s, "c": cn_s, "b": ""})
        sense = {"oid": 0, "i": {"e": endef, "c": gloss, "p": pos}, "g": ([{"uid": 0, "u": "", "s": s_list}] if s_list else [])}
        senses.append(sense)
    return senses or None

def repair_example(raw):
    """返回 (新值 or None, changed)"""
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
        # i.e 压扁
        i = it.get("i")
        if isinstance(i, dict):
            ie = (i.get("e") or "").strip()
            if ie and POS_MARK.search(ie) and CJK.search(ie):
                parsed = parse_flattened(ie)
                if parsed:
                    stats["i_flattened_repaired"] += 1
                    new_items.extend(parsed)
                    changed = True
                    continue
        g = it.get("g")
        flat_found = False
        if isinstance(g, list):
            for grp in g:
                if not isinstance(grp, dict):
                    continue
                for s_ in grp.get("s") or []:
                    if isinstance(s_, dict):
                        e = (s_.get("e") or "").strip()
                        if e and POS_MARK.search(e) and CJK.search(e) and parse_flattened(e):
                            flat_found = True
                            break
                if flat_found:
                    break
        if flat_found:
            stats["s_flattened_entries"] += 1
            parsed_all = []
            # 该 item 里所有压扁句全部展开；其余正常句保留
            keep_s = []
            for grp in g:
                if not isinstance(grp, dict):
                    continue
                for s_ in grp.get("s") or []:
                    if not isinstance(s_, dict):
                        continue
                    e = (s_.get("e") or "").strip()
                    if e and POS_MARK.search(e) and CJK.search(e):
                        parsed = parse_flattened(e)
                        if parsed:
                            parsed_all.extend(parsed)
                            stats["s_flattened_strings"] += 1
                            continue
                    keep_s.append(s_)
            if parsed_all:
                new_items.extend(parsed_all)
                # 原 item 若还有真实句或非空 i，保留
                i2 = it.get("i") or {}
                has_i = any((i2.get(k) or "").strip() for k in ("e", "c", "p"))
                if keep_s or has_i:
                    it2 = dict(it)
                    it2["g"] = ([{"uid": 0, "u": "", "s": keep_s}] if keep_s else [])
                    new_items.append(it2)
                changed = True
                continue
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
    cur.execute("SELECT id, word, example FROM words WHERE example IS NOT NULL")
    while True:
        rows = cur.fetchmany(20000)
        if not rows:
            break
        for rid, word, ex in rows:
            new, changed = repair_example(ex)
            if changed:
                updates.append((new, rid))
                if shown < 3:
                    samples[word] = (ex[:400], (new or "")[:400])
                    shown += 1
    print(f"entries repaired: {len(updates)}")
    for k, v in stats.items():
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
