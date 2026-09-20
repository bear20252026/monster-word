# -*- coding: utf-8 -*-
"""Extend theme_token_consistency_test for 9 non-starbucks skins."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = ROOT / "lib/tokens/skin_tokens.dart"
TEST = ROOT / "test/architecture/theme_token_consistency_test.dart"

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

src = TOKENS.read_text(encoding="utf-8")
fields_by_class: dict[str, list[str]] = {}
for skin, cls in CLASS.items():
    block = src.split(f"class {cls} {{", 1)[1].split("}", 1)[0]
    fields = []
    for line in block.splitlines():
        line = line.strip()
        if line.startswith("static const "):
            # static const pageBg = ...
            name = line.split("static const", 1)[1].strip().split("=", 1)[0].strip()
            if name.startswith("["):
                continue
            fields.append(name)
    fields_by_class[skin] = fields

# fix token file style: drop double const
tok = TOKENS.read_text(encoding="utf-8")
tok = tok.replace("static const ", "static const Color ", tok)
tok = tok.replace("static const Color [", "static const List<Color> [")
tok = tok.replace("= const Color(", "= Color(")
tok = tok.replace("= const [Color(", "= [Color(")
# fix list profileDecor lines if any malformed
TOKENS.write_text(tok, encoding="utf-8")

parts = [
    "    test('9 套皮肤 preset 字段引用 skin_tokens（batch7 全量 token 化）', () {",
    "      final cases = <String, (ThemeVars Function(), Map<String, Color> Function())>{",
]
for skin, cls in CLASS.items():
    fields = fields_by_class[skin]
    pairs = ", ".join(f"'{f}': {cls}.{f}" for f in fields)
    parts.append(
        f"        '{skin}': (() => themes['{skin}']!.vars, () => {{{pairs}}}),"
    )
parts += [
    "      };",
    "      for (final entry in cases.entries) {",
    "        final vars = entry.value.$1();",
    "        final tokens = entry.value.$2();",
    "        for (final t in tokens.entries) {",
    "          final dynamic actual = switch (t.key) {",
    "            'pageBg' => vars.pageBg,",
    "            'cardBg' => vars.cardBg,",
    "            'cardBgAlt' => vars.cardBgAlt,",
    "            'text1' => vars.text1,",
    "            'text2' => vars.text2,",
    "            'text3' => vars.text3,",
    "            'divider' => vars.divider,",
    "            'accent' => vars.accent,",
    "            'success' => vars.success,",
    "            'danger' => vars.danger,",
    "            'teal' => vars.teal,",
    "            'tabBarIcon' => vars.tabBarIcon,",
    "            'onGlassText1' => vars.onGlassText1,",
    "            'onGlassText2' => vars.onGlassText2,",
    "            'onGlassAccent' => vars.onGlassAccent,",
    "            'glassBg' => vars.glassBg,",
    "            'glassBgStrong' => vars.glassBgStrong,",
    "            'glassBorder' => vars.glassBorder,",
    "            'wallpaperScrim' => vars.wallpaperScrim,",
    "            'modalGlassBg' => vars.modalGlassBg,",
    "            'modalText1' => vars.modalText1,",
    "            'modalText2' => vars.modalText2,",
    "            'quizCorrectBg' => vars.quizCorrectBg,",
    "            'quizCorrectText' => vars.quizCorrectText,",
    "            'quizWrongBg' => vars.quizWrongBg,",
    "            'quizWrongText' => vars.quizWrongText,",
    "            'vipGoldBg' => vars.vipGoldBg,",
    "            'vipGoldText' => vars.vipGoldText,",
    "            _ => null,",
    "          };",
    "          expect(actual, t.value, reason: '${entry.key}.${t.key} 与 skin_tokens 漂移');",
    "        }",
    "      }",
    "    });",
    "",
]
block = "\n".join(parts)

test_src = TEST.read_text(encoding="utf-8")
if "skin_tokens" not in test_src:
    test_src = test_src.replace(
        "import 'package:word_app/tokens/starbucks_tokens.dart';",
        "import 'package:word_app/tokens/skin_tokens.dart';\nimport 'package:word_app/tokens/starbucks_tokens.dart';",
    )
# replace exemption comment
test_src = test_src.replace(
    "// 豁免说明：其余 6 套皮肤（bright/dark/pure_black/warm_orange/claude 等）不对应\n// token 集，不受本守卫约束。",
    "// batch7：其余 9 套皮肤亦 token 化（lib/tokens/skin_tokens.dart），本测试一并锁定。",
)
# append group before final closing of main if not present
if "9 套皮肤 preset" not in test_src:
    # insert before last closing brace of main
    idx = test_src.rstrip().rfind("}")
    # find the closing of last group/test - insert before final `}` of main
    # safer: replace final "}\n" of file
    test_src = test_src.rstrip()
    if test_src.endswith("}"):
        test_src = test_src[:-1] + "  group('皮肤 token 单一事实来源（batch7）', () {\n" + block + "  });\n}\n"
TEST.write_text(test_src, encoding="utf-8")
print("fields", {k: len(v) for k, v in fields_by_class.items()})
print("updated", TEST)
