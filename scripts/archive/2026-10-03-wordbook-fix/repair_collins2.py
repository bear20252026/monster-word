# -*- coding: utf-8 -*-
"""R10b：柯林斯压扁条目边角变体修复（空词性/带点词性/无词性前缀/纯中文词性串/中文占优串/中文序号前缀）。
用法: python repair_collins2.py [--apply]
"""
import sqlite3
import json
import re
import sys
from collections import Counter

DB = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\wordbook.db"
APPLY = "--apply" in sys.argv
CJK = re.compile(r"[\u4e00-\u9fff]")
POS_SET = {"N-VAR", "N-COUNT", "N-UNCOUNT", "N-PROPER", "ADJ", "ADJ-GRADED", "VERB", "ADV",
           "PREP", "PRON", "CONJ", "DET", "NUM", "ABBR", "MODAL", "PHRASE", "PHR-MODAL", "N-TITLE"}
# a/b: POS 可带 ". " 且词义可为空
POS_MARK2 = re.compile(r"(?:^|\s)([A-Z]+(?:-[A-Z]+)*)\.?\s*(?=[\u4e00-\u9fff（(]|[A-Z][a-z])")
EN_DEF_START = re.compile(r"[A-Z][a-z]+(?:'[a-z]+)?\s+(?:[A-Za-z'’,\(\)-]+\s+){2,}[A-Za-z'’,\(\)-]+")
EX_MARK = re.compile(r"例[：:]")
POS_CN_ONLY = re.compile(r"^((?:[a-z]{1,6}\.\s*)+)([\u4e00-\u9fff].*)$", re.S)

stats = Counter()
samples = {}

def cjk_count(s):
    return len(CJK.findall(s))

def latin_count(s):
    return len(re.findall(r"[A-Za-z]", s))

def parse_flattened2(text):
    marks = []
    for m in POS_MARK2.finditer(text):
        if m.group(1) in POS_SET:
            marks.append(m)
    if not marks:
        return None
    senses = []
    for k, m in enumerate(marks):
        pos = m.group(1)
        start = m.end()
        end = marks[k + 1].start() if k + 1 < len(marks) else len(text)
        seg = text[start:end].strip()
        en_idx = None
        for i, ch in enumerate(seg):
            if ch.isascii() and ch.isalpha():
                en_idx = i
                break
        gloss = seg[:en_idx].strip() if (en_idx or 0) > 0 else ""
        rest = seg[en_idx:].strip() if en_idx is not None else ""
        if not rest:
            continue
        parts = EX_MARK.split(rest)
        endef = re.sub(r"\s+", " ", parts[0]).strip()
        endef = endef.strip(" ;；,，")
        if not endef or not re.search(r"[A-Za-z]", endef):
            continue
        # 英文释义必须是英文为主
        if cjk_count(endef) > latin_count(endef):
            continue
        s_list = []
        for ex in parts[1:]:
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
                s_list.append({"e": en_s, "c": cn_s, "b": ""})
        senses.append({"oid": 0, "i": {"e": endef, "c": gloss, "p": pos},
                       "g": ([{"uid": 0, "u": "", "s": s_list}] if s_list else [])})
    return senses or None

def parse_leading_gloss(text):
    """c 变体：中文词义开头（无 POS），后接英文释义（大写词开头连续英文串）"""
    m = EN_DEF_START.search(text)
    if not m or m.start() == 0:
        return None
    gloss = text[:m.start()].strip()
    rest = text[m.start():].strip()
    # 词义必须含中文且较短
    if not CJK.search(gloss) or latin_count(gloss) > cjk_count(gloss) * 2 or len(gloss) > 60:
        return None
    if "<b>" in gloss:
        return None
    parts = EX_MARK.split(rest)
    endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
    if not endef or cjk_count(endef) > latin_count(endef):
        return None
    s_list = []
    for ex in parts[1:]:
        cut = None
        for i, ch in enumerate(ex):
            if CJK.match(ch):
                cut = i
                break
        en_s, cn_s = (ex, "") if cut is None else (ex[:cut].strip(), ex[cut:].strip())
        en_s = re.sub(r"\s+", " ", en_s)
        if en_s:
            s_list.append({"e": en_s, "c": cn_s, "b": ""})
    return {"oid": 0, "i": {"e": endef, "c": gloss, "p": ""},
            "g": ([{"uid": 0, "u": "", "s": s_list}] if s_list else [])}

def fix_string_item(e):
    """d/e/f 变体：返回 (新i字典 or 新句子e or None, 类型)"""
    t = e.strip()
    # d: "pl. 收益" 纯中文词性串
    m = POS_CN_ONLY.match(t)
    if m and not CJK.search(m.group(1)) and cjk_count(m.group(2)) > 0 and latin_count(m.group(2)) <= 4:
        return {"e": "", "c": m.group(2).strip(), "p": m.group(1).strip()}, "d_pos_cn"
    # e: 中文占优 → 挪 c
    if CJK.search(t) and cjk_count(t) > latin_count(t) and latin_count(t) <= 6:
        return {"e": "", "c": t, "p": ""}, "e_cjk_dominant"
    # f: 中文序号前缀 "一 1. English..."
    m2 = re.match(r"^([\u4e00-\u9fff]{1,3})\s*(\d{1,2})[.、]\s*(\S.*)$", t, re.S)
    if m2 and re.match(r"^[A-Za-z]", m2.group(3)):
        return m2.group(3).strip(), "f_cjk_numbering"
    return None, None

