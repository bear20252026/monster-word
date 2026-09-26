#!/usr/bin/env python3
"""Sentence gap backfill: write Tatoeba + pool-A candidates into a staged wordbook.db.

Non-destructive contract (same as apply_anki_supplement.py):
- only fills words whose `example` column is empty; never overwrites existing values
- writes by primary key id in small batches
- example JSON shape validated against the app's ExampleParser contract:
  {"v":1,"data":[{"oid":1,"i":{"e":"","c":"","p":""},"g":[{"uid":0,"u":"","s":[...]}]}]}
  s[] items: {"eid":<int>,"e":"... <b>word</b> ...","c":"中文","b":"来源"[,"u":"audio url"]}

Inputs (produced by tatoeba_match.py / tatoeba_full.py / audit step):
- candidates JSON: {lower_word: [[en, zh], ...]}
- optional pool JSON with audio: {word: [{"en","cn","audio","src"}, ...]}
- gap list JSON: [[id, word, main_word], ...]
"""
from __future__ import annotations

import argparse
import gzip
import json
import re
import shutil
import sqlite3
import tempfile
from pathlib import Path

AUDIO_URL = "http://audio.beingfine.cn/sentence/audio/{}.mp3"
TOK = re.compile(r"[a-z]+(?:'[a-z]+)*")
AUDIO_OK = re.compile(r"\d+\.mp3$")


def highlight(en: str, word: str) -> str:
    """Wrap the first word-boundary occurrence of `word` in <b></b>; best effort."""
    toks = tuple(t for t in re.split(r"[^a-z']+", word.lower()) if t)
    if not toks:
        return en
    low = en.lower()
    if len(low) != len(en):  # exotic unicode casing — skip highlighting
        return en
    spans = [(m.start(), m.end()) for m in TOK.finditer(low)]
    toks_in_line = [low[s:e] for s, e in spans]
    n = len(toks)
    for i in range(len(spans) - n + 1):
        if tuple(toks_in_line[i:i + n]) == toks:
            s, e = spans[i][0], spans[i + n - 1][1]
            return f"{en[:s]}<b>{en[s:e]}</b>{en[e:]}"
    return en


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, required=True, help="wordbook.db.gz (staged copy is modified)")
    ap.add_argument("--candidates", type=Path, required=True)
    ap.add_argument("--pool", type=Path, default=None, help="sentences_from_mapping.json (with audio)")
    ap.add_argument("--gap", type=Path, required=True, help="remaining_gap.json [[id, word, main_word]]")
    ap.add_argument("--output", type=Path, required=True, help="output .db.gz")
    ap.add_argument("--per-word", type=int, default=4)
    args = ap.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    cands = {k.lower(): v for k, v in json.load(open(args.candidates, encoding="utf-8")).items()}
    pool = {}
    if args.pool and args.pool.exists():
        pool = {k.lower(): v for k, v in json.load(open(args.pool, encoding="utf-8")).items()}
    gap = json.load(open(args.gap, encoding="utf-8"))

    # decide fills in memory first
    # candidates JSON: {lower_word: [[en, zh, source], ...]}  (priority-ordered)
    fills = {}  # id -> example json text
    eid = 1
    n_tat = n_pool = 0
    for wid, word, _mw in gap:
        lw = word.lower().strip()
        rows = []
        for e in (pool.get(lw) or [])[: args.per_word]:
            audio = e.get("audio") or ""
            audio = AUDIO_URL.format(audio[:-4]) if AUDIO_OK.search(audio) else None
            rows.append((highlight(e.get("en", ""), lw), e.get("cn", ""), e.get("src", "") or "原生句库", audio))
        for en, zh, src in (cands.get(lw) or [])[: args.per_word]:
            rows.append((highlight(en, lw), zh, src, None))
        rows = rows[: args.per_word]
        if not rows:
            continue
        if any(r[3] for r in rows):
            n_pool += 1
        if cands.get(lw):
            n_tat += 1
        s_arr, seen = [], set()
        for en, zh, src, audio in rows:
            if en.lower() in seen:
                continue
            seen.add(en.lower())
            item = {"eid": eid, "e": en, "c": zh, "b": src}
            if audio:
                item["u"] = audio
            eid += 1
            s_arr.append(item)
        obj = {"v": 1,
               "data": [{"oid": 1, "i": {"e": "", "c": "", "p": ""},
                         "g": [{"uid": 0, "u": "", "s": s_arr}]}]}
        fills[wid] = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    print(f"[plan] fill rows={len(fills)} (words touched: tatoeba={n_tat}, pool={n_pool})", flush=True)

    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "wordbook.db"
        with gzip.open(args.db, "rb") as src, raw.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        db = sqlite3.connect(raw)
        db.execute("PRAGMA journal_mode=OFF")
        before = db.execute(
            "SELECT COUNT(*) FROM words WHERE example IS NULL OR example=''").fetchone()[0]
        # safety: never overwrite a row that gained content meanwhile
        empty_ids = {r[0] for r in db.execute(
            "SELECT id FROM words WHERE example IS NULL OR example=''")}
        applied = {i: t for i, t in fills.items() if i in empty_ids}
        print(f"[apply] planned={len(fills)} still_empty={len(applied)} (skipped {len(fills)-len(applied)} non-empty)", flush=True)
        db.executemany("UPDATE words SET example=? WHERE id=?",
                       [(t, i) for i, t in applied.items()])
        db.commit()
        after = db.execute(
            "SELECT COUNT(*) FROM words WHERE example IS NULL OR example=''").fetchone()[0]
        print(f"[apply] empty-example rows: {before} -> {after}", flush=True)

        # integrity gates
        assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        assert db.execute("""SELECT COUNT(*) FROM books b WHERE b.word_count !=
            (SELECT COUNT(*) FROM word_books wb WHERE wb.book_id=b.id)""").fetchone()[0] == 0
        assert db.execute("""SELECT COUNT(*) FROM word_books wb
            LEFT JOIN words w ON w.id=wb.word_id WHERE w.id IS NULL""").fetchone()[0] == 0
        # parse-back validation of every written row
        bad = 0
        for i in applied:
            txt = db.execute("SELECT example FROM words WHERE id=?", (i,)).fetchone()[0]
            o = json.loads(txt)
            assert o["v"] == 1 and o["data"] and o["data"][0]["g"] and o["data"][0]["g"][0]["s"]
            for s in o["data"][0]["g"][0]["s"]:
                assert s["e"] and s["c"]
        print(f"[verify] parse-back ok, bad={bad}", flush=True)
        db.execute("VACUUM")
        db.commit()
        db.close()

        with gzip.open(args.output, "wb", compresslevel=9) as fo, raw.open("rb") as fi:
            shutil.copyfileobj(fi, fo)
    print(f"[done] -> {args.output}", flush=True)


if __name__ == "__main__":
    main()
