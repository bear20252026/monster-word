// 架构规约测试（健康评估 M6/M5 落地）：
// 1. lib/ 下不允许超过 900 行的 dart 文件（超大文件必须拆分）
// 2. presentation 层 build() 方法不允许超过 120 行（超过必须拆 _buildXxx）
// 阈值依据：2026-08-30 评估时全库最大文件 803 行、最大 build 280 行（拆分前 1346/766），
// 阈值取"略高于现状上限"，逼停回潮而不苛责存量。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P1-4（架构审计 2026-11-12）：900 行上限按 **part 家族聚合**计数。
///
/// 旧口径按物理文件计数，`part of` 拆分可以绕过上限（profile_screen 900 +
/// monster_room_life 329 ≈ 1229、treasure_checkin_page 843 + painters 563 ≈ 1406
/// 都「单文件合规」）。现把主文件与其全部 part 的行数加总判定。
///
/// 存量超限家族入棘轮清单：**只许缩小、不许增大**（与 radius/font 棘轮同机制）。
/// 每拆小一个家族就更新对应上限；新增家族或存量增大一律红灯。
const Map<String, int> _kPartFamilyRatchet = {
  // 1102：审计 D3（2026-11-15）音频 http→https 升级 +2（安全修复注释）。
  // 1121：第三轮 T24（2026-11-16）just_audio 惰性创建+释放后重建 +19
  // （修移动端 re-attach 发音永久静默；getter 挂监听替代构造期订阅）。
  // 1130：第三轮 T32（2026-11-16）单词缓存键白名单消毒 +9（防路径穿越）。
  'lib/core/audio/audio_players.dart': 1130,
  // 1763：批次 14 P2-8 驱动统一边界注释 +3（签到保留裸 Ticker 的语义说明）。
  'lib/features/checkin/presentation/treasure_checkin_page.dart': 1763,
  // 1467：批次 12 P2-6 home 拆域端口化 +5（Reader/Starter 导入与注释）。
  // 1474：审计 C8（2026-11-15）下滑查词重入闸 +7。
  'lib/features/home/presentation/home_screen.dart': 1474,
  // 1051：批次 2 冻结 1047，批次 3 P2-3 性格传参 +4（导入/传参/注释），合理新增。
  // 1078：AI 化阶段 1 AI 伙伴入口 cell+组方法 +18（设置主体已抽 llm_settings_sheet.dart 独立文件）。
  // 1087：审计 C3（2026-11-15）宠物开关 in-flight 闸 +9（竞态修复注释/finally）。
  // 1100：审计 C11（2026-11-15）副标题 Flexible+ellipsis +13。
  // 1114：审计 C6（2026-11-16）宠物可见性事件订阅+dispose +14。
  // 1126：审计 R20（2026-11-16）toggle 在途忽略事件+完成后 isVisible 复核 +12。
  // 1137：第三轮 T20（2026-11-16）首查 busy 闸+失败路径可见性复核 +11。
  'lib/features/settings/presentation/more_settings_page.dart': 1137,
  'lib/features/settings/presentation/profile_screen.dart': 1890,
};

/// 解析 part 家族：主文件 -> 家族总行数（主文件 + 全部 `part 'x.dart'`）。
/// `part of` 文件不单独成族，归入其主文件。
Map<String, int> _partFamilySizes() {
  final files = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
    files[normalized] = entity.readAsLinesSync();
  }

  final partOf = <String>{}; // 所有 `part of` 文件（归入主文件，不单独成族）
  final partsByOwner = <String, List<String>>{};
  final partDirective = RegExp(r'''^\s*part\s+['"]([^'"]+)['"]\s*;''');
  final partOfDirective = RegExp(r'''^\s*part\s+of\s+''');
  for (final entry in files.entries) {
    final dir = entry.key.substring(0, entry.key.lastIndexOf('/'));
    for (final line in entry.value) {
      if (partOfDirective.hasMatch(line)) {
        partOf.add(entry.key);
        break;
      }
      final m = partDirective.firstMatch(line);
      if (m != null) {
        final partPath = '$dir/${m.group(1)}';
        (partsByOwner[entry.key] ??= <String>[]).add(partPath);
      }
    }
  }

  final sizes = <String, int>{};
  for (final entry in files.entries) {
    if (partOf.contains(entry.key)) continue; // part 文件归入主文件
    var total = entry.value.length;
    for (final partPath in partsByOwner[entry.key] ?? const <String>[]) {
      total += files[partPath]?.length ?? 0;
    }
    sizes[entry.key] = total;
  }
  return sizes;
}

