from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-r49")

mapping = {
    40: "AppFontSizes.hero",
    44: "AppFontSizes.displayMd",
    48: "AppFontSizes.heroLg",
    30: "AppFontSizes.statSm",
    26: "AppFontSizes.title",
    24: "AppFontSizes.displaySm",
    19: "AppFontSizes.titleSm",
    18: "AppFontSizes.heading5",
    16: "AppFontSizes.bodyMd",
    15: "AppFontSizes.bodyXl",
    14: "AppFontSizes.bodySm",
    13: "AppFontSizes.caption",
    12: "AppFontSizes.micro",
}

def convert(text: str) -> str:
    def repl(m):
        n = int(m.group(1))
        scale = m.group(2)
        token = mapping.get(n, str(n))
        return f"fontSize: {token} * {scale}.fontScale"

    return re.sub(r"fontSize:\s*(\d+)\s*\*\s*(resp|responsive)\.fontScale", repl, text)

changed = 0
for rel in ("lib/features", "lib/widgets", "lib/app"):
    for f in (root / rel).rglob("*.dart"):
        t = f.read_text(encoding="utf-8")
        nt = convert(t)
        if nt != t:
            if "design_tokens.dart" not in nt:
                nt = nt.replace(
                    "import 'package:flutter/material.dart';",
                    "import 'package:flutter/material.dart';\nimport 'package:word_app/tokens/design_tokens.dart';",
                    1,
                )
            f.write_text(nt, encoding="utf-8")
            changed += 1
            print("converted", f.relative_to(root))

print("files", changed)
hits = []
for rel in ("lib/features", "lib/widgets", "lib/app"):
    for f in (root / rel).rglob("*.dart"):
        relp = f.relative_to(root).as_posix()
        if relp == "lib/app/app.dart" or "share_image_service" in relp:
            continue
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"fontSize:\s*\d+\s*\*", line):
                hits.append(f"{relp}:{i}: {line.strip()}")
print("remaining", len(hits))
for h in hits:
    print(h)

# font_hygiene
p = root / "test/architecture/font_hygiene_test.dart"
src = p.read_text(encoding="utf-8")
if "_scalePattern" not in src:
    src = src.replace(
        "final _pattern = RegExp(r'fontSize:\\s*\\d+\\s*[,)]');",
        "final _pattern = RegExp(r'fontSize:\\s*\\d+\\s*[,)]');\n"
        "final _scalePattern = RegExp(r'fontSize:\\s*\\d+\\s*\\*');\n"
        "const _scaleCeiling = 0;",
    )
    if src.rstrip().endswith("}"):
        src = src.rstrip()[:-1] + """
  test('fontSize: N * fontScale 字面量存量只减不增（当前上限 $_scaleCeiling）', () {
    final hits = <String>[];
    for (final rootDir in _scanRoots) {
      final dir = Directory(rootDir);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll(r'\\', '/');
        if (_whitelist.contains(rel)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_scalePattern.hasMatch(lines[i])) hits.add('$rel:${i + 1}');
        }
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_scaleCeiling),
      reason:
          'fontSize: N * scale 存量 ${hits.length} 超上限 $_scaleCeiling。'
          '请改用 AppFontSizes.* * fontScale。\\n${hits.take(20).join('\\n')}',
    );
  });
}
"""
    p.write_text(src, encoding="utf-8")
    print("font_hygiene updated")

# R4 search already applied? check
sp = root / "lib/features/search/presentation/search_page.dart"
s = sp.read_text(encoding="utf-8")
if "searchRouteName" in s:
    s = re.sub(r"/// 搜索页路由名。\nconst String searchRouteName = '/search';\n\n", "", s)
    s = s.replace("static const String routeName = searchRouteName;", "static const String routeName = RouteNames.search;")
    sp.write_text(s, encoding="utf-8")
    print("search fixed")

# route guard test
(root / "test/architecture/route_name_consistency_test.dart").write_text(
    r"""// R4：presentation 路由单源——routeName 必须引用 RouteNames.*，禁止字面量或本地常量双源。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation 页面 routeName 必须使用 RouteNames.*（R4）', () {
    final violations = <String>[];
    final dir = Directory('lib/features');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (!rel.contains('/presentation/')) continue;
      if (rel.endsWith('_feature_providers.dart')) continue;
      final src = f.readAsStringSync();
      final pattern = RegExp(r'static const \w*\s*routeName\s*=\s*([^;]+);');
      for (final m in pattern.allMatches(src)) {
        final rhs = m.group(1)!.trim();
        if (!rhs.startsWith('RouteNames.')) {
          violations.add('$rel → routeName = $rhs');
        }
      }
    }
    expect(violations, isEmpty, reason: '路由名必须引用 RouteNames：\n${violations.join('\n')}');
  });
}
""",
    encoding="utf-8",
)

# ledger / remaining / version if missing
led = root / "docs/regression_ledger.md"
ls = led.read_text(encoding="utf-8")
ls = ls.replace("（50 本/25k 词校验", "（books≥272 基线校验")
if "REG-TYPE-002" not in ls:
    ls = ls.replace(
        "## 修复新 bug 的流程",
        "| REG-NAV-006 | SearchPage 路由双源 | 无全库 RouteNames 守卫 | R4 批 | RouteNames.search + route_name_consistency_test |\n"
        "| REG-TYPE-002 | fontSize N*fontScale 盲区 | regex 未覆盖 scale | R6 批 | AppFontSizes.* * fontScale + scale 棘轮 0 |\n"
        "| REG-FSRS-005 | 迁移行数校验语义 | 空迁移/双实现 | R7 批 | migrateFromSp 校验 count≥cards.length |\n\n"
        "## 修复新 bug 的流程",
    )
led.write_text(ls, encoding="utf-8")

(root / "docs/remaining_issues_2026-09-03.md").write_text(
    """# 遗留问题清单

> **2026-09-20 重写。** 本文件为当前开口的唯一清单；闭环细节见 `docs/regression_ledger.md`。

| 优先级 | 项 | 说明 |
|---|---|---|
| 已闭环 | R1–R3 / N1–N11 / H1–H4 / M1–M9 | PR #44–#49 及 R4–R9 批 |
| P2 | ReviewScheduleRepository 以具体 ChangeNotifier 暴露 | 有意设计（N5） |
| P2 | widgets→core/repositories 放行 | import_guard 注释 |
| P3 | skin_system 直用 AppPreferences | 主题层无 R-prefs |
| 用户侧 | 微信提醒无通道 / 真机验证积压 | 业务安排 |

历史文档：git 中 `remaining_issues_2026-09-03.md` 旧版本、`docs/audit/*`、`docs/audit_followup_2026-09-04.md`。
""",
    encoding="utf-8",
)

pub = root / "pubspec.yaml"
ps = pub.read_text(encoding="utf-8")
if "2.9.4+109" not in ps:
    ps = ps.replace("version: 2.9.3+108", "version: 2.9.4+109")
    pub.write_text(ps, encoding="utf-8")
iss = root / "installer.iss"
ins = iss.read_text(encoding="utf-8")
if "2.9.4" not in ins:
    ins = ins.replace('define MyAppVersion "2.9.3"', 'define MyAppVersion "2.9.4"')
    iss.write_text(ins, encoding="utf-8")
print("version", [l for l in pub.read_text(encoding="utf-8").splitlines() if l.startswith("version:")])
print("done r4r9")
