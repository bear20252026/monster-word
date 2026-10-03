# -*- coding: utf-8 -*-
"""R10d：英文槽中文残留收尾（修 R10c 的 repaired_as_sense 未应用 bug + 8 类模式）。
用法: python repair_collins4.py [--apply]
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
EN_DEF_LC = re.compile(r"[A-Za-z]{2,}\s+(?:[A-Za-z'’,\(\)\-]+\s+){4,}[A-Za-z'’,\(\)\-]+")
EX_MARK = re.compile(r"例[：:]")
FORM_NOTE = re.compile(r"的(过去分词|过去式|现在分词|复数|比较级|最高级|第三人称单数|ing形式|所有格)")
JUNK_MENU = re.compile(r"生词本|单词管家|音标说明|海词英语|桌面客户端|背单词")
NUM_DEF = re.compile(r"\((\d+)\)\s*")

stats = Counter()
samples = {}

def cjk_count(s): return len(CJK.findall(s))
def latin_count(s): return len(re.findall(r"[A-Za-z]", s))

def cjk_in_parens_only(s):
    """中文仅出现在括号内注记"""
    stripped = re.sub(r"[（(][^（）()]*[）)]", "", s)
    return not CJK.search(stripped)

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

def repair_text(e, in_sentence):
    """返回 dict(kind=..., p=, c=, endef=, sents=[...], drop=bool) 或 None"""
    t = e.strip()
    if not CJK.search(t) or "<b>" in t:
        return None
    starts_latin = bool(re.match(r"^[A-Za-z]", t))

    # g7: 网站菜单垃圾句
    if in_sentence and JUNK_MENU.search(t) and len(JUNK_MENU.findall(t)) >= 2:
        return {"kind": "g7_junk", "p": "", "c": "", "endef": "", "sents": [], "drop": True}

    # g6: (1) 编号中文释义串
    if re.match(r"^\(\d+\)", t) and cjk_count(t) >= 2:
        segs = [s.strip(" ;；") for s in NUM_DEF.split(t) if s.strip(" ;；")]
        joined = "；".join(segs)
        return {"kind": "g6_numbered", "p": "", "c": joined, "endef": "", "sents": [], "drop": False}

    # g1: 英文起头 + 例：尾挂（允许括号内中文注记）
    if starts_latin and EX_MARK.search(t):
        parts = EX_MARK.split(t)
        endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
        if endef and cjk_in_parens_only(endef):
            return {"kind": "g1", "p": "", "c": "", "endef": endef, "sents": split_sentences(t), "drop": False}

    # g2: 词义碎片 + 大写英文释义
    for pat in (EN_DEF, EN_DEF_LC):
        m = None
        for cand in pat.finditer(t):
            pre = t[cand.start() - 1] if cand.start() > 0 else ""
            if cand.start() == 0 or CJK.match(pre) or pre in "）)":
                m = cand
                break
        if m:
            gloss = t[:m.start()].strip()
            rest = t[m.start():].strip()
            if gloss and CJK.search(gloss) and len(gloss) <= 60:
                parts = EX_MARK.split(rest)
                endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
                if endef and latin_count(endef) > cjk_count(endef) * 2 and len(endef) > 15:
                    return {"kind": "g2", "p": "", "c": gloss, "endef": endef, "sents": split_sentences(rest), "drop": False}

    # g5: 中文起头 + 词形注记（X的过去分词 等）
    if not starts_latin and FORM_NOTE.search(t):
        return {"kind": "g5_form_note", "p": "", "c": t, "endef": "", "sents": [], "drop": False}

    # g4 relaxed: 中文起头、中文为主（含拉丁专名）
    if not starts_latin and cjk_count(t) >= 4 and latin_count(t) <= cjk_count(t) * 3:
        return {"kind": "g4", "p": "", "c": t, "endef": "", "sents": [], "drop": False}

    # g8: 英文占优 + 尾部粘连中文（≥2 连续中文收尾）
    if starts_latin and latin_count(t) > cjk_count(t) * 2:
        m8 = re.search(r"[A-Za-z\s.,;:'\"!?()\-…]+([\u4e00-\u9fff][\u4e00-\u9fff\uff0c；;、。：\s]{1,})$", t)
        if m8 and m8.start(1) > 20:
            endef = t[:m8.start(1)].strip().strip(" ;；,，")
            cn = m8.group(1).strip()
            if cn and endef:
                return {"kind": "g8_tail_cjk", "p": "", "c": cn, "endef": endef, "sents": [], "drop": False}

    # g5b: <主英> 标签
    if t.startswith("<") and CJK.search(t):
        return {"kind": "g5b_tag", "p": "", "c": t, "endef": "", "sents": [], "drop": False}

    return None

def clean_gloss(c):
    """去除孤立括号片段"""
    if not c:
        return c
    for op, cl in (("(", ")"), ("（", "）")):
        while c.count(cl) > c.count(op):
            c = c.replace(cl, "", 1)
    return c.strip(" ,；;）)")

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
        it_changed = False

        # i.e
        if isinstance(i, dict):
            ie = (i.get("e") or "").strip()
            if ie and CJK.search(ie):
                r = repair_text(ie, in_sentence=False)
                if r:
                    stats["i_" + r["kind"]] += 1
                    it_changed = True
                    old_p = (i.get("p") or "").strip()
                    old_c = (i.get("c") or "").strip()
                    if r["endef"]:
                        # 重组为标准释义 + 例句（保留原词性/原中文）
                        keep_s = []
                        for grp in (g or []):
                            if isinstance(grp, dict):
                                for s_ in grp.get("s") or []:
                                    if isinstance(s_, dict) and (s_.get("e") or "").strip():
                                        keep_s.append(s_)
                        all_s = r["sents"] + keep_s
                        new_c = clean_gloss(r["c"]) or old_c
                        it = {"oid": it.get("oid", 0), "i": {"e": r["endef"], "c": new_c, "p": r["p"] or old_p},
                              "g": ([{"uid": 0, "u": "", "s": all_s}] if all_s else [])}
                    else:
                        i2 = dict(i)
                        i2["e"] = ""
                        i2["c"] = clean_gloss(r["c"]) or old_c
                        i2["p"] = r["p"] or old_p
                        it = {**it, "i": i2}

        # s.e
        if isinstance(g, list):
            new_g = []
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
                    r = repair_text(e, in_sentence=True) if (e and CJK.search(e)) else None
                    if not r:
                        new_s.append(s_)
                        continue
                    stats["s_" + r["kind"]] += 1
                    it_changed = True
                    if r["endef"]:
                        promote = r
                        continue  # 句子本身转为释义
                    if r["drop"]:
                        continue
                    s2 = dict(s_)
                    s2["c"] = (s2.get("c") or "") or r["c"]
                    s2["e"] = ""
                    if s2["c"]:
                        new_s.append(s2)
                new_g.append({**grp, "s": new_s})
            it = {**it, "g": new_g}
            if promote:
                i2 = it.get("i") or {}
                old_p = (i2.get("p") or "").strip()
                if not any((i2.get(k) or "").strip() for k in ("e", "c", "p")):
                    keep_s = [s_ for grp in new_g if isinstance(grp, dict) for s_ in grp.get("s") or []
                              if isinstance(s_, dict) and (s_.get("e") or "").strip()]
                    all_s = promote["sents"] + keep_s
                    it = {**it, "i": {"e": promote["endef"], "c": clean_gloss(promote["c"]), "p": promote["p"] or old_p},
                          "g": ([{"uid": 0, "u": "", "s": all_s}] if all_s else [])}
        if it_changed:
            changed = True
        new_items.append(it)
    if not changed:
        return raw, False
    new_items = [x for x in new_items if isinstance(x, dict)]
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
            new, changed = apply_to_example(ex)
            if changed:
                updates.append((new, rid))
                if shown < 6:
                    samples[word] = (ex[:250], (new or "")[:250])
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
