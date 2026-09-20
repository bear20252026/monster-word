# -*- coding: utf-8 -*-
from pathlib import Path
import re

ROOT = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-b7")
TOKENS = ROOT / "lib/tokens/skin_tokens.dart"
TEST = ROOT / "test/architecture/theme_token_consistency_test.dart"
PRESETS = ROOT / "lib/theme/theme_presets.dart"

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

# normalize tokens file
tok = TOKENS.read_text(encoding="utf-8")
tok = re.sub(r"static const (\w+) = const Color\(", r"static const Color \1 = Color(", tok)
tok = re.sub(r"static const (\w+) = const \[Color\(", r"static const List<Color> \1 = [Color(", tok)
# if we doubled Color Color
tok = tok.replace("static const Color Color ", "static const Color ")
tok = tok.replace("Color Color(", "Color(")
TOKENS.write_text(tok, encoding="utf-8")

src = TOKENS.read_text(encoding="utf-8")
fields_by_class = {}
for skin, cls in CLASS.items():
    if f"class {cls} {{" not in src:
        raise SystemExit(f"missing class {cls}")
    block = src.split(f"class {cls} {{", 1)[1].split("\n}", 1)[0]
    fields = []
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("static const "):
            continue
        rest = line[len("static const ") :]
        # Color pageBg = ... | List<Color> profileDecor = ...
        name = rest.split("=", 1)[0].strip().split()[-1]
        fields.append(name)
    fields_by_class[skin] = fields

# ensure presets import
pres = PRESETS.read_text(encoding="utf-8")
if "skin_tokens.dart" not in pres:
    pres = pres.replace(
        "import 'package:word_app/tokens/starbucks_tokens.dart';",
        "import 'package:word_app/tokens/skin_tokens.dart';\nimport 'package:word_app/tokens/starbucks_tokens.dart';",
    )
    PRESETS.write_text(pres, encoding="utf-8")

# rewrite test file header + append group
header = """// 主题色单一事实来源守卫（审计 A1 / 上轮 M4 + batch7）。
// 星巴克→starbucks_tokens；其余 9 套→lib/tokens/skin_tokens.dart（本测试锁定）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/skin_tokens.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

void main() {
"""

# keep original starbucks tests from existing file
old = TEST.read_text(encoding="utf-8")
start = old.find("  group('主题色单一事实来源：星巴克")
end = old.find("  });\n}", start)
if start < 0 or end < 0:
    raise SystemExit("could not find starbucks group")
starbucks = old[start : end + len("  });\n")]

lines = [
    "  group('皮肤 token 单一事实来源（batch7：9 套非星巴克）', () {",
    "    test('preset 字段 == skin_tokens 常量', () {",
    "      Color pick(String field, ThemeVars vars) {",
    "        return switch (field) {",
    "          'pageBg' => vars.pageBg,",
    "          'cardBg' => vars.cardBg,",
    "          'cardBgAlt' => vars.cardBgAlt,",
    "          'text1' => vars.text1,",
    "          'text2' => vars.text2,",
    "          'text3' => vars.text3,",
    "          'divider' => vars.divider,",
    "          'accent' => vars.accent,",
    "          'success' => vars.success,",
    "          'danger' => vars.danger,",
    "          'teal' => vars.teal,",
    "          'tabBarIcon' => vars.tabBarIcon,",
    "          'onGlassText1' => vars.onGlassText1,",
    "          'onGlassText2' => vars.onGlassText2,",
    "          'onGlassAccent' => vars.onGlassAccent,",
    "          'glassBg' => vars.glassBg,",
    "          'glassBgStrong' => vars.glassBgStrong,",
    "          'glassBorder' => vars.glassBorder,",
    "          'wallpaperScrim' => vars.wallpaperScrim,",
    "          'modalGlassBg' => vars.modalGlassBg,",
    "          'modalText1' => vars.modalText1,",
    "          'modalText2' => vars.modalText2,",
    "          'quizCorrectBg' => vars.quizCorrectBg,",
    "          'quizCorrectText' => vars.quizCorrectText,",
    "          'quizWrongBg' => vars.quizWrongBg,",
    "          'quizWrongText' => vars.quizWrongText,",
    "          'vipGoldBg' => vars.vipGoldBg,",
    "          'vipGoldText' => vars.vipGoldText,",
    "          _ => throw ArgumentError(field),",
    "        };",
    "      }",
    "",
]
for skin, cls in CLASS.items():
    for field in fields_by_class[skin]:
        if field == "profileDecor":
            lines.append(
                f"      expect(themes['{skin}']!.vars.profileDecor, {cls}.profileDecor, reason: '{skin}.profileDecor');"
            )
        else:
            lines.append(
                f"      expect(pick('{field}', themes['{skin}']!.vars), {cls}.{field}, reason: '{skin}.{field}');"
            )
lines += [
    "    });",
    "  });",
    "}",
    "",
]

out = header + starbucks.rstrip() + "\n\n" + "\n".join(lines)
# starbucks already ends with });  we need to not double-close main
# starbucks extract ends with "  });\n" only for last test inside group - need full group close
# Re-read carefully
# Actually end marker is first `  });\n}` which is last test + main close - wrong.

print("fields", {k: len(v) for k,v in fields_by_class.items()})
print("starbucks_len", len(starbucks))
# write draft - we'll fix main structure below
# Find complete first group only
gstart = old.find("  group('主题色单一事实来源：星巴克")
# find the matching end of this group: "\n  });\n" after WCAG test
gend = old.find("    });\n  });\n}", gstart)
if gend < 0:
    gend = old.rfind("  });\n}")
group = old[gstart: gend + len("    });\n  });\n")]
out = header + group + "\n\n" + "\n".join(lines)
TEST.write_text(out, encoding="utf-8")
print("wrote", TEST)