def repair_example(raw):
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
        item_replaced = False

        # 1) i.e 压扁变体（POS 前缀 / 中文词义开头）
        if isinstance(i, dict):
            ie = (i.get("e") or "").strip()
            if ie and CJK.search(ie):
                parsed = None
                if POS_MARK2.search(ie):
                    parsed = parse_flattened2(ie)
                if parsed is None and re.match(r"^[\u4e00-\u9fff（(]", ie):
                    lg = parse_leading_gloss(ie)
                    parsed = [lg] if lg else None
                if parsed:
                    stats["i_flattened2"] += 1
                    keep_s = []
                    for grp in (g or []):
                        if isinstance(grp, dict):
                            for s_ in grp.get("s") or []:
                                if isinstance(s_, dict) and (s_.get("e") or "").strip():
                                    keep_s.append(s_)
                    new_items.extend(parsed)
                    if keep_s:
                        new_items.append({"oid": 0, "i": {"e": "", "c": "", "p": ""},
                                          "g": [{"uid": 0, "u": "", "s": keep_s}]})
                    changed = True
                    item_replaced = True
        if item_replaced:
            continue

        # 2) s.e 压扁变体
        flat = False
        if isinstance(g, list):
            for grp in g:
                if isinstance(grp, dict):
                    for s_ in grp.get("s") or []:
                        if isinstance(s_, dict):
                            e = (s_.get("e") or "").strip()
                            if e and CJK.search(e):
                                if (POS_MARK2.search(e) and parse_flattened2(e)) or (
                                        re.match(r"^[\u4e00-\u9fff（(]", e) and parse_leading_gloss(e)):
                                    flat = True
                                    break
                    if flat:
                        break
        if flat:
            stats["s_flattened2"] += 1
            parsed_all = []
            keep_s = []
            for grp in g:
                if not isinstance(grp, dict):
                    continue
                for s_ in grp.get("s") or []:
                    if not isinstance(s_, dict):
                        continue
                    e = (s_.get("e") or "").strip()
                    handled = False
                    if e and CJK.search(e):
                        p1 = parse_flattened2(e) if POS_MARK2.search(e) else None
                        if p1:
                            parsed_all.extend(p1)
                            stats["s_flat2_strings"] += 1
                            handled = True
                        if not handled and re.match(r"^[\u4e00-\u9fff（(]", e):
                            p2 = parse_leading_gloss(e)
                            if p2:
                                parsed_all.append(p2)
                                stats["s_flat2_lead"] += 1
                                handled = True
                    if not handled:
                        keep_s.append(s_)
            if parsed_all:
                new_items.extend(parsed_all)
                i2 = it.get("i") or {}
                if keep_s or any((i2.get(k) or "").strip() for k in ("e", "c", "p")):
                    new_items.append({**it, "g": ([{"uid": 0, "u": "", "s": keep_s}] if keep_s else [])})
                changed = True
                continue

        # 3) 句级 d/e/f 变体
        it2 = it
        if isinstance(g, list):
            new_g = []
            g_changed = False
            for grp in g:
                if not isinstance(grp, dict):
                    new_g.append(grp)
                    continue
                new_s = []
                promote = None  # d/e 变体提升为父释义
                for s_ in grp.get("s") or []:
                    if not isinstance(s_, dict):
                        new_s.append(s_)
                        continue
                    e = (s_.get("e") or "").strip()
                    fix = kind = None
                    if e and CJK.search(e) and not POS_MARK2.search(e) and not re.match(r"^[\u4e00-\u9fff（(]", e):
                        fix, kind = fix_string_item(e)
                    if fix is None:
                        new_s.append(s_)
                        continue
                    stats[kind] += 1
                    g_changed = True
                    if isinstance(fix, dict):
                        promote = fix
                    else:
                        s2 = dict(s_)
                        s2["e"] = fix
                        new_s.append(s2)
                if promote is not None:
                    i2 = it2.get("i") or {}
                    if not any((i2.get(k) or "").strip() for k in ("e", "c", "p")):
                        it2 = {**it2, "i": {"e": promote["e"], "c": promote["c"], "p": promote["p"]}}
                    else:
                        i2 = dict(i2)
                        i2["c"] = (i2.get("c") or "") or promote["c"]
                        it2 = {**it2, "i": i2}
                if new_s:
                    new_g.append({**grp, "s": new_s})
                else:
                    new_g.append({**grp, "s": []})
            if g_changed:
                it2 = {**it2, "g": new_g}
                changed = True
        it = it2

        # 4) i.e 的 d/e 变体（无 POS、非中文开头）
        if isinstance(it.get("i"), dict):
            ie = (it["i"].get("e") or "").strip()
            if ie and CJK.search(ie) and not POS_MARK2.search(ie) and not re.match(r"^[\u4e00-\u9fff（(]", ie):
                fix, kind = fix_string_item(ie)
                if isinstance(fix, dict):
                    stats["i_" + kind] += 1
                    i2 = dict(it["i"])
                    i2["e"] = fix["e"]
                    i2["c"] = fix["c"] or (i2.get("c") or "")
                    i2["p"] = fix["p"] or (i2.get("p") or "")
                    it = {**it, "i": i2}
                    changed = True
        new_items.append(it)
    if not changed:
        return raw, False
    new_items = [x for x in new_items if x is not None]
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
                if shown < 4:
                    samples[word] = (ex[:300], (new or "")[:300])
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
