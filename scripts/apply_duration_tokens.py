# P1-B（审计 I60）批次脚本：动效语境的 Duration 字面量 → MotionDurations 档位。
# 口径：只收「参数化动效语境」（duration/delay/transitionDuration/AnimationController/
# 命名参数默认值），Future.delayed/Timer 等业务时序不动；值精确命中档位才替换。
# 按 (文件, 行号) 精确定位，逐行确认替换，避免误伤。
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TOKEN = {"150": "fast", "200": "base", "300": "slow", "450": "expressive", "700": "count", "2800": "splash"}

# (相对路径, 行号, 语境备注)
TARGETS = [
    ("lib/features/dictionary/presentation/word_detail/word_detail_example_tile.dart", 176, "BoxReveal delay"),
    ("lib/features/checkin/presentation/treasure_checkin_page.dart", 838, "AnimatedContainer duration"),
    ("lib/app/router/global_nav_history_bar.dart", 175, "动画 duration"),
    ("lib/features/learning/presentation/dashboard_page.dart", 175, "count 动画"),
    ("lib/features/dictionary/presentation/word_detail_page.dart", 288, "BoxReveal delay"),
    ("lib/features/dictionary/presentation/word_detail_page.dart", 383, "BoxReveal delay"),
    ("lib/widgets/coin_swallow_celebration.dart", 104, "AnimationController"),
    ("lib/features/learning/presentation/home/home_hero.dart", 215, "count 动画"),
    ("lib/features/learning/presentation/word_lookup_popup.dart", 63, "transitionDuration"),
    ("lib/features/learning/presentation/review_session_answer_state.dart", 12, "反馈时长默认参数"),
    ("lib/widgets/halo_search.dart", 58, "AnimationController"),
    ("lib/widgets/transition_widgets.dart", 17, "Route 默认时长"),
    ("lib/widgets/transition_widgets.dart", 36, "Route 默认时长"),
    ("lib/widgets/transition_widgets.dart", 51, "Route 默认时长"),
    ("lib/widgets/mw_style_grid.dart", 36, "动画 duration"),
    ("lib/widgets/morphing_tabs.dart", 52, "AnimationController expressive"),
    ("lib/widgets/morphing_tabs.dart", 147, "动画 duration"),
    ("lib/widgets/text_generate_effect.dart", 17, "delay 默认参数"),
]

DUR_RE = re.compile(r"const Duration\(milliseconds: (\d+)\)")
IMPORT_LINE = "import 'package:word_app/tokens/motion_tokens.dart';"
IMPORT_RE = re.compile(r"^import\s+['\"]package:word_app/tokens/motion_tokens\.dart['\"];", re.M)


def ensure_import(path: Path, src: str) -> str:
    if IMPORT_RE.search(src):
        return src
    first = re.search(r"^(import\s)", src, re.M)
    if first is None:
        return src
    return src[: first.start()] + IMPORT_LINE + "\n" + src[first.start() :]


def main() -> int:
    done = 0
    touched = set()
    for rel, lineno, note in TARGETS:
        f = ROOT / rel
        lines = f.read_text(encoding="utf-8").split("\n")
        line = lines[lineno - 1]
        m = DUR_RE.search(line)
        if not m or m.group(1) not in TOKEN:
            print(f"!! 未命中（请人工核对）: {rel}:{lineno} [{note}] -> {line.strip()}")
            continue
        lines[lineno - 1] = DUR_RE.sub(f"MotionDurations.{TOKEN[m.group(1)]}", line, count=1)
        f.write_text("\n".join(lines), encoding="utf-8", newline="\n")
        touched.add(rel)
        done += 1
        print(f"{rel}:{lineno} [{note}] -> MotionDurations.{TOKEN[m.group(1)]}")

    for rel in touched:
        f = ROOT / rel
        src = f.read_text(encoding="utf-8")
        if not IMPORT_RE.search(src):
            f.write_text(ensure_import(f, src), encoding="utf-8", newline="\n")
            print(f"  +import: {rel}")

    print(f"\n合计 {done} 处替换 / {len(touched)} 文件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
