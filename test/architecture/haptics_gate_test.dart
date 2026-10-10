// HapticsGate 守卫：触觉反馈唯一出口（白名单=出口实现自身）。
// 同 debug_print_guard 范式：扫描 lib/ 源码，`HapticFeedback.` 直接调用
// 只允许出现在 haptics_gate.dart。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('触觉唯一出口：lib/ 下 HapticFeedback 直接调用仅存在于 haptics_gate.dart', () {
    final violations = <String>[];
    final roots = [
      'lib/features',
      'lib/app',
      'lib/core',
      'lib/widgets',
      'lib/models',
      'lib/theme',
      'lib/tokens',
      'lib/utils',
      'lib/main.dart', // 2026-10 审计 Q1：兜底页/入口直用也须被守卫看见
    ];
    final self = 'lib/core/utils/haptics_gate.dart';
    final callRe = RegExp(r'\bHapticFeedback\.');

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized == self) continue;
        final source = entity.readAsStringSync();
        if (callRe.hasMatch(source)) {
          violations.add(normalized);
        }
      }
    }
    expect(violations, isEmpty, reason: '触觉必须经 HapticsGate.play 收口（禁直接 import HapticFeedback）');
  });
}
