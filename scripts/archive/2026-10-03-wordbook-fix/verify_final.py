# -*- coding: utf-8 -*-
"""修复后终验：按最终数据契约全量校验 771,251 词条。
契约：
  C1 所有文本字段：NULL 或 有效内容，不允许 ''
  C2 interpret：非空时为可读文本（纯文本/领域标签），首行词性无重复句点
  C3 uk_pron/us_pron：NULL 或 通过 IPA 白名单
  C4 phrase/confuse/audio_urls/image_urls：NULL 或 合法 JSON 数组
  C5 word_root：NULL 或 合法 JSON
  C6 example：NULL 或 合法 JSON（单层），e/eo/en 槽无中文（白名单 30 条豁免）
  C7 main_word：NULL 或 精确指向库内词
  C8 source：非 NULL
  C9 audio_urls/image_urls：无 http:// 明文
  C10 词书映射无孤儿、books.word_count 与实际一致
"""
import sqlite3
import json
import re
from collections import Counter

DB = r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\.zwork\audit\wordbook.db"
CJK = re.compile(r"[\u4e00-\u9fff]")
LATIN = re.compile(r"[A-Za-z]")
IPA = re.compile(
    r"^[A-Za-zɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸ"
    r"θœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʑʒʡʔʕǀǁǂǃ"
    r"ˈˌːˑ˞ʰʱʲʷˠˤˬˮ̈̃‍ⁿˀ˖ Ιʰ()/.,;:|·‐-―+\-\s\xa0]+$"
)
POS_DOTS = re.compile(r"(^|\n)(\s*)(n|v|vi|vt|adj|adv|a|ad|prep|conj|pron|art|num|interj|int|abbr|suf|pref|comb|aux|det|modal)\.\.", re.IGNORECASE)
ALLOWED_CJK_E = {
    "CEO", "ATM", "GDP", "am", "search for", "DNA", "PC", "PM", "GNP", "IQ", "LCD", "UFO",
    "exec", "gal", "ADHD", "CFC", "CPU", "MP", "MRI", "PDA", "PVC", "RNA", "TNT", "VIP",
    "simplified", "PhD", "etc", "mba", "code",
}

fails = Counter()
samples = {}

def fail(code, word, detail=""):
    fails[code] += 1
    if len(samples.get(code, [])) < 5:
        samples.setdefault(code, []).append((word, str(detail)[:100]))

con = sqlite3.connect(DB)
cur = con.cursor()

words_set = set()
cur.execute("SELECT word FROM words")
while True:
    rows = cur.fetchmany(50000)
    if not rows:
        break
    for (w,) in rows:
        words_set.add(w)

cur.execute("SELECT id, word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, word_root, source FROM words")
n = 0
while True:
    rows = cur.fetchmany(10000)
    if not rows:
        break
    for (rid, word, main_word, interpret, uk, us, phrase, example, confuse, audio, image, root, source) in rows:
        n += 1
        # C1
        for f, v in (("main_word", main_word), ("interpret", interpret), ("uk_pron", uk), ("us_pron", us),
                     ("phrase", phrase), ("example", example), ("confuse", confuse),
                     ("audio_urls", audio), ("image_urls", image), ("word_root", root), ("source", source)):
            if v is not None and isinstance(v, str) and v.strip() == "":
                fail(f"C1.empty_{f}", word)
        # C2
        if interpret is not None:
            if interpret.strip() == "":
                fail("C2.interpret_blank", word)
            elif POS_DOTS.search(interpret):
                fail("C2.pos_dots", word, interpret[:60])
        # C3
        for f, v in (("uk", uk), ("us", us)):
            if v is not None and not IPA.match(v):
                fail(f"C3.pron_{f}", word, v)
        # C4
        for f, v in (("phrase", phrase), ("confuse", confuse), ("audio_urls", audio), ("image_urls", image)):
            if v is not None:
                try:
                    pv = json.loads(v)
                    if not isinstance(pv, list):
                        fail(f"C4.{f}_not_list", word, v[:60])
                except Exception:
                    fail(f"C4.{f}_bad_json", word, v[:60])
        # C5
        if root is not None:
            try:
                json.loads(root)
            except Exception:
                fail("C5.word_root_bad_json", word, root[:60])
        # C6
        if example is not None:
            try:
                ev = json.loads(example)
            except Exception:
                fail("C6.example_bad_json", word, example[:60])
                ev = None
            if isinstance(ev, str):
                fail("C6.example_double_encoded", word)
                try:
                    ev = json.loads(ev)
                except Exception:
                    ev = None
            if isinstance(ev, (dict, list)):
                items = ev.get("data") if isinstance(ev, dict) else ev
                if not isinstance(items, list):
                    fail("C6.example_no_data_list", word)
                else:
                    for it in items:
                        if not isinstance(it, dict):
                            continue
                        i2 = it.get("i") or {}
                        for k in ("e", "eo", "en"):
                            v2 = (i2.get(k) or "").strip()
                            if v2 and CJK.search(v2) and word not in ALLOWED_CJK_E:
                                fail("C6.cjk_in_english_def", word, v2)
                        for g in it.get("g") or []:
                            if not isinstance(g, dict):
                                continue
                            for s_ in g.get("s") or []:
                                if not isinstance(s_, dict):
                                    continue
                                v3 = (s_.get("e") or "").strip()
                                if v3 and CJK.search(v3) and word not in ALLOWED_CJK_E:
                                    fail("C6.cjk_in_english_sentence", word, v3)
        # C7
        if main_word is not None and main_word not in words_set:
            fail("C7.main_word_dangling", word, main_word)
        # C8
        if source is None:
            fail("C8.source_null", word)
        # C9
        for f, v in (("audio_urls", audio), ("image_urls", image)):
            if v and "http://" in v:
                fail(f"C9.{f}_http", word)

print(f"rows verified: {n}")
if fails:
    print("FAILURES:")
    for k, c in fails.most_common():
        print(f"  {k}: {c}  e.g. {samples[k][:3]}")
else:
    print("ALL CONTRACT CHECKS PASSED")

# C10
orphans = cur.execute("SELECT COUNT(*) FROM word_books wb LEFT JOIN words w ON w.id=wb.word_id WHERE w.id IS NULL").fetchone()[0]
orphan_books = cur.execute("SELECT COUNT(*) FROM word_books wb LEFT JOIN books b ON b.id=wb.book_id WHERE b.id IS NULL").fetchone()[0]
mm = cur.execute("SELECT COUNT(*) FROM (SELECT b.id FROM books b LEFT JOIN word_books wb ON wb.book_id=b.id GROUP BY b.id HAVING b.word_count != COUNT(wb.word_id))").fetchone()[0]
print(f"C10: orphan_word_refs={orphans} orphan_book_refs={orphan_books} wordcount_mismatch={mm}")
print("integrity:", cur.execute("PRAGMA integrity_check").fetchone()[0])
con.close()
