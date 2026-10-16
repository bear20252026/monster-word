// 架构规约测试（健康评估 M6/M5 落地）：
// 1. lib/ 下不允许超过 900 行的 dart 文件（超大文件必须拆分）
// 2. presentation 层 build() 方法不允许超过 120 行（超过必须拆 _buildXxx）
// 阈值依据：2026-08-30 评估时全库最大文件 803 行、最大 build 280 行（拆分前 1346/766），
// 阈值取"略高于现状上限"，逼停回潮而不苛责存量。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 存量豁免清单：健康评估（2026-08-30）已记录、待按 Top5 清单逐步拆分的文件。
/// 新增违规不允许进入此清单；每拆完一个，从此处删除对应条目。
/// 2026-08-31 清空（class_checkin_page 已拆分为 part 文件，全库 ≤900 行达标）。
const Set<String> _kFileAllowlist = {};

void main() {
  test('lib/ 下 dart 文件不超过 900 行', () {
    final offenders = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      if (lines.length > 900) {
        final normalized = entity.path.replaceAll(Platform.pathSeparator, '/');
        if (_kFileAllowlist.contains(normalized)) continue;
        offenders[entity.path] = lines.length;
      }
    }
    expect(offenders, isEmpty, reason: '以下文件超过 900 行，必须拆分：$offenders');
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
