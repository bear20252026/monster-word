# -*- coding: utf-8 -*-
"""Merge pool/Tatoeba/OpenSubtitles candidates into final_candidates.json.

Priority per word: Tatoeba (human translations) > OpenSubtitles (translation memory).
Up to 4 rows per word, cleaner sentences ranked first:
  score = terminal punctuation > no SHOUTING tokens > shorter.
Also emits audit_sample.json (35 words) for manual review.
Output rows: [en, zh, source]
"""
import json, random, re, statistics

WORK = "C:/Users/17296/AppData/Local/Temp/mw_sentence_batch"
PER_WORD = 4

remaining = json.load(open(f"{WORK}/remaining_gap.json", encoding="utf-8"))
gap_words = {w.lower().strip() for _i, w, _m in remaining if w.strip()}

tat = {k: v for k, v in json.load(open(f"{WORK}/tatoeba_full_candidates.json", encoding="utf-8")).items() if k in gap_words}
sub = {k: v for k, v in json.load(open(f"{WORK}/opensub_candidates.json", encoding="utf-8")).items() if k in gap_words}

CTRL = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff\u00ad]")
def clean(s: str) -> str:
    return CTRL.sub("", s).strip()

# unambiguous traditional-only chars (simplified counterparts differ) — deprioritize, not exclude
TRAD = set("們無藥鎮劑說對會後裡過還這沒愛車馬鳥語書學開關點發應該當讓認聽覺記務運動場費買賣錢龍鳳國時專樂歷壓縮類願廳")

def score(en: str, zh: str):
    clean_zh = not (set(zh) & TRAD)
    no_shout = not re.search(r"\b[A-Z]{2,}\b", en)
    speaker = 0 if re.match(r"^[A-Z][A-Z' .-]{1,24}:\s", en) else 1
    return (1 if en[-1] in ".!?" else 0, clean_zh, no_shout, speaker, -len(en))

final = {}
for w in gap_words:
    rows, seen = [], set()
    for en, zh in tat.get(w, []):
        en, zh = clean(en), clean(zh)
        if not en or not zh or en.lower() in seen:
            continue
        seen.add(en.lower())
        rows.append([en, zh, "Tatoeba"])
    cand = sorted(sub.get(w, []), key=lambda r: score(clean(r[0]), clean(r[1])), reverse=True)
    for en, zh in cand:
        if len(rows) >= PER_WORD:
            break
        en, zh = clean(en), clean(zh)
        if not en or not zh or en.lower() in seen:
            continue
        seen.add(en.lower())
        rows.append([en, zh, "OpenSubtitles"])
    if rows:
        final[w] = rows

n_tat = sum(1 for v in final.values() if any(r[2] == "Tatoeba" for r in v))
n_sub = sum(1 for v in final.values() if any(r[2] == "OpenSubtitles" for r in v))
only_sub = sum(1 for v in final.values() if all(r[2] == "OpenSubtitles" for r in v))
cnt = [len(v) for v in final.values()]
print(f"words covered={len(final)}/{len(gap_words)}  with-tatoeba={n_tat}  with-sub={n_sub}  only-sub={only_sub}")
print(f"rows/word mean={statistics.mean(cnt):.2f} median={statistics.median(cnt)}")

json.dump(final, open(f"{WORK}/final_candidates.json", "w", encoding="utf-8"), ensure_ascii=False)

random.seed(42)
sample = {w: final[w] for w in random.sample(sorted(final), min(35, len(final)))}
json.dump(sample, open(f"{WORK}/audit_sample.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("audit sample -> audit_sample.json (35 words)")
