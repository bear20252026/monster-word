# -*- coding: utf-8 -*-
"""
全量词库导入管线（用户批准"全部采纳"）：

目标库 = 现 App 库（32,154 精修词原样保留，id 不变）
       + ECDICT 全部词条（77 万，MIT 许可）
       + kajweb/dict 81 本词书全部词条与词书映射

字段映射：
- ECDICT.phonetic → uk_pron；translation → interpret（多行，与 App 风格一致）；
  definition → definition_en 新列；collins/oxford/bnc/frq/exchange/tag → 新列存储
- kajweb: trans → interpret 多行；sentences → 合成 App ExampleParser 兼容的
  {"v":1,"data":[...]} example；phrases → PhraseParser 兼容 JSON

质量底线：word 大小写不敏感去重；ECDICT 无中文释义的条目跳过
（App 为中文学习界面，纯英文条目无法展示）。

用法：python scripts/build_full_wordbook.py
"""
import gzip
import json
import os
import re
import shutil
import sqlite3
import sys
import zipfile
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURRENT = os.environ.get("CURRENT_DB", "C:/Users/17296/WorkBuddy/current_wordbook.db")
ECDICT_CSV = os.environ.get("ECDICT_CSV", "C:/Users/17296/WorkBuddy/2026-08-29-23-03-07/data-survey/ECDICT/ecdict.csv")
KAJWEB_DIR = os.environ.get("KAJWEB_DIR", "C:/Users/17296/WorkBuddy/2026-08-29-23-03-07/data-survey/kajweb-dict/book")
OUT_DB = os.environ.get("OUT_DB", "C:/Users/17296/WorkBuddy/wordbook_full.db")
OUT_GZ = os.path.join(REPO, "assets", "db", "wordbook.db.gz")

CJK = re.compile(r"[\u4e00-\u9fff]")

NAME_MAP = {
    "CET4": "四级词汇", "CET4luan": "四级词汇 · 乱序",
    "CET6": "六级词汇", "CET6luan": "六级词汇 · 乱序",
    "KaoYan": "考研词汇", "KaoYanluan": "考研词汇 · 乱序",
    "IELTS": "雅思词汇", "IELTSluan": "雅思词汇 · 乱序",
    "TOEFL": "托福词汇",
    "GRE": "GRE 词汇", "GMAT": "GMAT 词汇", "SAT": "SAT 词汇",
    "BEC": "BEC 商务词汇",
    "Level4": "专四词汇", "Level8": "专八词汇",
    "ChuZhong": "初中词汇", "ChuZhongluan": "初中词汇 · 乱序",
    "GaoZhong": "高中词汇", "GaoZhongluan": "高中词汇 · 乱序",
    "BeiShiGaoZhong": "北师大高中词汇", "PEPGaoZhong": "人教高中词汇",
    "PEPChuZhong": "人教初中词汇", "PEPXiaoXue": "人教小学词汇",
    "WaiYanSheChuZhong": "外研社初中词汇",
}

stats = Counter()


def kajweb_stem(filename):
    stem = os.path.splitext(filename)[0]
    stem = re.sub(r"^reciteWord_\d+_", "", stem)
    stem = re.sub(r"^\d+_", "", stem)
    return stem


def kajweb_book_name(stem):
    m = re.match(r"^([A-Za-z]+?)(\d*)$", stem)
    if not m:
        return stem
    base, num = m.group(1), m.group(2)
    base_name = NAME_MAP.get(base, base)
    return f"{base_name} {num}" if num else base_name


