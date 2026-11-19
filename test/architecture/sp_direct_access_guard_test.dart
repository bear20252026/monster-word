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
import 'package:flutter_test/flutter_test.dart';

import 'guard_scan.dart';

/// 存量直触 SP 的 presentation/widgets 主文件（含其 part）。只许缩小。
///
/// 第四轮 M11（2026-11-18）第一批：兑换中心收藏章标记 / 小屋天色 / 生日年度标记
/// 收口于 PresentationPrefs 门面，redemption_center_page 与 profile_screen
/// （part monster_room_life）不再直触 SP，清单清空——presentation/widgets 层
/// 自此零直连，新增一律红灯。application/data/core 层不在射程（持久化合法归属）。
const Set<String> _kSpDirectAccessAllowlist = {};

/// 返回 presentation/widgets 层直触 SP 的主文件集合（part 归主文件）。
/// M12：walk + part 解析改用共享扫描层（guard_scan），判定口径不变。
Set<String> _directSpAccessFiles() {
  final files = enumerateDartFiles('lib');
  final partOfOwner = resolvePartOwners(files);

  bool inScope(String path) =>
      path.startsWith('lib/widgets/') || (path.startsWith('lib/features/') && path.contains('/presentation/'));

  final result = <String>{};
  for (final file in files) {
    if (!inScope(file.path)) continue;
    final hasDirect = file.lines.any((line) => line.contains('SharedPreferences.getInstance('));
    if (!hasDirect) continue;
    // part 文件归入主文件计数。
    result.add(partOfOwner[file.path] ?? file.path);
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
