// 动效时长卫生守卫（棘轮）——参数化动效语境中可映射 MotionDurations 的
// Duration 字面量只减不增。
//
// 背景：裸 Duration 字面量曾 122 处（审计 I60），其中不少是 Future.delayed /
// Timer 的业务时序（防抖、轮询、延迟清理），不应错误收敛到动效 token。
// 2026-10-01 批次已将**参数化动效语境**（duration/delay/transitionDuration/
// reverseDuration 命名参数）中值命中档位的调用收敛为 MotionDurations。
// 本测试锁定该口径的存量为 0；业务时序（位置参数调用）不在守卫范围。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app', 'lib/core', 'lib/main.dart'];

/// MotionDurations 档位值（与 lib/tokens/motion_tokens.dart 同口径）。
const _tiers = <String>{'150', '200', '300', '450', '700', '2800'};

/// duration/delay 等命名参数 + const Duration 字面量（动效语境特征）。
final _callRe = RegExp(
  r'(duration|delay|transitionDuration|reverseDuration)\s*:\s*(?:const\s+)?Duration\(milliseconds:\s*(\d+)\)',
);

void main() {
  test('动效语境中可映射 MotionDurations 的 Duration 字面量存量为 0（棘轮）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        if (rel.endsWith('tokens/motion_tokens.dart')) continue;
        final src = f.readAsStringSync();
        for (final m in _callRe.allMatches(src)) {
          if (_tiers.contains(m.group(2))) {
            final line = src.substring(0, m.start).split('\n').length;
            hits.add('$rel:$line (${m.group(1)}: ${m.group(2)}ms)');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: '以下动效时长应改用 MotionDurations 档位（棘轮：字面量只减不增）：\n${hits.join('\n')}');
  });

  test('MotionDurations 档位值与守卫口径一致', () {
    final src = File('lib/tokens/motion_tokens.dart').readAsStringSync();
    for (final tier in _tiers) {
      expect(
        src.contains('Duration(milliseconds: $tier)'),
        isTrue,
        reason: '守卫口径档位 $tier 应存在于 MotionDurations',
      );
    }
  });
}
