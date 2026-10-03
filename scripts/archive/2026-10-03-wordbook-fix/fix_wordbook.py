# -*- coding: utf-8 -*-
"""词库修复器：对 wordbook.db 全量词条执行规则化修复。
用法: python fix_wordbook.py [--apply]   (默认 dry-run)

R1 音标规范化（kajweb→IPA、垃圾模板清除、CJK/标签截断）
R2 音标替换/回填（uk 损坏用 ECDICT 源替换；us 损坏置空；空 uk 回填源音标）
R3 释义残缺词性修复 (a../n.. → a./n.)
R4 空释义回填（ECDICT translation → definition）
R5 例句修复（双重编码展开、假释义 sense 剔除、无英文内容清除）
R6 全字段空串/空JSON → NULL 统一（bulk SQL）
R7 source 空 → merged_wordbank
R8 音频/图片 URL http→https
R9 main_word 引用修复（大小写对齐、逗号段解析、不可解析置空）
"""
import sqlite3
import json
import re
import sys
import pickle
from collections import Counter, defaultdict

DB = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\wordbook.db"
PKL = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\ecdict_index.pkl"
APPLY = "--apply" in sys.argv
CJK = re.compile(r"[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]")
LATIN = re.compile(r"[A-Za-z]")

stats = Counter()
samples = {}
def rec(rule, n=1, *sample):
    stats[rule] += n
    if sample and rule not in samples:
        samples[rule] = sample

IPA_VALID = re.compile(
    r"^[A-Za-zɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸ"
    r"θœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʑʒʡʔʕǀǁǂǃ"
    r"ˈˌːˑ˞ʰʱʲʷˠˤˬ̈̃ⁿˀ˖"
    r"()/.,;:·+\-\s]+$"
)
KAJWEB_MARK = re.compile(r"[әєε'`ˊ]")

def norm_pron(s):
    """返回 (新值 or None=清空, 标记)"""
    if s is None:
        return None, "none"
    t = s.strip()
    if t == "":
        return None, "empty"
    if re.fullmatch(r"英\s*\[[^\]]*\]\s*美\s*\[[^\]]*\]\s*", t):
        return None, "junk_template"
    # 先剥离 英/美 标签与括号
    t2 = re.sub(r"英\s*\[?|美\s*\[?", " ", t)
    if t2 != t:
        t = t2.strip()
    # CJK/分号截断
    m = re.match(r"^([^;；\u4e00-\u9fff]+)", t)
    seg = (m.group(1) if m else "").strip()
    if seg != t:
        rec("R1.pron_cjk_cut")
    t = seg.strip(" ,;·")
    if t == "":
        return None, "stripped_to_empty"
    kajweb = bool(KAJWEB_MARK.search(t) or t.startswith("."))
    if kajweb:
        t = (t.replace("ә", "ə").replace("є", "e").replace("ε", "e")
              .replace("'", "ˈ").replace("`", "ˈ").replace("ˊ", "ˈ")
              .replace(":", "ː").replace(".", "ˌ"))
        rec("R1.pron_kajweb_converted")
    t = t.replace("璻", "ɚ").replace("\xa0", " ")
    t = re.sub(r"\s+", " ", t).strip().strip("-").strip()
    if t == "":
        return None, "stripped"
    if CJK.search(t) or not IPA_VALID.match(t):
        return None, "invalid_after_norm"
    return t, ("kajweb" if kajweb else "clean")

def norm_ecdict_pron(p):
    if not p:
        return None
    t = p.strip().replace("ˊ", "ˈ").replace("璻", "ɚ").replace("\xa0", " ")
    t = re.sub(r"(?<=[ɑɐɒæəɚɛɜɝɞʌɔɪʊeio])\:(?=[ɑɐɒæəɚɛɜɝɞʌɔɪʊeio])", "ː", t)
    t = re.sub(r"\s+", " ", t).strip()
    if not t or CJK.search(t) or not IPA_VALID.match(t):
        return None
    return t

