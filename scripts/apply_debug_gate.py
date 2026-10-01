# P1-C（审计 I51）批次脚本：debugPrint → debugLog（kDebugMode 门控出口）。
# 口径：lib 下所有 debugPrint( 调用统一换 debugLog(，白名单文件不动；
# 每个被改文件若无 debug_log import 则补上。foundation import 可能因
# debugPrint 迁走而变 unused，由后续 analyze 揭示、人工裁剪。
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 不改的白名单：统一出口实现自身 / 恒输出语义的上报器
WHITELIST = {
    "lib/core/utils/debug_log.dart",
    "lib/core/utils/swallowed_error_report.dart",
}

CALL_RE = re.compile(r"\bdebugPrint\(")
IMPORT_LINE = "import 'package:word_app/core/utils/debug_log.dart';"
IMPORT_RE = re.compile(r"^import\s+['\"]package:word_app/core/utils/debug_log\.dart['\"];", re.M)


def main() -> int:
    total_files = 0
    total_hits = 0
    for f in (ROOT / "lib").rglob("*.dart"):
        rel = f.relative_to(ROOT).as_posix()
        if rel in WHITELIST:
            continue
        src = f.read_text(encoding="utf-8")
        hits = list(CALL_RE.finditer(src))
        if not hits:
            continue
        new_src = CALL_RE.sub("debugLog(", src)
        if not IMPORT_RE.search(new_src):
            first = re.search(r"^(import\s)", new_src, re.M)
            if first is None:
                print(f"!! 跳过（无 import 块）: {rel}")
                continue
            new_src = new_src[: first.start()] + IMPORT_LINE + "\n" + new_src[first.start() :]
        f.write_text(new_src, encoding="utf-8", newline="\n")
        total_files += 1
        total_hits += len(hits)
        print(f"{rel}: {len(hits)} 处")

    print(f"\n合计 {total_files} 文件 / {total_hits} 处替换")
    return 0


if __name__ == "__main__":
    sys.exit(main())
