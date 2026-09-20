from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-r49")

# ── R4: search routeName ──
p = root / "lib/features/search/presentation/search_page.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    """/// 搜索页路由名。
const String searchRouteName = '/search';

/// 搜索功能域的完整页面。
///
/// 通过 Provider 向上层读取 [WordSearchReader] / [SearchHistoryStore] /
/// [ExampleReader] / [FavoritesAccessor] / [AudioPlaybackState]。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static const String routeName = searchRouteName;""",
    """/// 搜索功能域的完整页面。
///
/// 通过 Provider 向上层读取 [WordSearchReader] / [SearchHistoryStore] /
/// [ExampleReader] / [FavoritesAccessor] / [AudioPlaybackState]。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  /// R4：路由唯一事实来源 RouteNames.search
  static const String routeName = RouteNames.search;""",
)
p.write_text(src, encoding="utf-8")
print("R4 search ok")

# ── R6: AppFontSizes extend + convert scale fontSize ──
p = root / "lib/tokens/design_tokens.dart"
src = p.read_text(encoding="utf-8")
if "static const double hero = 40;" not in src:
    src = src.replace(
        "  static const double stat = 32;\n}",
        """  static const double stat = 32;
  // R6：响应式 scale 字号锚点（fontSize: AppFontSizes.x * fontScale）
  static const double bodyXl = 15;
  static const double titleSm = 19;
  static const double title = 26;
  static const double statSm = 30;
  static const double hero = 40;
  static const double displayMd = 44;
  static const double heroLg = 48;
}""",
    )
    p.write_text(src, encoding="utf-8")
    print("AppFontSizes extended")

repl = {
    "40 *": "AppFontSizes.hero *",
    "44 *": "AppFontSizes.displayMd *",
    "48 *": "AppFontSizes.heroLg *",
    "30 *": "AppFontSizes.statSm *",
    "26 *": "AppFontSizes.title *",
    "24 *": "AppFontSizes.displaySm *",
    "19 *": "AppFontSizes.titleSm *",
    "18 *": "AppFontSizes.heading5 *",
    "16 *": "AppFontSizes.bodyMd *",
    "15 *": "AppFontSizes.bodyXl *",
    "14 *": "AppFontSizes.bodySm *",
    "13 *": "AppFontSizes.caption *",
    "12 *": "AppFontSizes.micro *",
}
changed = 0
for rel in ("lib/features", "lib/widgets", "lib/app"):
    for f in (root / rel).rglob("*.dart"):
        t = f.read_text(encoding="utf-8")
        o = t
        t = re.sub(r"fontSize:\s*(\d+)\s*\*\s*(resp|responsive)\.fontScale", r"fontSize: PLACEHOLDER \1 * \2.fontScale", t)
        # map placeholder numbers
        def map_num(m):
            n = m.group(1)
            body = m.group(0)
            mapping = {
                "40": "AppFontSizes.hero",
                "44": "AppFontSizes.displayMd",
                "48": "AppFontSizes.heroLg",
                "30": "AppFontSizes.statSm",
                "26": "AppFontSizes.title",
                "24": "AppFontSizes.displaySm",
                "19": "AppFontSizes.titleSm",
                "18": "AppFontSizes.heading5",
                "16": "AppFontSizes.bodyMd",
                "15": "AppFontSizes.bodyXl",
                "14": "AppFontSizes.bodySm",
                "13": "AppFontSizes.caption",
                "12": "AppFontSizes.micro",
            }
            token = mapping.get(n)
            if not token:
                return body.replace("PLACEHOLDER ", "")
            return body.replace(f"PLACEHOLDER {n}", token)

        t = re.sub(r"PLACEHOLDER \d+ \* (?:resp|responsive)\.fontScale", map_num, t)
        if t != o:
            if "design_tokens.dart" not in t:
                t = t.replace(
                    "import 'package:flutter/material.dart';",
                    "import 'package:flutter/material.dart';\nimport 'package:word_app/tokens/design_tokens.dart';",
                    1,
                )
            f.write_text(t, encoding="utf-8")
            changed += 1
