# P1-D（审计 I4 收尾）批次脚本：ScaffoldMessenger.of(x).showSnackBar( → showMwSnackBar(x, 。
# 口径：只收 ScaffoldMessenger.of(...) 链式形态（含跨行链）；已局部化的
# messenger 变量调用不在范围。part 文件替换内容、import 落主库。
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CALL_RE = re.compile(r"ScaffoldMessenger\.of\(([^)]+)\)\s*\.\s*showSnackBar\(")
PART_OF_RE = re.compile(r"^part of '([^']+)';", re.M)
IMPORT_LINE = "import 'package:word_app/widgets/common/mw_feedback.dart';"
IMPORT_RE = re.compile(r"^import\s+['\"]package:word_app/widgets/common/mw_feedback\.dart['\"];", re.M)


def ensure_import(lib_file: Path, src: str) -> str:
    if IMPORT_RE.search(src):
        return src
    first = re.search(r"^(import\s)", src, re.M)
    if first is None:
        return src
    return src[: first.start()] + IMPORT_LINE + "\n" + src[first.start() :]


def main() -> int:
    total_files = 0
    total_hits = 0
    for f in (ROOT / "lib").rglob("*.dart"):
        rel = f.relative_to(ROOT).as_posix()
        if rel.endswith("mw_feedback.dart"):
            continue
        src = f.read_text(encoding="utf-8")
        hits = list(CALL_RE.finditer(src))
        if not hits:
            continue
        new_src = CALL_RE.sub(r"showMwSnackBar(\1, ", src)

        part_of = PART_OF_RE.search(new_src)
        if part_of:
            main_lib = (f.parent / part_of.group(1)).resolve()
            main_src = main_lib.read_text(encoding="utf-8")
            main_lib.write_text(ensure_import(main_lib, main_src), encoding="utf-8", newline="\n")
        else:
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