POS_TOKENS = "a|ad|n|v|vi|vt|adj|adv|abbr|pref|suf|comb|aux|conj|prep|pron|art|num|interj|int|det|modal"
POS_DOTS = re.compile(rf"(^|\n)(\s*)({POS_TOKENS})\.\.+(?=\s)", re.IGNORECASE)

def fix_interpret(s):
    if not s:
        return s
    new = POS_DOTS.sub(lambda m: f"{m.group(1)}{m.group(2)}{m.group(3).lower()}.", s)
    new = new.rstrip("\n\t ")
    if new != s:
        rec("R3.pos_dots_fixed", 1, s[:70], new[:70])
    return new

def deep_decode(s):
    s = (s or "").strip()
    if not s:
        return None, False
    try:
        v = json.loads(s)
    except Exception:
        return None, False
    double = isinstance(v, str)
    if double:
        try:
            v = json.loads(v)
        except Exception:
            return None, False
    return v, double

def has_any_latin_english(items):
    for it in items:
        if not isinstance(it, dict):
            continue
        i = it.get("i")
        if isinstance(i, dict) and LATIN.search(i.get("e") or ""):
            return True
        for g in it.get("g") or []:
            if not isinstance(g, dict):
                continue
            if LATIN.search(g.get("u") or ""):
                return True
            for s_ in g.get("s") or []:
                if isinstance(s_, dict) and LATIN.search(s_.get("e") or ""):
                    return True
    return False

def repair_senses(items):
    """R5b：i.e 为纯中文（释义塞进英文位）→ 挪到 i.c（中文位）；
    返回 (新列表, 移动数, 删除数)"""
    moved = 0
    dropped = 0
    out = []
    for it in items:
        if not isinstance(it, dict):
            dropped += 1
            continue
        i = it.get("i")
        if isinstance(i, dict):
            e = (i.get("e") or "").strip()
            if e and CJK.search(e) and not LATIN.search(e):
                c = (i.get("c") or "").strip()
                if c:
                    i["e"] = ""
                else:
                    i["c"] = e
                    i["e"] = ""
                moved += 1
        out.append(it)
    return out, moved, dropped

def fix_example(raw):
    """返回 (新值, 标记)；新值 None 表示清除/置 NULL"""
    if raw is None or raw.strip() == "":
        return None, None
    v, double = deep_decode(raw)
    if v is None:
        return None, "R5.undecodable_cleared"
    if isinstance(v, str):
        return None, "R5.undecodable_cleared"
    items = v.get("data") if isinstance(v, dict) else v
    if not isinstance(items, list):
        return None, "R5.odd_type_cleared"
    items, moved, dropped = repair_senses(items)
    if moved:
        rec("R5b.def_moved_e_to_c", moved)
    if dropped:
        rec("R5.bogus_sense_removed", dropped)
    if not items:
        return None, "R5.all_bogus_cleared"
    if not has_any_latin_english(items):
        return None, "R5.no_english_content_cleared"
    if isinstance(v, dict):
        v["data"] = items
        out = v
    else:
        out = items
    return json.dumps(out, ensure_ascii=False, separators=(",", ":")), ("R5.reserialized" if (moved or dropped or double) else None)