print("R6 scale files", changed)

# count remaining numeric * fontScale
hits = []
for rel in ("lib/features", "lib/widgets", "lib/app"):
    for f in (root / rel).rglob("*.dart"):
        relp = f.relative_to(root).as_posix()
        if relp in ("lib/app/app.dart",) or "share_image_service" in relp:
            continue
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"fontSize:\s*\d+\s*\*", line):
                hits.append(f"{relp}:{i}")
print("remaining scale hits", hits)

# ── font_hygiene extend ──
p = root / "test/architecture/font_hygiene_test.dart"
src = p.read_text(encoding="utf-8")
src = src.replace("const _ceiling = 1;", "const _ceiling = 1;")
if "scaleCeiling" not in src:
    src = src.replace(
        "final _pattern = RegExp(r'fontSize:\\s*\\d+\\s*[,)]');",
        """final _pattern = RegExp(r'fontSize:\\s*\\d+\\s*[,)]');
/// R6：fontSize: N * fontScale 字面量（应改为 AppFontSizes.x * fontScale）
final _scalePattern = RegExp(r'fontSize:\\s*\\d+\\s*\\*');
const _scaleCeiling = 0;""",
    )
    src = src.replace(
        "    );\n  });\n}",
        """    );
  });

  test('fontSize: N * fontScale 字面量存量只减不增（当前上限 $_scaleCeiling）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\\\', '/');
        if (_whitelist.contains(rel)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_scalePattern.hasMatch(lines[i])) hits.add('\$rel:\${i + 1}');
        }
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_scaleCeiling),
      reason:
          'fontSize: N * scale 存量 \${hits.length} 超上限 \$_scaleCeiling。'
          '请改用 AppFontSizes.* * fontScale。\\n\${hits.take(20).join('\\n')}',
    );
  });
}""",
    )
    p.write_text(src, encoding="utf-8")
    print("font_hygiene extended")

# ── R7: migrateFromSp validation semantics only (keep store helpers; tests use them) ──
p = root / "lib/features/learning/data/review_schedule_store.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    """      if (cards.isNotEmpty) {
        final result = await txn.rawQuery('SELECT COUNT(*) AS n FROM fsrs_cards');
        final count = (result.single['n'] as int?) ?? 0;
        if (count != cards.length) {
          throw StateError('迁移行数校验失败：预期 ${cards.length}，实际 $count');
        }
      }""",
    """      // R7：有卡片可迁时校验库内不少于迁移行数（允许设备上已有新评卡）。
      // 空迁移不校验绝对总数。insertCardsInTransaction 仍保留给单测锁定 merge 语义。
      if (cards.isNotEmpty) {
        final result = await txn.rawQuery('SELECT COUNT(*) AS n FROM fsrs_cards');
        final count = (result.single['n'] as int?) ?? 0;
        if (count < cards.length) {
          throw StateError('迁移行数校验失败：预期至少 ${cards.length}，实际 $count');
        }
      }""",
)
p.write_text(src, encoding="utf-8")
print("R7 store ok")

# ── R5 ledger + data_verification comment ──
p = root / "docs/regression_ledger.md"
src = p.read_text(encoding="utf-8")
src = src.replace(
    "`test/data_verification_test.dart`（50 本/25k 词校验，CI 前置\n                `test -s assets/db/wordbook.db.gz`）",
    "`test/data_verification_test.dart`（books≥272 基线 + 字段覆盖率；CI 前置 wordbook.db.gz）",
)
src = src.replace(
    "`test/data_verification_test.dart`（50 本/25k 词校验，CI 前置 `test -s assets/db/wordbook.db.gz`）",
    "`test/data_verification_test.dart`（books≥272 基线 + 字段覆盖率；CI 前置 wordbook.db.gz）",
)
if "REG-ARCH-011" not in src:
    src = src.replace(
        "## 修复新 bug 的流程",
        """| REG-NAV-006 | SearchPage.routeName 双源 searchRouteName | 无全库 RouteNames 守卫 | R4 批（2026-09-20） | routeName=RouteNames.search；architecture 路由单源测试 |
