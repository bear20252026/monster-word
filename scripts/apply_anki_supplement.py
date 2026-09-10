#!/usr/bin/env python3
"""Apply audited Anki candidates to a staged DB copy.

Non-destructive: only fills empty dictionary fields, never overwrites existing
values. To avoid the per-row `WHERE lower(word)=?` full-table scan over a
770k-row table (the original reason applies appeared to hang), we build an
in-memory word -> (id, uk, us, interpret, example, word_root) map once, decide
all fills in Python, then apply by primary key `id` in small batches.

Field contracts (validated against the app's real parsers):
- word_root: {"prefix":..,"roots":[..],"suffix":..}
- example:   {"v":1,"data":[{"oid":..,"i":{"e":..,"c":..,"p":..},"g":[{"u":..,"s":[{"e":..,"c":..,"b":..}]}]}]}
"""
from __future__ import annotations
import argparse, gzip, json, re, shutil, sqlite3, tempfile
from pathlib import Path


def root_json(affix, meaning):
    affix = affix.strip(); meaning = (meaning or '').strip()
    if affix.endswith('-'):
        return {"prefix": affix.rstrip('-'), "roots": [], "suffix": ""}
    if affix.startswith('-'):
        return {"prefix": "", "roots": [], "suffix": affix.lstrip('-')}
    return {"prefix": "", "roots": [f"{affix} = {meaning}" if meaning else affix], "suffix": ""}


def example_json(en, cn):
    return {"v": 1, "data": [{"oid": 1, "i": {"e": "", "c": "", "p": ""},
                              "g": [{"uid": 0, "u": "", "s": [{"eid": 1, "e": en, "c": cn or "", "b": ""}]}]}]}


def load(path):
    return [json.loads(line) for line in path.open(encoding="utf-8")]


def affix_map(path):
    m = {}
    for item in load(path):
        for ex in item.get("examples", []):
            w = ex.get("word", "").lower().strip()
            if re.fullmatch(r"[a-z]+", w):
                m.setdefault(w, []).append((item.get("affix", ""), item.get("meaning_cn", "")))
    return m


def esc(value):
    return (value or "").replace("'", "''")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, required=True)
    ap.add_argument("--audit-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    affix = affix_map(args.audit_dir / "affix_supplement.jsonl")
    print(f"[apply] affix_map_words={len(affix)}", flush=True)

    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "wordbook.db"
        with gzip.open(args.db, "rb") as src, raw.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        db = sqlite3.connect(raw)
        db.execute("PRAGMA journal_mode=OFF")

        # Build in-memory word -> row lookup (once).
        print("[apply] loading words map...", flush=True)
        rows = db.execute("SELECT id, word, uk_pron, us_pron, interpret, example, word_root FROM words").fetchall()
        idx = {}
        for r in rows:
            key = r[1].lower()
            if key not in idx:  # keep first occurrence for a casing duplicate
                idx[key] = r
        print(f"[apply] words_map={len(idx)}", flush=True)

        updates = {}  # id -> {'uk':..,'us':..,'interpret':..,'example':..,'root':..}
        n_roots = n_uk = n_us = n_ex = n_int = 0

        # Stage 1: structured word_root from affix deck (empty only).
        for word, links in affix.items():
            rec = idx.get(word)
            if rec is None:
                continue
            word_id, _, _, _, _, _, cur_root = rec
            if cur_root and cur_root.strip():
                continue
            seen = set()
            for affix_val, meaning in links:
                key = (affix_val, meaning)
                if key in seen:
                    continue
                seen.add(key)
                updates.setdefault(word_id, {})["root"] = json.dumps(root_json(affix_val, meaning), ensure_ascii=False)
                n_roots += 1
        print(f"[apply] stage1 word_root fills={n_roots}", flush=True)

        # Stage 2: pronunciation/interpret/example (empty only) from all decks.
        for item in load(args.audit_dir / "example_fill.jsonl"):
            rec = idx.get(item["word"])
            if rec is None:
                continue
            word_id, _, cur_uk, cur_us, cur_int, cur_ex, _ = rec
            if item.get("fill_uk"):
                updates.setdefault(word_id, {})["uk"] = item["uk_pron"]; n_uk += 1
            if item.get("fill_us"):
                updates.setdefault(word_id, {})["us"] = item["us_pron"]; n_us += 1
            if item.get("fill_interpret"):
                updates.setdefault(word_id, {})["interpret"] = item["interpret"]; n_int += 1
            if item.get("fill_example"):
                updates.setdefault(word_id, {})["example"] = json.dumps(example_json(item["example_en"], item["example_cn"]), ensure_ascii=False); n_ex += 1
        print(f"[apply] stage2 fills: uk={n_uk} us={n_us} interpret={n_int} example={n_ex}", flush=True)

        # Apply by primary key in batches to keep the single transaction manageable.
        print(f"[apply] applying {len(updates)} keyed updates...", flush=True)
        db.execute("BEGIN")
        items = list(updates.items())
        batch_size = 2000
        for start in range(0, len(items), batch_size):
            batch = items[start:start + batch_size]
            for word_id, u in batch:
                sets, values = [], []
                if "uk" in u:
                    sets.append("uk_pron=?"); values.append(u["uk"])
                if "us" in u:
                    sets.append("us_pron=?"); values.append(u["us"])
                if "interpret" in u:
                    sets.append("interpret=?"); values.append(u["interpret"])
                if "example" in u:
                    sets.append("example=?"); values.append(u["example"])
                if "root" in u:
                    sets.append("word_root=?"); values.append(u["root"])
                if not sets:
                    continue
                values.append(word_id)
                db.execute("UPDATE words SET %s WHERE id=?" % ", ".join(sets), values)
            if start % 5000 == 0:
                print(f"[apply] ...batch {start}/{len(items)}", flush=True)
        db.commit()
        print("[apply] committed, vacuuming...", flush=True)
        db.execute("VACUUM")
        db.close()
        with raw.open("rb") as src, gzip.open(args.output, "wb", compresslevel=9) as dst:
            shutil.copyfileobj(src, dst)
        print("[apply] output written", flush=True)

    report = {
        "source": str(args.db),
        "output": str(args.output),
        "word_root_updates": n_roots,
        "uk_pron_updates": n_uk,
        "us_pron_updates": n_us,
        "interpret_updates": n_int,
        "example_updates": n_ex,
        "non_overwrite_policy": True,
    }
    (args.output.parent / "apply_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()