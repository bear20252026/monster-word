// P1-3（架构审计 2026-11-12）：presentation / widgets 直调 core/utils 静态偏好门面存量锁。
//
// core/utils 的静态偏好类（MonsterBondPrefs / MonsterIdentityPrefs / SfxSettings /
// MonsterVoiceSettings / MonsterPersonalitySettings）以 static 方法直读写 SP。
// 它们字面上不触发 R-prefs（该规则只封 import app_preferences），但实质绕过了
// 「presentation 经可注入门面访问持久化」的规则意图——静态调用无法注入替身、
// 测试缝也是静态 override，污染跨用例隔离。
//
// 全量收敛为 application 端口 + Provider 是渐进工程（审计报告第二批）。本守卫
// 先把**存量冻结**：清单内文件允许继续直调（待逐个迁移），清单外新增一律红灯。
// 每迁完一个文件就删对应条目；清单只许缩小（棘轮）。
//
// 口径：统计对五个静态门面类的 `类名.` 调用。part 文件归入主文件。
// application/data/core/app 层不在射程（装配与持久化的合法归属）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 存量直调静态偏好门面的 presentation/widgets 主文件（含其 part）。只许缩小。
const Set<String> _kStaticFacadeAllowlist = {
  'lib/features/account/presentation/login_page.dart',
  'lib/features/account/presentation/monster_hatching_page.dart',
  'lib/features/account/presentation/splash_page.dart',
  'lib/features/learning/presentation/learn_completion_screen.dart',
  'lib/features/settings/presentation/more_settings_page.dart',
  'lib/features/settings/presentation/profile_screen.dart', // part: monster_room_life
};

const List<String> _kFacadeClasses = [
  'MonsterBondPrefs',
  'MonsterIdentityPrefs',
  'SfxSettings',
  'MonsterVoiceSettings',
  'MonsterPersonalitySettings',
];

/// 返回 presentation/widgets 层直调静态门面的主文件集合（part 归主文件）。
Set<String> _staticFacadeCallers() {
  final files = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
    files[normalized] = entity.readAsLinesSync();
  }

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

  final callPattern = RegExp('(?:${_kFacadeClasses.join('|')})\\.');
  final result = <String>{};
  for (final entry in files.entries) {
    if (!inScope(entry.key)) continue;
    // 跳过注释行，避免把说明文字里的类名误判为调用。
    final hasCall = entry.value.any((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) return false;
      return callPattern.hasMatch(line);
    });
    if (!hasCall) continue;
    result.add(partOfOwner[entry.key] ?? entry.key);
  }
  return result;
}

void main() {
  test('presentation/widgets 直调静态偏好门面不得超出存量清单（棘轮）', () {
    final actual = _staticFacadeCallers();
    final added = actual.difference(_kStaticFacadeAllowlist);
    expect(added, isEmpty, reason: '以下文件新增直调静态偏好门面，请改经 application 端口注入：$added');
  });

  test('静态门面直调存量清单不得存在失效条目', () {
    final actual = _staticFacadeCallers();
    final stale = _kStaticFacadeAllowlist.difference(actual);
    expect(stale, isEmpty, reason: '以下文件已不再直调静态门面，请从存量清单删除（只许收紧）：$stale');
  });
}