def main():
    for p in (CURRENT, ECDICT_CSV, KAJWEB_DIR):
        if not os.path.exists(p):
            sys.exit(f"missing: {p}")
    if os.path.exists(OUT_DB):
        os.remove(OUT_DB)

    out = sqlite3.connect(OUT_DB)
    out.executescript(
        """
        ATTACH DATABASE '%s' AS cur;
        CREATE TABLE books (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT, word_count INTEGER);
        CREATE TABLE words (
          id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT, main_word TEXT, interpret TEXT,
          uk_pron TEXT, us_pron TEXT, phrase TEXT, example TEXT, confuse TEXT,
          audio_urls TEXT, image_urls TEXT, word_root TEXT
        );
        CREATE TABLE word_books (word_id INTEGER, book_id INTEGER);
        CREATE UNIQUE INDEX idx_words_word ON words(word);
        CREATE INDEX idx_wb_book ON word_books(book_id);
        CREATE INDEX idx_wb_word ON word_books(word_id);
        """
        % CURRENT.replace("\\", "/")
    )

    # 1) 现库原样搬入（权威：id/精修字段/191 本书/映射全保留）
    out.execute("INSERT INTO books SELECT * FROM cur.books")
    out.execute("INSERT INTO words SELECT * FROM cur.words")
    out.execute("INSERT INTO word_books SELECT * FROM cur.word_books")
    # 追加 ECDICT/kajweb 数据的扩展列（App 按列名读取，多余列无影响）
    for col in ("definition_en", "collins", "oxford", "bnc", "frq", "exchange", "tag", "source"):
        out.execute(f"ALTER TABLE words ADD COLUMN {col} TEXT")
    n_base = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    print(f"base words: {n_base}, base books: {out.execute('SELECT COUNT(*) FROM books').fetchone()[0]}")

    # 2) ECDICT 全量导入
    import csv

    seen = set()
    batch = []
    with open(ECDICT_CSV, encoding="utf-8") as f:
        rdr = csv.reader(f)
        header = next(rdr)
        ix = {k: header.index(k) for k in
              ("word", "phonetic", "definition", "translation", "collins", "oxford", "bnc", "frq", "exchange", "tag")}

        def _int(col):
            v = (row[ix[col]] or "").strip()
            return int(v) if v.isdigit() else None

        for row in rdr:
            w = (row[ix["word"]] or "").strip()
            if not w or len(w) > 60 or "\n" in w:
                stats["rej:word"] += 1
                continue
            key = w.lower()
            if key in seen:
                continue
            seen.add(key)
            tr = (row[ix["translation"]] or "").strip()
            if not CJK.search(tr):
                stats["rej:no-cn"] += 1
                continue

            def _int2(col):
                v = (row[ix[col]] or "").strip()
                return int(v) if v.isdigit() else None

            batch.append((
                w, "", tr,
                (row[ix["phonetic"]] or "").strip(), "",
                "", "", "", "", "", "",
                (row[ix["definition"]] or "").strip(),
                _int2("collins"), _int2("oxford"), _int2("bnc"), _int2("frq"),
                (row[ix["exchange"]] or "").strip(), (row[ix["tag"]] or "").strip(),
                "ecdict",
            ))
            stats["ecdict"] += 1

    before = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    out.executemany(
        "INSERT OR IGNORE INTO words (word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse,"
        " audio_urls, image_urls, word_root, definition_en, collins, oxford, bnc, frq, exchange, tag, source)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        batch,
    )
    after = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    stats["ecdict_kept"] = after - before
    print("ECDICT inserted:", after - before, "| attempted:", stats["ecdict"], "| rejected:", stats["rej:word"] + stats["rej:no-cn"])

    word_to_id = {r[1]: r[0] for r in out.execute("SELECT id, word FROM words")}

    # 3) kajweb 全量导入（词条原样 + App 兼容合成）
    kw_files = sorted(fn for fn in os.listdir(KAJWEB_DIR) if fn.endswith(".zip"))
    batch = []
    for fn in kw_files:
        zf = zipfile.ZipFile(os.path.join(KAJWEB_DIR, fn))
        for line in zf.read(zf.namelist()[0]).decode("utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                stats["kajweb_bad"] += 1
                continue
            head = (rec.get("headWord") or "").strip()
            if not head or head.lower() in seen:
                continue
            content = rec.get("content") or {}
            wc = (content.get("word") or {})
            c = wc.get("content") or {}
            trans = [(t.get("pos") or "", t.get("tranCn") or "") for t in (wc.get("trans") or []) if isinstance(t, dict)]
            interp = "\n".join(f"{p}. {cn}".strip() for p, cn in trans if cn)
            sents = (c.get("sentence") or {}).get("sentences", []) or []
            ex_data = [{"oid": i, "type": 1,
                        "i": {"e": s.get("sContent", ""), "c": s.get("sCn", ""), "p": "", "t": "NORMAL"},
                        "g": []} for i, s in enumerate(sents)]
            example = json.dumps({"v": 1, "data": ex_data}, ensure_ascii=False) if ex_data else ""
            ph_list = (wc.get("phrase") or {}).get("phrases", []) or []
            ph = [{"t": 0, "p": [{"en": (p.get("pContent") or "").strip(), "cn": p.get("pCn") or ""}]}
                  for p in ph_list if isinstance(p, dict)]
            phrase = json.dumps(ph, ensure_ascii=False) if ph else ""
            batch.append((
                head, (wc.get("wordContent") or ""), interp,
                (c.get("ukphone") or "").strip(), (c.get("usphone") or "").strip(),
                phrase, example, "", "", "", "", "", "", "", "", "", "", "", "kajweb",
            ))
            seen.add(head.lower())
            stats["kajweb"] += 1

    before_kw = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    out.executemany(
        "INSERT OR IGNORE INTO words (word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse,"
        " audio_urls, image_urls, word_root, definition_en, collins, oxford, bnc, frq, exchange, tag, source)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        batch,
    )
    after_kw = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    stats["kajweb_kept"] = after_kw - before_kw
    print("kajweb inserted:", after_kw - before_kw, "| attempted:", stats["kajweb"])

    word_to_id = {r[1]: r[0] for r in out.execute("SELECT id, word FROM words")}

    # 4) kajweb 81 本词书：映射 + 中文命名 + 分组
    for fn in kw_files:
        stem = kajweb_stem(fn)
        zf = zipfile.ZipFile(os.path.join(KAJWEB_DIR, fn))
        heads = set()
        for line in zf.read(zf.namelist()[0]).decode("utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            h = (rec.get("headWord") or "").strip()
            if h:
                heads.add(h.lower())
        c = out.execute("INSERT INTO books (code, name, word_count) VALUES (?,?,0)",
                        (f"KJW_{stem}", kajweb_book_name(stem)))
        bid = c.lastrowid
        mappings = [(word_to_id[h], bid) for h in heads if h in word_to_id]
        out.executemany("INSERT INTO word_books (word_id, book_id) VALUES (?,?)", mappings)
        out.execute("UPDATE books SET word_count=? WHERE id=?", (len(mappings), bid))
        print(f"  book {stem}: {len(mappings)} words")

    # 5) 收尾自检
    out.execute("UPDATE books SET word_count=(SELECT COUNT(*) FROM word_books WHERE book_id=books.id)")
    n_words = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    n_books = out.execute("SELECT COUNT(*) FROM books").fetchone()[0]
    n_maps = out.execute("SELECT COUNT(*) FROM word_books").fetchone()[0]
    dangling = out.execute(
        "SELECT COUNT(*) FROM word_books wb LEFT JOIN words w ON wb.word_id=w.id WHERE w.id IS NULL").fetchone()[0]
    dupes = out.execute("SELECT COUNT(*) FROM (SELECT word FROM words GROUP BY word HAVING COUNT(*)>1)").fetchone()[0]
    print(f"FINAL: words={n_words} books={n_books} mappings={n_maps} dangling={dangling} dupes={dupes}")

    out.commit()
    out.execute("VACUUM")
    out.close()

    # 6) 压缩为 App 资产
    if os.path.exists(OUT_GZ):
        os.remove(OUT_GZ)
    with open(OUT_DB, "rb") as f, gzip.open(OUT_GZ, "wb", compresslevel=9) as g:
        shutil.copyfileobj(f, g, length=8 * 1024 * 1024)
    print("OUT_DB:", round(os.path.getsize(OUT_DB) / 1048576, 1), "MB")
    print("OUT_GZ:", round(os.path.getsize(OUT_GZ) / 1048576, 1), "MB ->", OUT_GZ)


if __name__ == "__main__":
    main()
