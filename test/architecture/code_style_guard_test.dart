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
  'lib/core/audio/audio_players.dart': 1100,
  // 1760：批次 7 P2-8 里程碑庆祝编排收口于 MilestoneCelebration，两份重复方法删减 -30。
  'lib/features/checkin/presentation/treasure_checkin_page.dart': 1760,
  'lib/features/learning/presentation/home_screen.dart': 1462,
  // 1051：批次 2 冻结 1047，批次 3 P2-3 性格传参 +4（导入/传参/注释），合理新增。
  // 1060：批次 6 P2-12 恢复入口 cell +9（对话框主体已抽 restore_backup_dialog.dart 独立文件）。
  'lib/features/settings/presentation/more_settings_page.dart': 1060,
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

  /// build() 超长存量豁免：文件名 -> 豁免的 build 起始行号集合
  ///
  /// ⚠️ 条目按 build() 的**起始行号**登记，因此在 build() 之前增删任何代码都会
  /// 让旧条目失配。失配的条目是**死豁免**：它不再豁免任何东西，却会继续掩盖真实
  /// 违规——后人看到清单里有这个文件，会以为「超长是已知且已批准的」而不再深究。
  ///
  /// 2026-10-16 清理：立「豁免清单不得存在失效条目」守卫后发现本清单**三条全失效**：
  ///   - `more_settings_page.dart` {494, 495}：拆出 `_buildXxx` 后起始行早已漂到 517，
  ///     且 build() 只剩 35 行（本就合规）——条目纯属残留。
  ///   - `list_word_listen_page.dart` {99, 100, 101}：起始行实际 107，build() 已合规。
  ///   - `scare_coin_history_page.dart` {64, 65, 74}：只有 93 是当前真实起始行，
  ///     另外三个是历史行号的残留。
  /// 现仅保留真正需要豁免的一条。**新增豁免前先确认 build() 真的超 120 行**。
  const kBuildAllowlist = {
    // 160 行（2026-10-04 签到守卫 +9 行，起始行 64→74；2026-10-15 埋点接线 +19 行，
    // 起始行 74→93）。这是当前唯一真实的超长 build()。
    'lib/features/scare_coin/presentation/scare_coin_history_page.dart': {93},
  };

  test('presentation 层 build() 方法不超过 120 行', () {
    final offenders = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.path.replaceAll('\\', '/').contains('/presentation/')) continue;

      final lines = entity.readAsLinesSync();
      var buildStart = -1;
      var braceDepth = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
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
              final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
              final allowed = kBuildAllowlist[normalized]?.contains(buildStart + 1) ?? false;
              if (!allowed) {
                offenders['${entity.path}:${buildStart + 1}'] = length;
              }
            }
            buildStart = -1;
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: '以下 build() 超过 120 行，必须拆分 _buildXxx：$offenders');
  });

  // 防「死豁免」（2026-10-16 立）：豁免清单按 build() 起始行号登记，行号一旦漂移，
  // 条目就永远匹配不到——它不再豁免任何东西，却会**继续掩盖真实违规**：
  // 后人看到清单里有这个文件，会以为「超长是已知且已批准的」，于是不再深究。
  //
  // 实锤案例：more_settings_page.dart 的 {494, 495} 在文件拆出 _buildXxx 后失配
  // （实际起始行早已是 517），此后该文件哪怕 build() 涨到 200 行也不会被拦。
  //
  // 本测试要求：清单里的每个行号都必须**真的命中一个超长 build()**。
  // 命中不到 ⇒ 要么行号漂了（改对），要么 build() 已经合规（删掉条目）。
  test('build() 豁免清单不得存在失效条目', () {
    final observed = <String, Set<int>>{}; // 文件 -> 实际超长 build() 的起始行号
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.path.replaceAll('\\', '/').contains('/presentation/')) continue;

      final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
      final lines = entity.readAsLinesSync();
      var buildStart = -1;
      var braceDepth = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (buildStart == -1) {
          if (RegExp(r'^\s+Widget build\(BuildContext context\) \{').hasMatch(line)) {
            buildStart = i;
            braceDepth = 1;
          }
        } else {
          braceDepth += '{'.allMatches(line).length - '}'.allMatches(line).length;
          if (braceDepth <= 0) {
            if (i - buildStart + 1 > 120) {
              (observed[normalized] ??= <int>{}).add(buildStart + 1);
            }
            buildStart = -1;
          }
        }
      }
    }

    final stale = <String>[];
    for (final entry in kBuildAllowlist.entries) {
      final actual = observed[entry.key] ?? const <int>{};
      for (final lineNo in entry.value) {
        if (!actual.contains(lineNo)) {
          stale.add(
            '${entry.key}:$lineNo'
            '（该文件${actual.isEmpty ? "当前没有超长 build()" : "实际超长行号为 $actual"}）',
          );
        }
      }
    }
    expect(stale, isEmpty, reason: '以下豁免条目已失效，会掩盖真实违规，请更新行号或删除：$stale');
  });
}
