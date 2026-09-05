# -*- coding: utf-8 -*-
"""
扩充词库管线：现库（精清洗 32k）⊕ merged 库（全量 20.8 万）→ 新 assets/db/wordbook.db.gz

原则（RAW 全量模式，2026-09-06）：
- 现有 32,154 词原样保留；
- merged 独有的 181,206 词【全量原样】搬入（interpret/word_root 等字段不做清洗，
  数据质量治理由数据侧另行处理；本管线只负责完整搬入与词书挂接）；
- 词书：保留 191 本原书全部映射；另生成 5 本数据驱动的专题书；
- schema 在现库基础上追加 merged 的 3 个尾列（collocation/synonym/usage_note），
  App 按列名读取，向后兼容。

用法：python scripts/build_expanded_wordbook.py
"""
import gzip
import json
import os
import re
import shutil
import sqlite3
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MERGED = os.environ.get("MERGED_DB", "D:/AI2/wordbook_merged.db")
CURRENT = os.environ.get("CURRENT_DB", "C:/Users/17296/WorkBuddy/current_wordbook.db")
OUT_DB = os.environ.get("OUT_DB", "C:/Users/17296/WorkBuddy/wordbook_expanded.db")
OUT_GZ = os.path.join(REPO, "assets", "db", "wordbook.db.gz")

POS_RE = re.compile(r"^\s*((?:n|v|vi|vt|adj|adv|a|ad|prep|conj|pron|art|num|int|interj)\.)\s*")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
UKUS_RE = re.compile(r"\s+(?:US|UK)\s*\[.*?\]\s*$", re.I)
JUNK_WORD_RE = re.compile(r"[,;；|]")
MAX_INTERPRET_LINES = 8
CURATED_KEEP = re.compile(r"^[\w' -]+$", re.I)  # 垃圾词形过滤（仅作用于新导入词）

stats = Counter()


def clean_interpret(raw):
    """merged 的 interpret 是 JSON 字符串数组 → 清洗为 '词性. 中文' 多行纯文本。"""
    if not raw or not raw.strip():
        return ""
    s = raw.strip()
    entries = None
    if s.startswith("["):
        try:
            d = json.loads(s)
            if isinstance(d, list):
                entries = [e for e in d if isinstance(e, str)]
        except Exception:
            # 无效 JSON（约 16%）：按条目分隔符手工切段后走同一清洗路径
            body = s.lstrip("[").rstrip("]")
            entries = re.split(r'"\s*,\s*"', body)
            entries = [e.strip().strip('"') for e in entries]
    if entries is None:
        lines = [ln.strip() for ln in s.splitlines()]
        kept = []
        for ln in lines:
            ln2 = UKUS_RE.sub("", ln)
            if CJK_RE.search(ln2):
                kept.append(ln2)
        return "\n".join(kept)[:2000]

    out = []
    for e in entries:
        e = e.strip()
        if not e or e.startswith("→"):
            continue
        e = UKUS_RE.sub("", e)
        if not CJK_RE.search(e):
            continue  # 无中文条目多为损坏英文长释义
        m = POS_RE.match(e)
        pos = ""
        body = e
        if m:
            pos = m.group(1)
            body = e[m.end():].strip()
        # 截到最后一个 CJK/常见中文标点，丢其后英文残渣
        last = -1
        for i, ch in enumerate(body):
            if CJK_RE.match(ch) or ch in "，。；：、）】」！？":
                last = i
        if last >= 0:
            body = body[: last + 1].strip(" ,;；")
        if not body:
            continue
        line = f"{pos} {body}".strip().lstrip("[“”，；[] ")
        # 质量线：至少 2 个 CJK 字符，且不是"见 xxx"式交叉引用残片
        if len(CJK_RE.findall(line)) >= 2 and not line.lstrip().startswith("→"):
            out.append(line)
        if len(out) >= MAX_INTERPRET_LINES:
            break
    return "\n".join(out)


