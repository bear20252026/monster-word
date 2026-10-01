# P1-A（审计 I61）批次脚本：withValues(alpha: 字面量) → AppAlphas token。
# 口径与 spacing 批次一致：值精确命中档位才替换，不改任何非档位值；
# 每个被改文件若无 design_tokens import 则补上。
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 档位 → token 名（覆盖同一档位的多种写法：0.1/0.10）
TOKEN_OF = {
    "0": "o0",
    "0.0": "o0",
    "0.05": "o05",
    "0.06": "o06",
    "0.08": "o08",
    "0.1": "o10",
    "0.10": "o10",
    "0.12": "o12",
    "0.14": "o14",
    "0.15": "o15",
    "0.18": "o18",
    "0.2": "o20",
    "0.20": "o20",
    "0.22": "o22",
    "0.25": "o25",
    "0.3": "o30",
    "0.30": "o30",
    "0.35": "o35",
    "0.4": "o40",
    "0.40": "o40",
    "0.5": "o50",
    "0.50": "o50",
    "0.55": "o55",
    "0.6": "o60",
    "0.60": "o60",
    "0.65": "o65",
    "0.7": "o70",
    "0.70": "o70",
    "0.75": "o75",
    "0.8": "o80",
    "0.80": "o80",
    "0.85": "o85",
    "0.9": "o90",
    "0.90": "o90",
    "0.92": "o92",
    "0.96": "o96",
}

ALPHA_RE = re.compile(r"withValues\(alpha:\s*(0(?:\.\d+)?)\)")
PART_OF_RE = re.compile(r"^part of '([^']+)';", re.M)
IMPORT_LINE = "import 'package:word_app/tokens/design_tokens.dart';"
IMPORT_RE = re.compile(r"^import\s+['\"]package:word_app/tokens/design_tokens\.dart['\"];", re.M)


def ensure_import(lib_file: Path) -> bool:
    """确保 lib_file（主库文件）含 design_tokens import；缺则插到首个 import 前。"""
    src = lib_file.read_text(encoding="utf-8")
    if IMPORT_RE.search(src):
        return True
    first_import = re.search(r"^(import\s)", src, re.M)
    if first_import is None:
        return False
    src = src[: first_import.start()] + IMPORT_LINE + "\n" + src[first_import.start() :]
    lib_file.write_text(src, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    total_files = 0
    total_hits = 0
    for f in (ROOT / "lib").rglob("*.dart"):
        src = f.read_text(encoding="utf-8")
        hits = list(ALPHA_RE.finditer(src))
        if not hits:
            continue

        def repl(m: re.Match) -> str:
            token = TOKEN_OF[m.group(1)]
            return f"withValues(alpha: AppAlphas.{token})"

        new_src = ALPHA_RE.sub(repl, src)

        part_of = PART_OF_RE.search(new_src)
        if part_of:
            # part 文件：替换内容照写，import 落到主库文件
            main_lib = (f.parent / part_of.group(1)).resolve()
            if not ensure_import(main_lib):
                print(f"!! 跳过（主库无 import 块）: {f} -> {main_lib}")
                continue
        elif not IMPORT_RE.search(new_src):
            first_import = re.search(r"^(import\s)", new_src, re.M)
            if first_import is None:
                print(f"!! 跳过（无 import 块）: {f}")
                continue
            new_src = new_src[: first_import.start()] + IMPORT_LINE + "\n" + new_src[first_import.start() :]

        f.write_text(new_src, encoding="utf-8", newline="\n")
        total_files += 1
        total_hits += len(hits)
        print(f"{f.relative_to(ROOT)}: {len(hits)} 处")

    print(f"\n合计 {total_files} 文件 / {total_hits} 处替换")
    return 0


if __name__ == "__main__":
    sys.exit(main())
