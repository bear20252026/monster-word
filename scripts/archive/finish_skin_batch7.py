from pathlib import Path
import re
import subprocess
import sys

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-b7")
sys.path.insert(0, str(root / "scripts"))
# run fix_skin_test
subprocess.check_call([sys.executable, str(root / "scripts" / "fix_skin_test.py")])

pres_path = root / "lib/theme/theme_presets.dart"
pres = pres_path.read_text(encoding="utf-8")
tok_path = root / "lib/tokens/skin_tokens.dart"
tok = tok_path.read_text(encoding="utf-8")
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
for skin, cls in CLASS.items():
    start = pres.find(f"'{skin}': ThemePreset(")
    if start < 0:
        continue
    nxt = re.search(r"\n  '\w+': ThemePreset\(", pres[start + 10 :])
    end = start + 10 + nxt.start() if nxt else len(pres)
    block = pres[start:end]
    if f"class {cls}" not in tok:
        continue
    body = tok.split(f"class {cls} {{", 1)[1].split("\n}", 1)[0]
    m = re.search(r"profileDecor:\s*const \[([^\]]+)\]", block)
    if m and "profileDecor" not in body:
        tok = tok.replace(
            f"class {cls} {{",
            f"class {cls} {{\n  static const List<Color> profileDecor = [{m.group(1)}];",
            1,
        )
        body = tok.split(f"class {cls} {{", 1)[1].split("\n}", 1)[0]
    if "profileDecor" in body:
        block2 = re.sub(
            r"profileDecor:\s*const \[[^\]]+\]",
            f"profileDecor: {cls}.profileDecor",
            block,
        )
        if block2 != block:
            pres = pres[:start] + block2 + pres[end:]
tok_path.write_text(tok, encoding="utf-8")
pres_path.write_text(pres, encoding="utf-8")
print("profileDecor done")
test = (root / "test/architecture/theme_token_consistency_test.dart").read_text(encoding="utf-8")
print("test has batch7", "batch7" in test)
print("test tail:\n", "\n".join(test.splitlines()[-15:]))