| REG-TYPE-002 | fontSize: N*fontScale 棘轮盲区 26 处 | regex 不覆盖乘法 scale | R6 批 | AppFontSizes.* * fontScale；font_hygiene _scaleCeiling=0 |
| REG-FSRS-005 | 迁移空集/闲置 insertCards 双实现 | 校验语义不一致 + 死代码 | R7 批 | migrateFromSp 唯一入口；空迁移不校验绝对总数 |

## 修复新 bug 的流程""",
    )
p.write_text(src, encoding="utf-8")
print("R5 ledger ok")

p = root / "test/data_verification_test.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    "// Expected: 191 books / ~32,000 words / full official library",
    "// Expected: ≥272 books（官方基线 191 + kajweb 81；管线可追加专题书）",
)
p.write_text(src, encoding="utf-8")

# ── R8 version bump ──
p = root / "pubspec.yaml"
src = p.read_text(encoding="utf-8")
src = src.replace("version: 2.9.3+108", "version: 2.9.4+109")
p.write_text(src, encoding="utf-8")
p = root / "installer.iss"
src = p.read_text(encoding="utf-8")
src = src.replace('#define MyAppVersion "2.9.3"', '#define MyAppVersion "2.9.4"')
p.write_text(src, encoding="utf-8")
print("R8 version 2.9.4+109")

# ── R9 remaining issues rewrite ──
p = root / "docs/remaining_issues_2026-09-03.md"
src = p.read_text(encoding="utf-8")
header = """# 遗留问题清单

> **本文件已由 2026-09-20 重写。** 历史 09-03 版内容见 git 历史；当前唯一事实来源是本文件 + `docs/regression_ledger.md` + 各审计报告。

## 当前开口（基线将随 R4–R9 合入更新）

| 优先级 | 项 | 说明 |
|---|---|---|
| — | ~~R1–R9~~ | 已在 PR #48/#49 及本批落地 |
| P2 | N5 ReviewScheduleRepository ChangeNotifier 具体类型暴露 | 有意设计，长期可拆只读 Reader |
| P2 | widgets→core/repositories 放行 | import_guard_test 明确注释 |
| P3 | theme/skin_system 直用 AppPreferences | 主题层无 R-prefs |
| P3 | git tag / pubspec | 本批 bump 2.9.4+109 后于合并提交打 tag |
| 用户侧 | 微信提醒开关无通道 | 用户明确不动 |
| 用户侧 | 装机真机验证积压 | 业务侧安排 |

## 历史闭环（摘要）

S1–S4 / H1–H3 / A2 / A4 / M1–M7 等见 `docs/regression_ledger.md` 与 `docs/audit/*`；PR #44–#49 完成守卫、端口、token、FSRS 原子化、N1–N11、R1–R3。
"""
p.write_text(header, encoding="utf-8")
print("R9 remaining issues rewritten")

# ── R4 architecture routeName guard ──
test = root / "test/architecture/route_name_consistency_test.dart"
test.write_text(
    """// R4：presentation 路由单源——routeName 必须引用 RouteNames.*，禁止字面量或本地常量双源。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation 页面 routeName 必须使用 RouteNames.*（R4）', () {
    final violations = <String>[];
    final dir = Directory('lib/features');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\\', '/');
      if (!rel.contains('/presentation/')) continue;
      if (rel.endsWith('_feature_providers.dart')) continue;
      final src = f.readAsStringSync();
      final pattern = RegExp(r"static const \\w*\\s*routeName\\s*=\\s*([^;]+);");
      for (final m in pattern.allMatches(src)) {
        final rhs = m.group(1)!.trim();
        if (!rhs.startsWith('RouteNames.')) {
          violations.add('\$rel → routeName = \$rhs');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '路由名必须引用 RouteNames 集中表（N3/R4）：\\n\${violations.join('\\n')}',
    );
  });
}
""",
    encoding="utf-8",
)
print("R4 guard test ok")
print("done")