void main() {
  test('lib/ 下 dart 文件（含 part 家族聚合）不超过 900 行', () {
    final offenders = <String, int>{};
    for (final entry in _partFamilySizes().entries) {
      if (entry.value <= 900) continue;
      final ceiling = _kPartFamilyRatchet[entry.key];
      if (ceiling != null && entry.value <= ceiling) continue; // 存量棘轮内
      offenders[entry.key] = entry.value;
    }
    expect(offenders, isEmpty, reason: '以下文件/家族超过 900 行（或超出棘轮上限），必须拆分：$offenders');
  });

  test('part 家族棘轮清单不得存在失效或可收紧条目', () {
    final sizes = _partFamilySizes();
    final problems = <String>[];
    for (final entry in _kPartFamilyRatchet.entries) {
      final actual = sizes[entry.key];
      if (actual == null) {
        problems.add('${entry.key}：文件不存在（死豁免，请删除）');
      } else if (actual <= 900) {
        problems.add('${entry.key}：已合规（$actual 行），请从棘轮清单删除');
      } else if (actual < entry.value) {
        problems.add('${entry.key}：已缩小到 $actual 行，请把棘轮上限从 ${entry.value} 收紧到 $actual');
      }
    }
    expect(problems, isEmpty, reason: '棘轮清单需更新（只许收紧）：$problems');
  });

  /// build() 超长存量豁免：文件名 -> 豁免的**所属类名**集合。
  ///
  /// 第四轮审计 M12（2026-11-17）：锚点从「build 起始行号」改为「类名」——
  /// 行号锚点在 build() 之前增删任何代码都会失配（死豁免掩盖真实违规，
  /// 2026-10-16 曾清理出三条全失效）；类名是符号锚点，不随上方代码漂移，
  /// 只有类被改名/删除才失配（此时死豁免守卫照样拦截）。
  ///
  /// **新增豁免前先确认 build() 真的超 120 行**。
  const kBuildAllowlist = {
    // 约 160 行（签到守卫 + 埋点接线历史增长）。当前唯一真实的超长 build()。
    'lib/features/scare_coin/presentation/scare_coin_history_page.dart': {'_ScareCoinHistoryPageState'},
  };

  /// 扫描 presentation 层全部 build()，返回 文件 -> {类名: 长度}（仅超长项）。
  /// 类名取 build 之前最近的 `class X` 声明（StatefulWidget 的 build 在 State 类）。
  Map<String, Map<String, int>> scanLongBuilds() {
    final result = <String, Map<String, int>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.path.replaceAll('\\', '/').contains('/presentation/')) continue;

      final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
      final lines = entity.readAsLinesSync();
      var buildStart = -1;
      var braceDepth = 0;
      var currentClass = '';
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final classMatch = RegExp(r'^\s*(?:abstract\s+)?class\s+(\w+)').firstMatch(line);
        if (classMatch != null) currentClass = classMatch.group(1)!;
        if (buildStart == -1) {
          // build 方法签名（排除 _buildXxx 辅助方法）
          if (RegExp(r'^\s+Widget build\(BuildContext context\) \{').hasMatch(line)) {
            buildStart = i;
            braceDepth = 1; // 签名行自身以 { 结束
          }
        } else {
          braceDepth += '{'.allMatches(line).length - '}'.allMatches(line).length;
          if (braceDepth <= 0) {
            final length = i - buildStart + 1;
            if (length > 120) {
              (result[normalized] ??= {})[currentClass] = length;
            }
            buildStart = -1;
          }
        }
      }
    }
    return result;
  }

  test('presentation 层 build() 方法不超过 120 行', () {
    final offenders = <String, int>{};
    for (final entry in scanLongBuilds().entries) {
      for (final build in entry.value.entries) {
        final allowed = kBuildAllowlist[entry.key]?.contains(build.key) ?? false;
        if (!allowed) offenders['${entry.key}#${build.key}'] = build.value;
      }
    }
    expect(offenders, isEmpty, reason: '以下 build() 超过 120 行，必须拆分 _buildXxx：$offenders');
  });

  // 防「死豁免」（2026-10-16 立；第四轮 M12 改类名锚点）：清单里的每个类名
  // 都必须**真的命中一个超长 build()**。命中不到 ⇒ 类被改名/删除（改对），
  // 或 build() 已经合规（删掉条目）。死豁免会掩盖真实违规，必须拦截。
  test('build() 豁免清单不得存在失效条目', () {
    final observed = scanLongBuilds();
    final stale = <String>[];
    for (final entry in kBuildAllowlist.entries) {
      final actual = observed[entry.key] ?? const <String, int>{};
      for (final className in entry.value) {
        if (!actual.containsKey(className)) {
          stale.add(
            '${entry.key}#$className'
            '（该文件${actual.isEmpty ? "当前没有超长 build()" : "实际超长类为 ${actual.keys}"}）',
          );
        }
      }
    }
    expect(stale, isEmpty, reason: '以下豁免条目已失效，会掩盖真实违规，请更新类名或删除：$stale');
  });
}