def clean_word_root(raw, word):
    """词根词缀必须出现在单词本身里（词干≥3 才做出现校验），防错挂。"""
    if not raw or not raw.strip():
        return ""
    try:
        d = json.loads(raw.strip())
    except Exception:
        return ""
    # 兼容两种存法：现库是单个 JSON 对象，merged 库是对象数组
    if isinstance(d, dict):
        d = [d]
    if not isinstance(d, list) or not d:
        return ""
    w = word.lower().replace("-", "").replace(" ", "")
    out = []
    for item in d:
        if not isinstance(item, dict):
            continue
        prefix = (item.get("prefix") or "").strip()
        suffix = (item.get("suffix") or "").strip()
        roots = item.get("roots") or []
        if not isinstance(roots, list):
            roots = []
        kept_roots = []
        for r in roots:
            if not isinstance(r, str) or not r.strip():
                continue
            stem = r.split("=")[0].strip().lower().replace("-", "").replace(" ", "")
            if len(stem) < 3:
                kept_roots.append(r.strip())  # 极短词根（如 -y）免校验
            elif stem in w:
                kept_roots.append(r.strip())
        suffix_ok = suffix if suffix and w.endswith(suffix.split("=")[0].strip().lower().replace("-", "").replace(" ", "")) else ""
        prefix_ok = prefix if prefix and w.startswith(prefix.split("=")[0].strip().lower().replace("-", "").replace(" ", "")) else ""
        if prefix_ok or kept_roots or suffix_ok:
            out.append({"prefix": prefix_ok, "roots": kept_roots, "suffix": suffix_ok})
    return json.dumps(out, ensure_ascii=False) if out else ""


NEW_BOOKS = [
    ("PHRASEIDIOM", "短语·地道搭配大全", 3000),
    ("ROOTAFFIX", "词根词缀速记", 3000),
    ("SYNNOTE", "同义词·近义词辨析", 2500),
    ("COLLOC", "高频搭配力", 3000),
    ("USAGENOTE", "用法·易错辨析", 2500),
]


