# -*- coding: utf-8 -*-
"""Generate skin_tokens.dart + rewrite theme_presets to reference tokens (batch7)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "lib/theme/theme_presets.dart"
OUT = ROOT / "lib/tokens/skin_tokens.dart"

SKINS = [
    "bright",
    "dark",
    "pure_black",
    "warm_orange",
    "claude_cream",
    "airbnb_light",
    "nike_mono",
    "apple_light",
    "clickhouse_dark",
]

CLASS = {
    "bright": "BrightThemeColors",
    "dark": "DarkThemeColors",
    "pure_black": "PureBlackThemeColors",
    "warm_orange": "WarmOrangeThemeColors",
    "claude_cream": "ClaudeCreamColors",
    "airbnb_light": "AirbnbLightColors",
    "nike_mono": "NikeMonoColors",
    "apple_light": "AppleLightColors",
    "clickhouse_dark": "ClickhouseDarkColors",
}

FIELDS = [
    "pageBg",
    "cardBg",
    "cardBgAlt",
    "text1",
    "text2",
    "text3",
    "divider",
    "accent",
    "success",
    "danger",
    "teal",
    "tabBarIcon",
    "onGlassText1",
    "onGlassText2",
    "onGlassAccent",
    "glassBg",
    "glassBgStrong",
    "glassBorder",
    "wallpaperScrim",
    "modalGlassBg",
    "modalText1",
    "modalText2",
    "quizCorrectBg",
    "quizCorrectText",
    "quizWrongBg",
    "quizWrongText",
    "vipGoldBg",
    "vipGoldText",
]


def parse_skin_block(src: str, skin_id: str) -> dict[str, str]:
    marker = f"'{skin_id}': ThemePreset("
    start = src.find(marker)
    if start < 0:
        raise SystemExit(f"skin not found: {skin_id}")
    # find matching vars ThemeVars( ... ),  within this preset
    end = src.find("ThemePreset(", start + len(marker))
    if end < 0:
        end = len(src)
    # next skin key after start
    nxt = re.search(r"\n  '\w+': ThemePreset\(", src[start + len(marker) :])
    if nxt:
        end = start + len(marker) + nxt.start()
    block = src[start:end]
    vars_m = re.search(r"vars: ThemeVars\((.*?)\n    \),", block, re.S)
    if not vars_m:
        raise SystemExit(f"ThemeVars not found for {skin_id}")
    body = vars_m.group(1)
    colors: dict[str, str] = {}
    for field in FIELDS:
        m = re.search(rf"{field}:\s*(const Color\(0x[0-9A-Fa-f]+\))", body)
        if m:
            colors[field] = m.group(1)
        else:
            # list field
            lm = re.search(rf"{field}:\s*const \[(Color\(0x[0-9A-Fa-f]+\)),\s*(Color\(0x[0-9A-Fa-f]+\))\]", body)
            if lm:
                colors[field] = f"const [{lm.group(1)}, {lm.group(2)}]"
    if "pageBg" not in colors:
        raise SystemExit(f"failed to parse {skin_id}, body head={body[:200]}")
    return colors


def main() -> None:
    src = PRESETS.read_text(encoding="utf-8")
    all_colors = {s: parse_skin_block(src, s) for s in SKINS}

    lines = [
        "// lib/tokens/skin_tokens.dart",
        "// 9 套非星巴克皮肤色板 token（batch7，2026-09-20）。",
        "// theme_presets 引用本文件常量；theme_token_consistency_test 锁定 preset==token。",
        "import 'package:flutter/material.dart';",
        "",
    ]
    for skin in SKINS:
        cls = CLASS[skin]
        colors = all_colors[skin]
        lines.append(f"/// {skin} 主题色 token")
        lines.append(f"class {cls} {{")
        for field in FIELDS:
            if field not in colors:
                continue
            lines.append(f"  static const {field} = {colors[field]};")
        lines.append("}")
        lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # rewrite theme_presets: import + field refs
    if "skin_tokens.dart" not in src:
        src = src.replace(
            "import 'package:word_app/tokens/starbucks_tokens.dart';",
            "import 'package:word_app/tokens/skin_tokens.dart';\nimport 'package:word_app/tokens/starbucks_tokens.dart';",
        )

    for skin in SKINS:
        cls = CLASS[skin]
        marker = f"'{skin}': ThemePreset("
        start = src.find(marker)
        nxt = re.search(r"\n  '\w+': ThemePreset\(", src[start + len(marker) :])
        end = start + len(marker) + nxt.start() if nxt else len(src)
        block = src[start:end]
        new_block = block
        for field in FIELDS:
            # replace const Color(...) after field: only inside this block once
            new_block = re.sub(
                rf"({field}:\s*)const Color\(0x[0-9A-Fa-f]+\)",
                rf"\1{cls}.{field}",
                new_block,
                count=1,
            )
            new_block = re.sub(
                rf"({field}:\s*)const \[Color\(0x[0-9A-Fa-f]+\),\s*Color\(0x[0-9A-Fa-f]+\)\]",
                rf"\1{cls}.{field}",
                new_block,
                count=1,
            )
        src = src[:start] + new_block + src[end:]

    header = (
        "    // 单一事实来源：字段引用 skin_tokens.dart 常量（theme_token_consistency_test 锁定）\n"
    )
    # add comment once after file header note
    src = src.replace(
        "// 单一事实来源：星巴克双主题字段引用 starbucks_tokens.dart（守卫测试锁定）。",
        "// 单一事实来源：星巴克→starbucks_tokens；其余 9 套→skin_tokens.dart（守卫测试锁定）。",
    )
    PRESETS.write_text(src, encoding="utf-8")
    print("wrote", OUT)
    print("skins", {s: len(all_colors[s]) for s in SKINS})


if __name__ == "__main__":
    main()
