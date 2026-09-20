from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-n")
files = [
    "test/features/book/presentation/book_words_page_fab_test.dart",
    "test/features/dictionary/presentation/word_detail_deep_link_error_test.dart",
    "test/features/dictionary/presentation/word_detail_phrase_root_test.dart",
    "test/features/learning/data/learning_session_starter_contract_test.dart",
    "test/features/learning/presentation/review_dialog_test.dart",
    "test/features/learning/presentation/learn_page_regression_test.dart",
    "test/regression/regression_quiz_test.dart",
    "test/features/learning/presentation/learning_session_state_test.dart",
]
for rel in files:
    p = root / rel
    src = p.read_text(encoding="utf-8")
    # fix double commas
    src = src.replace(",,", ",")
    # merge glued import at start
    src = re.sub(
        r"^import 'package:word_app/core/application/today_progress_store.dart';import ",
        "import ",
        src,
    )
    lines = src.splitlines()
    seen = set()
    out = []
    for line in lines:
        if line.startswith("import ") and line in seen:
            continue
        if line.startswith("import "):
            seen.add(line)
        out.append(line)
    src = "\n".join(out) + "\n"
    # ensure both facade imports exist once
    for imp in (
        "import 'package:word_app/core/application/presentation_prefs.dart';",
        "import 'package:word_app/core/application/today_progress_store.dart';",
    ):
        if imp not in src:
            # after first import
            src = re.sub(r"(import 'package:flutter_test/flutter_test.dart';)", r"\1\n" + imp, src, count=1)
    p.write_text(src, encoding="utf-8")
    print("cleaned", rel)
print("ok")
