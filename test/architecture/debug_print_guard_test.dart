// 调试日志卫生守卫——lib 下禁止直接调用 debugPrint（审计 I51）。
//
// 背景：debugPrint 在 release 构建仍输出到平台日志且无远程观测。
// 2026-10-01 批次已将 88 处调用统一收敛为 debugLog（kDebugMode 门控，
// release 零输出）；错误路径一律 reportSwallowedError（分级 + Sentry）。
// 本测试锁定：直接 debugPrint 调用存量为 0，回潮即红。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>[
  'lib/features',
  'lib/widgets',
  'lib/app',
  'lib/core',
  'lib/main.dart',
  'lib/models',
  'lib/tokens',
];

/// 统一出口实现自身与恒输出语义的上报器豁免。
const _whitelist = <String>{'lib/core/utils/debug_log.dart', 'lib/core/utils/swallowed_error_report.dart'};

final _callRe = RegExp(r'\bdebugPrint\(');

void main() {
  test('lib 下 debugPrint 直接调用存量为 0（统一走 debugLog / reportSwallowedError）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        if (_whitelist.contains(rel)) continue;
        final src = f.readAsStringSync();
        for (final m in _callRe.allMatches(src)) {
          final line = src.substring(0, m.start).split('\n').length;
          hits.add('$rel:$line');
        }
      }
    }
    expect(hits, isEmpty, reason: '以下文件应改用 debugLog（调试）或 reportSwallowedError（错误路径）：\n${hits.join('\n')}');
  });

  test('debugLog 必须 kDebugMode 门控（release 零输出）', () {
    final src = File('lib/core/utils/debug_log.dart').readAsStringSync();
    expect(src.contains('if (kDebugMode)'), isTrue, reason: 'debugLog 出口必须门控 kDebugMode');
  });
}
