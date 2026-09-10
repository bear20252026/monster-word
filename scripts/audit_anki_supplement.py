#!/usr/bin/env python3
"""Audit and normalize ALL usable Anki decks into non-destructive supplements.

The user has decided every data source is accepted. This script therefore
extracts, from every usable English deck, the three fields that add real value
to the app: example sentences, pronunciation, and Chinese interpretation.
It writes JSONL candidates plus a machine-readable report, and does NOT write
into the shipped database itself.

Quality rules that remain even under the "accept all" policy:
- Only fill fields that are currently empty (non-overwrite).
- Skip decks that are broken (4000 Essential) or non-English (Spanish).
- A sentence deck (167000) contributes example sentences by matching a target
  word inside the sentence.
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sqlite3
import zipfile
from collections import Counter
from pathlib import Path

SEP = "\x1f"
TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"\s+")
SENT_SPLIT_RE = re.compile(r"[.!?;]")

# Decks we deliberately skip and why.
SKIP = {
    "4000_Essential_English_Words_all_books_en-en.apkg": "broken (1 note / import-error)",
    "Spanish_7000_IntermediateAdvanced_Sentences_w_Audio.apkg": "not English",
}


def clean(value: str) -> str:
    value = html.unescape(value or "")
    value = value.replace("<br />", "\n").replace("<br/>", "\n").replace("<br>", "\n")
    value = TAG_RE.sub("", value)
    value = value.replace("\xa0", " ")
    return WS_RE.sub(" ", value).strip()


def extract_anki(path: Path):
    with zipfile.ZipFile(path) as archive:
        db_name = next((n for n in archive.namelist() if n.endswith("collection.anki2")), None)
        if not db_name:
            raise ValueError(f"{path.name}: collection.anki2 not found")
        blob = archive.read(db_name)
    tmp = path.with_suffix(".audit.anki2")
    tmp.write_bytes(blob)
    try:
        db = sqlite3.connect(tmp)
        models = json.loads(db.execute("select models from col").fetchone()[0])
        fields_by_model = {int(k): [f["name"] for f in v["flds"]] for k, v in models.items()}
        rows = db.execute("select id, mid, flds from notes")
        for note_id, mid, fields in rows:
            names = fields_by_model.get(mid, [])
            values = fields.split(SEP)
            yield note_id, dict(zip(names, values))
    finally:
        try:
            tmp.unlink()
        except OSError:
            pass


def first(fields, *names):
    for name in names:
        value = clean(fields.get(name, ""))
        if value:
            return value
    return ""


def ascii_word(word):
    word = word.lower().strip()
    return word if re.fullmatch(r"[a-z]+", word) else ""


def split_uk_us(raw):
    """Return (uk, us) from forms like '英 [..] 美 [..]' or '[..]' or 'UK..US..'."""
    raw = clean(raw)
    if not raw:
        return "", ""
    uk = us = ""
    m_uk = re.search(r"(?:英|UK|英式)[^\[]*\[([^\]]+)\]", raw)
    m_us = re.search(r"(?:美|US|美式)[^\[]*\[([^\]]+)\]", raw)
    if m_uk or m_us:
        if m_uk:
            uk = m_uk.group(1).strip()
        if m_us:
            us = m_us.group(1).strip()
    else:
        us = raw.strip("[] ")
        uk = ""
    return uk, us


def parse_word_card(path: Path, source: str):
    """Generic word card with fields: word, interpret, example, pron."""
    for note_id, f in extract_anki(path):
        word = ascii_word(first(f, "单词", "word", "Word", "英语单词"))
        if not word:
            continue
        uk, us = split_uk_us(first(f, "英美音标", "发音", "音标"))
        if not uk and not us:
            raw = first(f, "音标")
            us = raw.strip("[] ").strip()
        example = first(f, "例句", "英语例句", "example_en")
        interpret = first(f, "释义1", "定义", "中文释义", "解释")
        # collapse multi-interpret fields (释义1 + 释义2)
        if not interpret:
            parts = []
            for k in ("释义1", "释义2", "词性1", "词性2"):
                v = clean(f.get(k, ""))
                if v:
                    parts.append(v)
            interpret = " ".join(parts)
        yield {
            "source": source,
            "note_id": note_id,
            "word": word,
            "uk_pron": uk,
            "us_pron": us,
            "interpret": interpret,
            "example": example,
        }


def parse_anki_deck(path: Path, source: str):
    """Anki deck: word + 英美音标 + 中文释义 + 英语例句."""
    for note_id, f in extract_anki(path):
        word = ascii_word(first(f, "英语单词"))
        if not word:
            continue
        uk, us = split_uk_us(first(f, "英美音标"))
        example = first(f, "英语例句")
        interpret = first(f, "中文释义")
        yield {
            "source": source,
            "note_id": note_id,
            "word": word,
            "uk_pron": uk,
            "us_pron": us,
            "interpret": interpret,
            "example": example,
        }


def parse_coca(path: Path, source: str):
    """COCA decks: 单词 | 音标 | 解释 | 例句."""
    for note_id, f in extract_anki(path):
        word = ascii_word(first(f, "单词"))
        if not word:
            continue
        pron = first(f, "音标")
        uk = ""
        us = pron.strip("[] ").strip()
        example = first(f, "例句")
        interpret = first(f, "解释")
        yield {
            "source": source,
            "note_id": note_id,
            "word": word,
            "uk_pron": uk,
            "us_pron": us,
            "interpret": interpret,
            "example": example,
        }


def parse_sentence_deck(path: Path, source: str):
    """167000 sentence deck: extract sentences and record the word each belongs to."""
    # We can't know a target word per note, so emit the whole sentence list as
    # a sentence resource. This file is still useful to the example-fill pass.
    out = []
    for note_id, f in extract_anki(path):
        en = first(f, "Front")
        zh = first(f, "Back")
        if en:
            out.append({"source": source, "note_id": note_id, "en": en, "zh": zh})
    return out


def gather_decks(anki_dir: Path):
    decks = [
        ("5500.apkg", "anki:5500.apkg", parse_word_card),
        ("TOEFL__.apkg", "anki:TOEFL__.apkg", parse_word_card),
        ("Anki.apkg", "anki:Anki.apkg", parse_word_card),
        ("blank.apkg", "anki:blank.apkg", parse_anki_deck),
        ("blank (1).apkg", "anki:blank (1).apkg", parse_anki_deck),
        ("blank (2).apkg", "anki:blank (2).apkg", parse_anki_deck),
        ("COCAEnglish10000.apkg", "anki:COCAEnglish10000.apkg", parse_coca),
        ("COCA_words_16000_COCA.apkg", "anki:COCA_words_16000_COCA.apkg", parse_coca),
    ]
    sentence = []
    for fn, source, parser in decks:
        if fn in SKIP:
            continue
        path = anki_dir / fn
        if path.exists():
            yield from parser(path, source)
    spath = anki_dir / "167000.apkg"
    if spath.exists():
        sentence.extend(parse_sentence_deck(spath, "anki:167000.apkg"))
    yield from sentence


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, required=True)
    ap.add_argument("--anki-dir", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    import gzip

    db_path = args.out / "_wordbook.audit.db"
    with gzip.open(args.db, "rb") as src, db_path.open("wb") as dst:
        dst.write(src.read())
    db = sqlite3.connect(db_path)

    existing = {row[0].lower(): row for row in db.execute("select word, uk_pron, us_pron, interpret, example from words")}

    word_cards = []
    sentences = []
    for item in gather_decks(args.anki_dir):
        if "en" in item and "zh" in item:
            sentences.append(item)
        else:
            word_cards.append(item)

    stats = Counter()
    fill_ex = Counter()
    for item in word_cards:
        row = existing.get(item["word"])
        item["matched"] = bool(row)
        if row:
            stats["matched"] += 1
            item["fill_interpret"] = bool(not row[3] and item["interpret"])
            item["fill_example"] = bool(not row[4] and item["example"])
            item["fill_uk"] = bool(not row[1] and item["uk_pron"])
            item["fill_us"] = bool(not row[2] and item["us_pron"])
            fill_ex[item["source"]] += int(item["fill_example"])
            for k in ("fill_interpret", "fill_example", "fill_uk", "fill_us"):
                if item[k]:
                    stats[k] += 1
        else:
            stats["new_candidate"] += 1
            item["fill_example"] = False
            item["fill_interpret"] = False
            item["fill_uk"] = item["fill_us"] = False

    def dump(name, rows):
        with (args.out / name).open("w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")

    dump("example_fill.jsonl", word_cards)
    dump("sentence_deck.jsonl", sentences)
    report = {
        "database_words": len(existing),
        "word_card_notes": len(word_cards),
        "matched": stats["matched"],
        "new_candidates": stats["new_candidate"],
        "fill_interpret": stats["fill_interpret"],
        "fill_example": stats["fill_example"],
        "fill_uk": stats["fill_uk"],
        "fill_us": stats["fill_us"],
        "example_fill_by_source": dict(fill_ex),
        "sentence_deck_notes": len(sentences),
        "skipped": SKIP,
        "policy": "non_destructive_accept_all",
    }
    (args.out / "audit_example_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    db.close()
    db_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