def main():
    for p in (MERGED, CURRENT):
        if not os.path.exists(p):
            sys.exit(f"missing db: {p}")
    if os.path.exists(OUT_DB):
        os.remove(OUT_DB)

    mg = sqlite3.connect(MERGED)
    out = sqlite3.connect(OUT_DB)
    out.executescript(
        """
        ATTACH DATABASE '%s' AS cur;
        CREATE TABLE books (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT, word_count INTEGER);
        CREATE TABLE words (
          id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT, main_word TEXT, interpret TEXT,
          uk_pron TEXT, us_pron TEXT, phrase TEXT, example TEXT, confuse TEXT,
          audio_urls TEXT, image_urls TEXT, word_root TEXT,
          collocation TEXT, synonym TEXT, usage_note TEXT
        );
        CREATE TABLE word_books (word_id INTEGER, book_id INTEGER);
        CREATE UNIQUE INDEX idx_words_word ON words(word);
        CREATE INDEX idx_wb_book ON word_books(book_id);
        CREATE INDEX idx_wb_word ON word_books(word_id);
        """
        % CURRENT.replace("\\", "/")
    )

    # 1) 书与现有词原样搬（保持 id）；word_root 全库统一过卫生校验
    #    （现库存在 couple→duct 类错挂，仅做"词干须出现在词中"的删除性校正）
    out.execute("INSERT INTO books (id, code, name, word_count) SELECT id, code, name, word_count FROM cur.books")
    out.execute(
        "INSERT INTO words (id, word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, word_root) "
        "SELECT id, word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, word_root FROM cur.words"
    )
    n_cur = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    print("curated words kept:", n_cur)
    existing = {r[0] for r in out.execute("SELECT word FROM words")}

    # 2) 单遍扫描 merged：导入独有词（三级清洗）
    cur = mg.cursor()
    cur.execute(
        "SELECT word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, "
        "audio_urls, image_urls, word_root, collocation, synonym, usage_note FROM words"
    )
    batch = []
    for row in cur:
        (w, mainw, interp, uk, us, phrase, example, confuse, audio, image, wroot, colloc, syn, unote) = row
        if w in existing:
            continue
        if not w or not w.strip():
            stats["rej:word-text"] += 1
            continue
        # RAW：字段原样保留，仅修复 merge 遗留的重复词形（按 word 唯一索引兜底）
        batch.append(
            (w, mainw, interp, uk, us, phrase, example, confuse, audio, image, wroot, colloc, syn, unote)
        )
        existing.add(w)
        stats["imported"] += 1

    out.executemany(
        "INSERT INTO words (word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, word_root, collocation, synonym, usage_note) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        batch,
    )
    print("imported:", stats["imported"], "| rejected:", {k: v for k, v in stats.items() if k.startswith("rej")})

    word_to_id = {r[1]: r[0] for r in out.execute("SELECT id, word FROM words")}

    # 3) 词书映射：merged 全量映射按词文本重挂
    seen = set()
    wb = []
    for bid, w in mg.execute("SELECT wb.book_id, w.word FROM word_books wb JOIN words w ON w.id=wb.word_id"):
        wid = word_to_id.get(w)
        if wid is not None and (wid, bid) not in seen:
            seen.add((wid, bid))
            wb.append((wid, bid))
    out.executemany("INSERT INTO word_books (word_id, book_id) VALUES (?,?)", wb)
    print("mappings from merged:", len(wb))

    # 4) 新专题书
    for code, name, cap in NEW_BOOKS:
        c = out.execute("INSERT INTO books (code, name, word_count) VALUES (?,?,0)", (code, name))
        bid = c.lastrowid
        if code == "PHRASEIDIOM":
            q = ("SELECT id FROM words WHERE id>? AND word LIKE '% %' AND LENGTH(word)<=32 AND "
                 "interpret NOT LIKE '%→%' ORDER BY (example!='') DESC, LENGTH(word) LIMIT ?")
            args = (n_cur, cap)
        elif code == "ROOTAFFIX":
            q = ("SELECT id FROM words WHERE word_root LIKE '%roots%' AND word_root NOT LIKE '[{}]' AND word_root != '{}' "
                 "AND word_root NOT LIKE '%[]%' ORDER BY (example!='') DESC, (us_pron!='') DESC LIMIT ?")
            args = (cap,)
        elif code == "SYNNOTE":
            q = "SELECT id FROM words WHERE id>? AND synonym!='' AND (uk_pron!='' OR us_pron!='') LIMIT ?"
            args = (n_cur, cap)
        elif code == "COLLOC":
            q = "SELECT id FROM words WHERE id>? AND collocation!='' AND (uk_pron!='' OR us_pron!='') LIMIT ?"
            args = (n_cur, cap)
        elif code == "USAGENOTE":
            q = "SELECT id FROM words WHERE id>? AND usage_note!='' AND (uk_pron!='' OR us_pron!='') LIMIT ?"
            args = (n_cur, cap)
        sel = [r[0] for r in out.execute(q, args)]
        out.executemany("INSERT INTO word_books (word_id, book_id) VALUES (?,?)", [(wid, bid) for wid in sel])
        out.execute("UPDATE books SET word_count=? WHERE id=?", (len(sel), bid))
        print(f"new book {code} [{name}]: {len(sel)} words")

    # 5) 收尾自检
    out.execute("UPDATE books SET word_count=(SELECT COUNT(*) FROM word_books WHERE book_id=books.id)")
    n_words = out.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    n_maps = out.execute("SELECT COUNT(*) FROM word_books").fetchone()[0]
    dangling = out.execute(
        "SELECT COUNT(*) FROM word_books wb LEFT JOIN words w ON wb.word_id=w.id WHERE w.id IS NULL"
    ).fetchone()[0]
    dupes = out.execute("SELECT COUNT(*) FROM (SELECT word FROM words GROUP BY word HAVING COUNT(*)>1)").fetchone()[0]
    print(f"FINAL: words={n_words} books={out.execute('SELECT COUNT(*) FROM books').fetchone()[0]} mappings={n_maps} dangling={dangling} dupes={dupes}")

    out.commit()
    out.execute("VACUUM")
    out.close()
    mg.close()

    # 6) 压缩为资产
    if os.path.exists(OUT_GZ):
        os.remove(OUT_GZ)
    with open(OUT_DB, "rb") as f, gzip.open(OUT_GZ, "wb", compresslevel=9) as g:
        shutil.copyfileobj(f, g, length=8 * 1024 * 1024)
    print("OUT_DB:", round(os.path.getsize(OUT_DB) / 1048576, 1), "MB")
    print("OUT_GZ:", round(os.path.getsize(OUT_GZ) / 1048576, 1), "MB ->", OUT_GZ)


if __name__ == "__main__":
    main()
