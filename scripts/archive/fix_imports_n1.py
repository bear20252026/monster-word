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
imps = (
    "import 'package:word_app/core/application/presentation_prefs.dart';\n"
    "import 'package:word_app/core/application/today_progress_store.dart';\n"
)
for rel in files:
    p = root / rel
    if not p.exists():
        continue
    src = p.read_text(encoding="utf-8")
    src = re.sub(r"(?m)^import 'package:word_app/core/application/presentation_prefs.dart';\r?\n", "", src)
    src = re.sub(r"(?m)^import 'package:word_app/core/application/today_progress_store.dart';\r?\n", "", src)
    if "package:flutter_test/flutter_test.dart" in src:
        src = src.replace(
            "import 'package:flutter_test/flutter_test.dart';",
            "import 'package:flutter_test/flutter_test.dart';\n" + imps.rstrip("\n"),
            1,
        )
    else:
        src = imps + src
    # fix _SpySession super in contract test
    src = re.sub(
        r"class _SpySession extends LearningSessionState \{[\s\S]*?super\(([\s\S]*?)\);",
        lambda m: "class _SpySession extends LearningSessionState {\n  _SpySession()\n    : super(\n"
        + m.group(1).rstrip()
        + ",\n        todayStore: TodayProgressStore(),\n        prefs: PresentationPrefs(),\n      );",
        src,
        count=1,
    )
    # avoid duplicate todayStore in spy
    src = src.replace(
        "todayStore: TodayProgressStore(),\n        prefs: PresentationPrefs(),\n        todayStore: TodayProgressStore(),\n        prefs: PresentationPrefs(),",
        "todayStore: TodayProgressStore(),\n        prefs: PresentationPrefs(),",
    )
    p.write_text(src, encoding="utf-8")
    print("fixed", rel)
print("ok")
