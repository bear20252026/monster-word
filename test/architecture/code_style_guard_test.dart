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
  const kBuildAllowlist = {
    'lib/features/book/presentation/lib_select_page.dart': {98, 99, 552}, // 279/126 行（两处大 build，格式化行号浮动）
    'lib/features/learning/presentation/spell_check_page.dart': {84}, // 169 行
    'lib/features/learning/presentation/list_word_listen_page.dart': {64}, // 121 行
    'lib/features/scare_coin/presentation/scare_coin_history_page.dart': {64}, // 154 行
    'lib/features/settings/presentation/more_settings_page.dart': {261}, // 133 行
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
}
