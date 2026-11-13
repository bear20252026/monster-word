// P1-2（架构审计 2026-11-12）：presentation / widgets 直触 SharedPreferences 存量锁。
//
// R-prefs 的本意是「presentation 不直接持久化，经 application 门面」。但旧守卫
// 只封 `import app_preferences`，不封 `SharedPreferences.getInstance()` 本身，
// 也不覆盖 widgets 层对 core 目标的引用——于是有一批页面绕过门面直读直写 SP。
//
// 全量收敛为 application 端口是渐进工程（见审计报告第二批）。本守卫先把**存量
// 冻结**：清单内的文件允许继续直触（待逐个迁移），清单外新增直触一律红灯。
// 每迁完一个文件就从清单删除；清单只许缩小、不许增大（棘轮）。
//
// 口径：统计 `SharedPreferences.getInstance(` 调用点。part 文件归入其主文件
// （与 code_style_guard 的 part 家族口径一致）。application/data/core 层不在
// 本守卫射程（它们本就是持久化的合法归属）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 存量直触 SP 的 presentation/widgets 主文件（含其 part）。只许缩小。
const Set<String> _kSpDirectAccessAllowlist = {
  'lib/features/checkin/presentation/treasure_checkin_page.dart',
  'lib/features/learning/presentation/learn_page.dart',
  'lib/features/scare_coin/presentation/redemption_center_page.dart',
  'lib/features/settings/presentation/profile_screen.dart', // part: monster_room_life
  'lib/widgets/monster_presence.dart',
};

/// 返回 presentation/widgets 层直触 SP 的主文件集合（part 归主文件）。
Set<String> _directSpAccessFiles() {
  final files = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
    files[normalized] = entity.readAsLinesSync();
  }

  // part of 文件 -> 主文件（解析 `part of 'x.dart'`）。
  final partOfOwner = <String, String>{};
  final partOfDirective = RegExp(r'''^\s*part\s+of\s+['"]([^'"]+)['"]''');
  for (final entry in files.entries) {
    final dir = entry.key.substring(0, entry.key.lastIndexOf('/'));
    for (final line in entry.value) {
      final m = partOfDirective.firstMatch(line);
      if (m != null) {
        partOfOwner[entry.key] = '$dir/${m.group(1)}';
        break;
      }
    }
  }

  bool inScope(String path) =>
      path.startsWith('lib/widgets/') || (path.startsWith('lib/features/') && path.contains('/presentation/'));

  final result = <String>{};
  for (final entry in files.entries) {
    if (!inScope(entry.key)) continue;
    final hasDirect = entry.value.any((line) => line.contains('SharedPreferences.getInstance('));
    if (!hasDirect) continue;
    // part 文件归入主文件计数。
    result.add(partOfOwner[entry.key] ?? entry.key);
  }
  return result;
}

void main() {
  test('presentation/widgets 直触 SP 不得超出存量清单（棘轮）', () {
    final actual = _directSpAccessFiles();
    final added = actual.difference(_kSpDirectAccessAllowlist);
    expect(added, isEmpty, reason: '以下 presentation/widgets 文件新增直触 SharedPreferences，请改经 application 门面：$added');
  });

  test('SP 直触存量清单不得存在失效条目', () {
    final actual = _directSpAccessFiles();
    final stale = _kSpDirectAccessAllowlist.difference(actual);
    expect(stale, isEmpty, reason: '以下文件已不再直触 SP，请从存量清单删除（只许收紧）：$stale');
  });
}
