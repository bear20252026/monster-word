from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-b7")
p = root / "lib/tokens/design_tokens.dart"
c = p.read_text(encoding="utf-8")
if "class AppFontSizes" not in c:
    block = """/// 排版字号常量（与 MwTypography 阶一致；const TextStyle 用，见 font_hygiene）。
class AppFontSizes {
  static const double microXs = 10;
  static const double micro = 12;
  static const double caption = 13;
  static const double bodySm = 14;
  static const double bodyMd = 16;
  static const double heading5 = 18;
  static const double titleLg = 20;
  static const double heading4 = 22;
  static const double displaySm = 24;
  static const double stat = 32;
}

"""
    c = c.replace("/// 排版 token：只承载字号", block + "/// 排版 token：只承载字号")
    p.write_text(c, encoding="utf-8")
    print("inserted AppFontSizes")

repl = {
    "MwTypography.micro.fontSize": "AppFontSizes.micro",
    "MwTypography.caption.fontSize": "AppFontSizes.caption",
    "MwTypography.bodySm.fontSize": "AppFontSizes.bodySm",
    "MwTypography.bodyMd.fontSize": "AppFontSizes.bodyMd",
    "MwTypography.heading5.fontSize": "AppFontSizes.heading5",
    "MwTypography.titleLg.fontSize": "AppFontSizes.titleLg",
    "MwTypography.heading4.fontSize": "AppFontSizes.heading4",
    "MwTypography.displaySm.fontSize": "AppFontSizes.displaySm",
    "MwTypography.stat.fontSize": "AppFontSizes.stat",
}
changed = 0
for rel in ("lib/features", "lib/widgets", "lib/app"):
    for f in (root / rel).rglob("*.dart"):
        t = f.read_text(encoding="utf-8")
        o = t
        for a, b in repl.items():
            t = t.replace(a, b)
        if t != o:
            f.write_text(t, encoding="utf-8")
            changed += 1
print("files changed", changed)
print("AppFontSizes" in (root / "lib/tokens/design_tokens.dart").read_text(encoding="utf-8"))
