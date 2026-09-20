from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-n")
files = [
    "test/features/book/presentation/book_words_page_fab_test.dart",
    "test/features/dictionary/presentation/word_detail_deep_link_error_test.dart",
    "test/features/dictionary/presentation/word_detail_phrase_root_test.dart",
    "test/features/learning/presentation/learning_session_state_test.dart",
    "test/features/learning/presentation/learn_page_regression_test.dart",
    "test/regression/regression_quiz_test.dart",
]
imp = "import 'package:word_app/core/application/presentation_prefs.dart';\nimport 'package:word_app/core/application/today_progress_store.dart';\n"
for rel in files:
    p = root / rel
    if not p.exists():
        print("missing", rel)
        continue
    src = p.read_text(encoding="utf-8")
    if "presentation_prefs.dart" not in src:
        src = src.replace("import 'package:flutter_test/flutter_test.dart';", "import 'package:flutter_test/flutter_test.dart';\n" + imp, 1)
        if "presentation_prefs.dart" not in src:
            src = imp + src
    # inject named args before closing of LearningSessionState( ... )
    def fix_ctor(m):
        body = m.group(0)
        if "todayStore:" in body:
            return body
        # insert before final )
        return body[:-1] + "todayStore: TodayProgressStore(), prefs: PresentationPrefs(),)"

    src = re.sub(r"LearningSessionState\([^;]*?\)", fix_ctor, src, count=0)
    # Spy super() in fab test
    src = src.replace(
        "choicePort: MockChoiceGeneratorPort(),\n      );",
        "choicePort: MockChoiceGeneratorPort(),\n        todayStore: TodayProgressStore(),\n        prefs: PresentationPrefs(),\n      );",
    )
    p.write_text(src, encoding="utf-8")
    print("patched", rel)
