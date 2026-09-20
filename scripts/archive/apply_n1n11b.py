from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-n")

# ── N3: routeName must alias RouteNames when path matches ──
route_names_src = (root / "lib/app/router/route_names.dart").read_text(encoding="utf-8")
route_map = {}
for m in re.finditer(r"static const String (\w+) = '([^']+)'", route_names_src):
    route_map[m.group(1)] = m.group(2)

# rewrite presentation routeName = '/xxx' to RouteNames alias where path exists
alias_by_path = {v: k for k, v in route_map.items()}
changed = 0
for f in (root / "lib/features").rglob("*.dart"):
    if "presentation" not in f.as_posix():
        continue
    text = f.read_text(encoding="utf-8")
    orig = text

    def repl(m):
        path = m.group(2)
        key = alias_by_path.get(path)
        if not key:
            return m.group(0)
        # only if already has RouteNames import or we add later
        return f"{m.group(1)}RouteNames.{key};"

    text2 = re.sub(
        r"(static const (?:String )?routeName = )'([^']+)';",
        repl,
        text,
    )
    if text2 != orig:
        if "package:word_app/app/router/route_names.dart" not in text2:
            text2 = text2.replace(
                "import 'package:flutter/material.dart';",
                "import 'package:flutter/material.dart';\nimport 'package:word_app/app/router/route_names.dart';",
                1,
            )
        f.write_text(text2, encoding="utf-8")
        changed += 1
print("N3 routeName aliased files", changed)

# ── N9: import_guard R-DB + review_schedule ──
p = root / "lib/core/import_guard.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    "const dbSingletonTargets = ['core/infrastructure/wordbook_database.dart', 'core/infrastructure/user_database.dart'];",
    "const dbSingletonTargets = [\n"
    "      'core/infrastructure/wordbook_database.dart',\n"
    "      'core/infrastructure/user_database.dart',\n"
    "      'features/learning/data/review_schedule_store.dart',\n"
    "    ];",
)
p.write_text(src, encoding="utf-8")
print("N9 guard R-DB ok")

# ── N6: swallowed_error list + docs ──
p = root / "test/architecture/swallowed_error_guard_test.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    """  'lib/features/account/data/user_service_impl.dart', // 用户信息
];""",
    """  'lib/features/account/data/user_service_impl.dart', // 用户信息
  'lib/features/learning/data/review_schedule_repository.dart', // FSRS 持久化/迁移（N4）
  'lib/features/learning/presentation/learning_session_state.dart', // 今日已学写入
  'lib/core/application/today_progress_store.dart', // 目标/已学单源
  'lib/features/account/application/message_store.dart', // 消息本地仓
];""",
)
p.write_text(src, encoding="utf-8")
print("N6 guard list ok")

# ledger
p = root / "docs/regression_ledger.md"
src = p.read_text(encoding="utf-8")
if "REG-ARCH-009" not in src:
    add = """
| REG-ARCH-009 | LearningSessionState 与 Provider 双实例门面（M1 残债） | providers 创建 session 未注入 TodayProgressStore/PresentationPrefs | N1 批（2026-09-20） | 装配层先建门面再注入 session；widgets `context.read`；架构测试禁非装配文件直建 |
| REG-OPS-001 | build_full_wordbook 无备份覆盖 assets | H4 只覆盖 expanded 脚本 | N2 批 | 默认 OUT 到 inputs/；`ALLOW_ASSET_OVERWRITE` + `.bak` |
| REG-NAV-005 | 页面 routeName 字面量与 RouteNames 双源 | 无单源守卫 | N3 批 | presentation `routeName = RouteNames.*`；路由表唯一事实来源 |

## 修复新 bug 的流程
"""
    src = src.replace("## 修复新 bug 的流程", add, 1)
    p.write_text(src, encoding="utf-8")
    print("ledger ok")

# migration plan H1 alignment
p = root / "docs/fsrs_sqlite_migration_plan.md"
if p.exists():
    src = p.read_text(encoding="utf-8")
    src = src.replace(
        "表空且 SP 非空",
        "迁移标记未写（migratedMarkerKey != done）且 SP 非空（H1：不再用 cardCount>0 提前返回）",
    )
    p.write_text(src, encoding="utf-8")
    print("migration plan ok")

# data_verification comment
p = root / "test/data_verification_test.dart"
src = p.read_text(encoding="utf-8")
src = src.replace("191 本官方", "官方基线约 191 本（可增长）")
p.write_text(src, encoding="utf-8")

# ── architecture test N1: forbid direct PresentationPrefs() outside allowed files ──
test_n1 = r'''
// N1：门面直建守卫——除装配边界与门面自身外，禁止 PresentationPrefs()/TodayProgressStore() 构造。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowed = <String>[
  'lib/core/application/presentation_prefs.dart',
  'lib/core/application/today_progress_store.dart',
  'lib/features/learning/presentation/learning_feature_providers.dart',
  'lib/features/dictionary/presentation/dictionary_feature_providers.dart',
];

void main() {
  test('非装配文件禁止直建 PresentationPrefs()/TodayProgressStore()（N1/M1）', () {
    final violations = <String>[];
    final pattern = RegExp(r'PresentationPrefs\(\)|TodayProgressStore\(\)');
    for (final dirName in ['lib/features', 'lib/widgets', 'lib/app']) {
      final dir = Directory(dirName);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll(r'\', '/');
        if (_allowed.contains(rel)) continue;
        final src = f.readAsStringSync();
        for (final m in pattern.allMatches(src)) {
          // 允许构造函数参数默认值字段声明处仍算违规——需注入
          final line = src.substring(0, m.start).split('\n').length;
          violations.add('$rel:$line ${m.group(0)}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '门面必须经 Provider 注入或仅在 providers/门面文件内构造：\n${violations.join('\n')}',
    );
  });
}
'''
(root / "test/architecture/facade_direct_ctor_guard_test.dart").write_text(test_n1, encoding="utf-8")
print("N1 arch test ok")

# import_guard_test note for widgets core repos
p = root / "test/architecture/import_guard_test.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    "expect(check('widgets/some_card.dart', 'core/repositories/word_repository.dart'), isEmpty);",
    "// widgets→core/repositories：历史放行（scare_coin 等）；R-widgets 仍禁 feature 内层。\n"
    "      expect(check('widgets/some_card.dart', 'core/repositories/word_repository.dart'), isEmpty);",
)
p.write_text(src, encoding="utf-8")
print("done stage2")
