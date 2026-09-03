// 由 Claude 团队生成 | Monster Word App

// 吞错治理守卫（审计跟进批次 C / REG-OBS-001）。
// A 级文件（用户数据丢失/持久化失败路径）必须调用 reportSwallowedError 上报，
// 任何人回退为空捕获 `catch (_) {}` 即测试失败。
// 分级规则见 lib/core/utils/swallowed_error_report.dart 文件头。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A 级路径：这些文件的异常曾导致用户数据静默丢失，必须接 reportSwallowedError。
const _aLevelFiles = [
  'lib/core/repositories/fav_repository_impl.dart', // 收藏列表
  'lib/core/repositories/note_repository_impl.dart', // 笔记
  'lib/features/learning/data/mastered_repository_impl.dart', // 已掌握词表
  'lib/features/learning/application/review_session_starter.dart', // 复习会话启动
  'lib/features/learning/presentation/review_word_action_coordinator.dart', // 收藏/掌握持久化
  'lib/features/scare_coin/data/preferences_scare_coin_store.dart', // 金币账本
  'lib/features/account/data/user_service_impl.dart', // 用户信息
];

void main() {
  test('A 级数据路径文件必须调用 reportSwallowedError（REG-OBS-001）', () {
    final violations = <String>[];
    for (final path in _aLevelFiles) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path 不存在（请在仓库根目录运行）');
      final src = f.readAsStringSync();
      if (!src.contains('reportSwallowedError')) {
        violations.add('$path 缺少 reportSwallowedError 调用（数据路径异常不得静默吞掉）');
      }
    }
    expect(violations, isEmpty, reason: violations.join('；'));
  });

  test('上报工具不得在 Sentry 未初始化时调用平台通道', () {
    final src = File('lib/core/utils/swallowed_error_report.dart').readAsStringSync();
    expect(src, contains('Sentry.isEnabled'), reason: '必须用 isEnabled 守卫，避免测试环境崩溃');
  });
}
