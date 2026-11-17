#!/usr/bin/env python3
"""第四轮审计 M9（2026-11-17）：CI 门禁步骤单一事实来源同步器。

背景：分支保护 required check 按检查名精确匹配（analyze-and-test），
reusable 调用会把检查名上报为「调用方 job / 被调 job」而匹配不上，
故 dart.yml 的 analyze-and-test job 必须内联步骤承载原名。

口径：quality_gate.yml 的 analyze-and-test job 步骤是**唯一事实来源**；
本脚本把它的步骤（去掉最后的同步校验步自身）机械复制到 dart.yml 的同名
job，消除手工同步漂移。release_packages.yml / build.yml 走 reusable 调用
（它们的检查名不受分支保护约束）。

用法：
  python scripts/sync_ci_gate.py          # 同步 dart.yml（写回）
  python scripts/sync_ci_gate.py --check  # 只校验是否漂移（CI 用，漂移即 exit 1）
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".github" / "workflows" / "quality_gate.yml"
TARGET = ROOT / ".github" / "workflows" / "dart.yml"

SYNC_STEP_NAME = "Verify gate steps in sync with quality_gate.yml"


def extract_steps(text: str) -> str:
    """提取 analyze-and-test job 的 steps 块（缩进 6 空格的步骤行）。"""
    lines = text.splitlines(keepends=True)
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^  analyze-and-test:\s*$", line):
            start = i
            break
    if start is None:
        raise SystemExit("未找到 analyze-and-test job")
    steps_start = None
    for i in range(start + 1, len(lines)):
        if re.match(r"^    steps:\s*$", lines[i]):
            steps_start = i + 1
            break
        if re.match(r"^  \S", lines[i]):
            break
    if steps_start is None:
        raise SystemExit("未找到 steps 块")
    steps = []
    for i in range(steps_start, len(lines)):
        line = lines[i]
        if line.strip() == "" or line.startswith("      "):
            steps.append(line)
        else:
            break
    return "".join(steps)


def strip_sync_step(steps: str) -> str:
    """去掉同步校验步自身（源头不需要校验自己）。"""
    idx = steps.find(f"- name: {SYNC_STEP_NAME}")
    if idx >= 0:
        steps = steps[:idx]
    return steps.rstrip() + "\n"


def main() -> None:
    check_only = "--check" in sys.argv
    source_steps = strip_sync_step(extract_steps(SOURCE.read_text(encoding="utf-8")))
    target_text = TARGET.read_text(encoding="utf-8")
    target_steps = extract_steps(target_text)

    # 目标侧去掉同步校验步后与源头比对
    target_core = strip_sync_step(target_steps)
    if target_core == source_steps:
        print("gate steps in sync")
        return
    if check_only:
        print("::error::dart.yml 门禁步骤与 quality_gate.yml 漂移，请运行 python scripts/sync_ci_gate.py")
        sys.exit(1)

    # 写回：替换目标 steps 核心块，保留同步校验步
    sync_idx = target_steps.find(f"- name: {SYNC_STEP_NAME}")
    sync_step = target_steps[sync_idx:] if sync_idx >= 0 else ""
    new_steps = source_steps + ("\n      " + sync_step.lstrip() if sync_step else "")
    # 定位目标文件中的 steps 块并替换
    lines = target_text.splitlines(keepends=True)
    start = next(i for i, l in enumerate(lines) if re.match(r"^  analyze-and-test:\s*$", l))
    steps_start = next(i for i in range(start + 1, len(lines)) if re.match(r"^    steps:\s*$", lines[i])) + 1
    end = steps_start
    while end < len(lines) and (lines[end].strip() == "" or lines[end].startswith("      ")):
        end += 1
    new_text = "".join(lines[:steps_start]) + new_steps + "".join(lines[end:])
    TARGET.write_text(new_text, encoding="utf-8")
    print("dart.yml gate steps synced from quality_gate.yml")


if __name__ == "__main__":
    main()
