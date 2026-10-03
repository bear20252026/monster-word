# -*- coding: utf-8 -*-
"""R10e：残留解析边界修正（单字母A边界/驼峰粘连/中文标点边界/拉丁开头词形注记/超长gloss）+ 显式补丁。
用法: python repair_collins5.py [--apply]
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
BOUNDARY_OK = re.compile(r"[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef）)”’，。、]")

# 显式人工补丁：word -> (field_path 由脚本定位，此处直接给修复函数用的替换文本)
HAND_PATCH = {
    "crowning": None,  # 结构化补丁在代码内处理
    "em": None,
    "etc": None,
}

stats = Counter()
samples = {}

def cjk_count(s): return len(CJK.findall(s))
def latin_count(s): return len(re.findall(r"[A-Za-z]", s))

def boundary_ok(t, start):
    """start 前的片段是否为合法词义边界"""
    pre = t[:start].rstrip()
    if not pre:
        return True
    last = pre[-1]
    if CJK.match(last) or last in "）)”’’，。、,;-":
        return True
    # 单字母谓语 (A/I/a) 前接中文
    m = re.search(r"(?<=[\u4e00-\u9fff）)”])[AaI]$", pre)
    if m:
        return True
    # 驼峰粘连：小写串紧跟大写词，且其前 20 字符含中文
    if re.match(r"^[a-z]+$", last) and start < len(t) and t[start].isupper():
        if CJK.search(pre[-20:]):
            return True
    return False

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

def clean_gloss(c):
    if not c:
        return c
    for op, cl in (("(", ")"), ("（", "）")):
        while c.count(cl) > c.count(op):
            c = c.replace(cl, "", 1)
    return c.strip(" ,；;）)").strip()

def repair_text(e, in_sentence):
    t = e.strip()
    if not CJK.search(t) or "<b>" in t:
        return None
    starts_latin = bool(re.match(r"^[A-Za-z]", t))

    # g1 英文起头 + 例：
    if starts_latin and EX_MARK.search(t):
        parts = EX_MARK.split(t)
        endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
        stripped = re.sub(r"[（(][^（）()]*[）)]", "", endef)
        if endef and not CJK.search(stripped):
            return {"kind": "g1", "p": "", "c": "", "endef": endef, "sents": split_sentences(t), "drop": False}

    # g2 词义碎片 + 英文释义
    for pat in (EN_DEF, EN_DEF_LC):
        m = None
        for cand in pat.finditer(t):
            if boundary_ok(t, cand.start()):
                m = cand
                break
        if m:
            start = m.start()
            if start > 0 and t[start - 1] == "-":
                start -= 1  # 连字符前缀词（-scarred 等）
            gloss = t[:start].strip()
            rest = t[start:].strip()
            if gloss and CJK.search(gloss) and len(gloss) <= 80 and cjk_count(gloss) >= 1:
                parts = EX_MARK.split(rest)
                endef = re.sub(r"\s+", " ", parts[0]).strip().strip(" ;；,，")
                if endef and latin_count(endef) > cjk_count(endef) * 2 and len(endef) > 15:
                    return {"kind": "g2", "p": "", "c": clean_gloss(gloss), "endef": endef, "sents": split_sentences(rest), "drop": False}

    # g5 词形注记（不限制开头）
    if FORM_NOTE.search(t) and cjk_count(t) >= 3 and latin_count(t) <= cjk_count(t) * 3 and " " not in t.strip():
        return {"kind": "g5", "p": "", "c": t, "endef": "", "sents": [], "drop": False}

    # g4 中文为主
    if not starts_latin and cjk_count(t) >= 4 and latin_count(t) <= cjk_count(t) * 3:
        return {"kind": "g4", "p": "", "c": t, "endef": "", "sents": [], "drop": False}

    # g8 英文为主 + 尾部中文
    if starts_latin and latin_count(t) > cjk_count(t) * 2:
        m8 = re.search(r"[A-Za-z\s.,;:'\"!?()\-…]+([\u4e00-\u9fff][\u4e00-\u9fff\uff0c；;、。：\s]{1,})$", t)
        if m8 and m8.start(1) > 20:
            endef = t[:m8.start(1)].strip().strip(" ;；,，")
            cn = m8.group(1).strip()
            if cn and endef:
                return {"kind": "g8", "p": "", "c": cn, "endef": endef, "sents": [], "drop": False}
    return None

def hand_patch(word, v):
    """显式补丁，返回 (items, changed)"""
    if word == "crowning":
        # 两个释义粘连："The crown of a hat..." + "N-COUNT 5先令的英国硬币 A crown was..."
        out = []
        for it in v.get("data", []):
            ie = (it.get("i") or {}).get("e") or ""
            if "N-COUNT" in ie and CJK.search(ie):
                idx = ie.find("N-COUNT")
                seg1 = ie[:idx].strip()
                rest = ie[idx:]
                # N-COUNT5先令的英国硬币A crown was...
                m = re.match(r"^N-COUNT\s*(.+?)((?:A|The|It|They)\s+[A-Za-z].*)$", rest, re.S)
                if m:
                    out.append({"oid": 0, "i": {"e": seg1, "c": (it.get("i") or {}).get("c") or "", "p": (it.get("i") or {}).get("p") or ""}, "g": it.get("g") or []})
                    out.append({"oid": 0, "i": {"e": re.sub(r"\s+", " ", m.group(2)).strip(), "c": m.group(1).strip(), "p": "N-COUNT"}, "g": []})
                    stats["hand_crowning"] += 1
                    continue
            out.append(it)
        return out, stats["hand_crowning"] > 0 and any("hand" in k for k in stats)
    if word == "em":
        for it in v.get("data", []):
            i = it.get("i") or {}
            ie = (i.get("e") or "")
            if ie.strip().startswith("b，m和p开头的单词前）同en-Em-"):
                i2 = dict(i)
                i2["e"] = "Em- is a form of en- that is used before b-, m-, and p-."
                i2["c"] = "同en-（用于b、m和p开头的单词前）"
                it["i"] = i2
                stats["hand_em"] += 1
        return v.get("data", []), stats["hand_em"] > 0
    if word == "etc":
        # 查看句级：英文句 + 中文尾注
        for it in v.get("data", []):
            for g in it.get("g") or []:
                for s_ in g.get("s") or []:
                    e = (s_.get("e") or "").strip()
                    if e.startswith("etc is used at the end"):
                        m8 = re.search(r"([\u4e00-\u9fff][\u4e00-\u9fff\uff0c；;、。：\s]{1,})$", e)
                        if m8:
                            s_["c"] = (s_.get("c") or "") or m8.group(1).strip()
                            s_["e"] = e[:m8.start(1)].strip().rstrip(",；; ")
                            stats["hand_etc"] += 1
        return v.get("data", []), stats["hand_etc"] > 0
    return None, False

def apply_to_example(raw, word):
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

    if word in HAND_PATCH:
        patched, changed = hand_patch(word, v if isinstance(v, dict) else {"data": items})
        if changed:
            if isinstance(v, dict):
                v["data"] = patched
                return json.dumps(v, ensure_ascii=False, separators=(",", ":")), True
            return json.dumps(patched, ensure_ascii=False, separators=(",", ":")), True

    new_items = []
    changed = False
    for it in items:
        if not isinstance(it, dict):
            new_items.append(it)
            continue
        i = it.get("i")
        g = it.get("g")
        it_changed = False
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
                        keep_s = []
                        for grp in (g or []):
                            if isinstance(grp, dict):
                                for s_ in grp.get("s") or []:
                                    if isinstance(s_, dict) and (s_.get("e") or "").strip():
                                        keep_s.append(s_)
                        all_s = r["sents"] + keep_s
                        it = {"oid": it.get("oid", 0), "i": {"e": r["endef"], "c": r["c"] or old_c, "p": r["p"] or old_p},
                              "g": ([{"uid": 0, "u": "", "s": all_s}] if all_s else [])}
                    else:
                        i2 = dict(i)
                        i2["e"] = ""
                        i2["c"] = r["c"] or old_c
                        i2["p"] = r["p"] or old_p
                        it = {**it, "i": i2}
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
                        continue
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
                    it = {**it, "i": {"e": promote["endef"], "c": promote["c"], "p": promote["p"] or old_p},
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
            new, changed = apply_to_example(ex, word)
            if changed:
                updates.append((new, rid))
                if shown < 6:
                    samples[word] = (ex[:230], (new or "")[:230])
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