def main():
    with open(PKL, "rb") as f:
        ec = pickle.load(f)
    print(f"ecdict index: {len(ec)}")
    con = sqlite3.connect(DB)
    cur = con.cursor()

    exact_set = set()
    lower_map = {}
    cur.execute("SELECT word FROM words")
    while True:
        rows = cur.fetchmany(50000)
        if not rows:
            break
        for (w,) in rows:
            exact_set.add(w)
            lower_map.setdefault(w.lower(), w)

    by_field = defaultdict(list)  # field -> [(value, id)]
    def upd(field, rid, val):
        by_field[field].append((val, rid))

    cur.execute("SELECT id, word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, source FROM words")
    n = 0
    while True:
        rows = cur.fetchmany(10000)
        if not rows:
            break
        for (rid, word, main_word, interpret, uk, us, phrase, example, confuse, audio, image, source) in rows:
            n += 1
            src = ec.get(word.lower())
            src_pron = norm_ecdict_pron(src[1]) if src else None

            # R1/R2 音标
            if (uk is None or uk.strip() == "") and src_pron:
                upd("uk_pron", rid, src_pron)
                rec("R2.uk_backfilled", 1, word, "", src_pron)
            for field, val in (("uk_pron", uk), ("us_pron", us)):
                if val is None or val.strip() == "":
                    continue
                new, mark = norm_pron(val)
                if mark in ("none", "empty", "clean") and new == val:
                    continue
                if new is None:
                    if field == "uk_pron" and src_pron:
                        upd(field, rid, src_pron)
                        rec("R2.uk_bad_replaced_by_source", 1, word, val, src_pron)
                    else:
                        upd(field, rid, None)
                        rec("R2.pron_cleared", 1, word, val, field)
                elif new != val:
                    upd(field, rid, new)
                    rec("R1.pron_normalized", 1, word, val, new)

            # R3/R4 释义
            if interpret is None or interpret.strip() == "":
                cand = (src[3] if src else "") or ""
                if not cand.strip() and src:
                    cand = src[2] or ""
                cand = cand.strip()
                if cand:
                    upd("interpret", rid, fix_interpret(cand))
                    rec("R4.interpret_backfilled", 1, word, "", cand[:50])
            else:
                new_it = fix_interpret(interpret)
                if new_it != interpret:
                    upd("interpret", rid, new_it)

            # R5 例句
            new_ex, mark = fix_example(example)
            if mark:
                rec(mark, 1, word)
                upd("example", rid, new_ex)

            # R8 http→https
            for field, val in (("audio_urls", audio), ("image_urls", image)):
                if val and "http://" in val:
                    upd(field, rid, val.replace("http://", "https://"))
                    rec("R8.http_to_https", 1, word, field)

            # R9 main_word
            if main_word and main_word.strip():
                mw = main_word.strip()
                if mw not in exact_set:
                    target = lower_map.get(mw.lower())
                    if target:
                        upd("main_word", rid, target)
                        rec("R9.main_word_case_fixed", 1, word, mw, target)
                    else:
                        first = mw.split(",")[0].strip()
                        t2 = lower_map.get(first.lower())
                        if t2:
                            upd("main_word", rid, t2)
                            rec("R9.main_word_segment_fixed", 1, word, mw, t2)
                        else:
                            upd("main_word", rid, None)
                            rec("R9.main_word_dangling_cleared", 1, word, mw, "")

            # R7 source
            if source is None:
                upd("source", rid, "merged_wordbank")
                rec("R7.source_backfilled", 1, word)

    print(f"\nrows scanned: {n}; per-row updates by field:")
    for f, pairs in sorted(by_field.items()):
        print(f"  {f}: {len(pairs)}")
    print("\nrule stats:")
    for k, v in sorted(stats.items()):
        print(f"  {k}: {v}")
    print("\nsamples:")
    for k, s in sorted(samples.items()):
        print(f"  [{k}] {s}")

    if APPLY:
        con.execute("BEGIN")
        for f, pairs in by_field.items():
            cur.executemany(f"UPDATE words SET {f}=? WHERE id=?", pairs)
        # R6 bulk 空值统一：空串/空JSON → NULL
        for f, empties in [
            ("phrase", ("", "[]")), ("example", ("", "[]", "{}")), ("confuse", ("", "[]")),
            ("audio_urls", ("", "[]")), ("image_urls", ("", "[]")), ("word_root", ("", "[]", "{}")),
            ("interpret", ("",)), ("uk_pron", ("",)), ("us_pron", ("",)), ("main_word", ("",)),
            ("definition_en", ("",)), ("collins", ("",)), ("oxford", ("",)),
            ("bnc", ("",)), ("frq", ("",)), ("exchange", ("",)), ("tag", ("",)),
        ]:
            ph = ",".join("?" * len(empties))
            c = cur.execute(f"UPDATE words SET {f}=NULL WHERE {f} IN ({ph})", empties).rowcount
            if c:
                print(f"R6 {f} empty→NULL: {c}")
        con.commit()
        print("APPLIED & COMMITTED")
    else:
        print("\nDRY RUN (pass --apply to commit)")
    con.close()

if __name__ == "__main__":
    main()
